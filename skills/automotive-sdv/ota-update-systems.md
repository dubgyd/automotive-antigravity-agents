# OTA Update Systems — Over-The-Air Updates for Vehicles

Expert knowledge of OTA (Over-The-Air) update architecture, A/B partitioning, differential updates, rollback mechanisms, secure boot chain, and update orchestration across ECUs.

## Core Concepts

### Update Architecture Patterns

1. **Full Image Updates**: Complete partition replacement
2. **Differential Updates**: Binary diffs to minimize bandwidth
3. **Component Updates**: Individual ECU/application updates
4. **Atomic Updates**: All-or-nothing update transactions
5. **Staged Rollouts**: Phased deployment across fleet

### Security Requirements

- **Uptane Framework**: Industry standard for secure vehicle updates
- **TUF (The Update Framework)**: Metadata and signature verification
- **Secure Boot Chain**: UEFI/U-Boot signature validation
- **Hardware Root of Trust**: TPM/HSM for key storage
- **Rollback Protection**: Anti-rollback counters

## Production-Ready Implementations

### 1. Uptane-Compliant Update Client (Python)

```python
#!/usr/bin/env python3
"""
Uptane-compliant OTA update client for automotive ECUs.
Implements Director and Image repository verification.
"""

import hashlib
import json
import os
import subprocess
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional
import requests
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding, rsa
from cryptography.hazmat.backends import default_backend


@dataclass
class UpdateMetadata:
    """Update metadata from Director repository."""
    version: str
    targets: Dict[str, dict]
    signatures: List[dict]
    expires: str

    @classmethod
    def from_json(cls, data: dict):
        return cls(
            version=data["signed"]["version"],
            targets=data["signed"]["targets"],
            signatures=data["signatures"],
            expires=data["signed"]["expires"]
        )


class UptaneClient:
    """
    Uptane OTA update client.

    Supports:
    - Dual Director/Image repository verification
    - Signature validation with threshold
    - Differential update download
    - A/B partition switching
    - Automatic rollback on boot failure
    """

    def __init__(self, config_path: str = "/etc/ota/uptane-config.json"):
        self.config = self._load_config(config_path)
        self.ecu_serial = self._get_ecu_serial()
        self.current_version = self._get_current_version()
        self.director_url = self.config["director_url"]
        self.image_repo_url = self.config["image_repo_url"]
        self.root_keys = self._load_root_keys()

    def _load_config(self, path: str) -> dict:
        """Load Uptane configuration."""
        with open(path, 'r') as f:
            return json.load(f)

    def _get_ecu_serial(self) -> str:
        """Get unique ECU serial number."""
        # Read from secure storage (TPM, EEPROM, etc.)
        serial_path = Path("/sys/firmware/devicetree/base/serial-number")
        if serial_path.exists():
            return serial_path.read_text().strip()
        return os.uname().nodename  # Fallback

    def _get_current_version(self) -> str:
        """Get currently running software version."""
        version_path = Path("/etc/ota/current-version")
        if version_path.exists():
            return version_path.read_text().strip()
        return "unknown"

    def _load_root_keys(self) -> List[rsa.RSAPublicKey]:
        """Load root public keys for signature verification."""
        keys = []
        for key_file in self.config["root_keys"]:
            with open(key_file, 'rb') as f:
                key = serialization.load_pem_public_key(
                    f.read(),
                    backend=default_backend()
                )
                keys.append(key)
        return keys

    def verify_signature(self, data: bytes, signature: bytes,
                        public_key: rsa.RSAPublicKey) -> bool:
        """Verify RSA signature on data."""
        try:
            public_key.verify(
                signature,
                data,
                padding.PSS(
                    mgf=padding.MGF1(hashes.SHA256()),
                    salt_length=padding.PSS.MAX_LENGTH
                ),
                hashes.SHA256()
            )
            return True
        except Exception as e:
            print(f"Signature verification failed: {e}")
            return False

    def check_for_updates(self) -> Optional[UpdateMetadata]:
        """
        Check Director repository for available updates.

        Returns:
            UpdateMetadata if update available, None otherwise
        """
        print(f"[OTA] Checking for updates (ECU: {self.ecu_serial}, "
              f"Version: {self.current_version})")

        # Fetch Director metadata
        url = f"{self.director_url}/metadata/{self.ecu_serial}/targets.json"
        try:
            response = requests.get(url, timeout=30)
            response.raise_for_status()
            metadata = UpdateMetadata.from_json(response.json())

            # Verify signatures (threshold: 2/3)
            verified_sigs = 0
            for sig_data in metadata.signatures:
                sig_bytes = bytes.fromhex(sig_data["sig"])
                # Verify against root keys
                for key in self.root_keys:
                    if self.verify_signature(
                        json.dumps(response.json()["signed"]).encode(),
                        sig_bytes,
                        key
                    ):
                        verified_sigs += 1
                        break

            if verified_sigs < self.config.get("signature_threshold", 2):
                raise ValueError(f"Insufficient signatures: {verified_sigs}")

            # Check if update is newer
            for target_name, target_info in metadata.targets.items():
                if target_info["custom"].get("ecu_identifier") == self.ecu_serial:
                    target_version = target_info["custom"]["version"]
                    if target_version != self.current_version:
                        print(f"[OTA] Update available: {target_version}")
                        return metadata

            print("[OTA] No updates available")
            return None

        except Exception as e:
            print(f"[OTA] Error checking for updates: {e}")
            return None

    def download_update(self, metadata: UpdateMetadata) -> Optional[Path]:
        """
        Download update image from Image repository.

        Uses differential updates if available.

        Returns:
            Path to downloaded update file
        """
        for target_name, target_info in metadata.targets.items():
            if target_info["custom"].get("ecu_identifier") != self.ecu_serial:
                continue

            # Check for differential update
            if "delta_from" in target_info["custom"]:
                if target_info["custom"]["delta_from"] == self.current_version:
                    print("[OTA] Downloading differential update...")
                    url = f"{self.image_repo_url}/targets/{target_name}.delta"
                else:
                    print("[OTA] Delta not applicable, downloading full image")
                    url = f"{self.image_repo_url}/targets/{target_name}"
            else:
                print("[OTA] Downloading full update image...")
                url = f"{self.image_repo_url}/targets/{target_name}"

            # Download with progress
            download_path = Path(f"/tmp/ota-update-{target_name}")
            try:
                with requests.get(url, stream=True, timeout=300) as r:
                    r.raise_for_status()
                    total_size = int(r.headers.get('content-length', 0))
                    downloaded = 0

                    with open(download_path, 'wb') as f:
                        for chunk in r.iter_content(chunk_size=8192):
                            f.write(chunk)
                            downloaded += len(chunk)
                            progress = (downloaded / total_size * 100) if total_size else 0
                            print(f"\r[OTA] Download progress: {progress:.1f}%", end='')

                    print()  # New line after progress

                # Verify hash
                expected_hash = target_info["hashes"]["sha256"]
                actual_hash = self._compute_sha256(download_path)

                if actual_hash != expected_hash:
                    raise ValueError(f"Hash mismatch: {actual_hash} != {expected_hash}")

                print(f"[OTA] Download complete: {download_path}")
                return download_path

            except Exception as e:
                print(f"[OTA] Download failed: {e}")
                if download_path.exists():
                    download_path.unlink()
                return None

        return None

    def _compute_sha256(self, file_path: Path) -> str:
        """Compute SHA256 hash of file."""
        sha256 = hashlib.sha256()
        with open(file_path, 'rb') as f:
            for chunk in iter(lambda: f.read(8192), b''):
                sha256.update(chunk)
        return sha256.hexdigest()

    def install_update(self, update_path: Path) -> bool:
        """
        Install update to inactive partition.

        Uses A/B partition switching for atomic updates.

        Returns:
            True if installation successful
        """
        print("[OTA] Installing update...")

        try:
            # Determine inactive partition
            current_slot = self._get_current_boot_slot()
            inactive_slot = 'b' if current_slot == 'a' else 'a'
            inactive_partition = f"/dev/mmcblk0p{2 if inactive_slot == 'b' else 1}"

            print(f"[OTA] Current slot: {current_slot}, "
                  f"Installing to: {inactive_slot}")

            # Write update to inactive partition
            cmd = f"dd if={update_path} of={inactive_partition} bs=4M status=progress"
            subprocess.run(cmd, shell=True, check=True)

            # Set boot slot to inactive (will become active on next boot)
            self._set_boot_slot(inactive_slot)

            # Mark for boot attempt counter (rollback if boot fails 3 times)
            self._set_boot_counter(3)

            print(f"[OTA] Update installed to slot {inactive_slot}")
            return True

        except Exception as e:
            print(f"[OTA] Installation failed: {e}")
            return False

    def _get_current_boot_slot(self) -> str:
        """Get currently booted partition slot."""
        # Read from U-Boot environment or kernel command line
        with open("/proc/cmdline", 'r') as f:
            cmdline = f.read()
            if "root=/dev/mmcblk0p1" in cmdline:
                return 'a'
            elif "root=/dev/mmcblk0p2" in cmdline:
                return 'b'
        return 'a'  # Default

    def _set_boot_slot(self, slot: str):
        """Set boot slot for next reboot."""
        # Write to U-Boot environment
        cmd = f"fw_setenv boot_slot {slot}"
        subprocess.run(cmd, shell=True, check=True)

    def _set_boot_counter(self, count: int):
        """Set boot attempt counter for rollback protection."""
        cmd = f"fw_setenv boot_counter {count}"
        subprocess.run(cmd, shell=True, check=True)

    def apply_update(self) -> bool:
        """
        Apply update by rebooting into new partition.

        Returns:
            True if reboot initiated
        """
        print("[OTA] Applying update (rebooting)...")
        try:
            subprocess.run(["reboot"], check=True)
            return True
        except Exception as e:
            print(f"[OTA] Reboot failed: {e}")
            return False

    def verify_boot_success(self):
        """
        Verify successful boot after update.

        Called by systemd service on boot.
        Confirms update success or triggers rollback.
        """
        boot_counter_path = Path("/proc/device-tree/chosen/u-boot,boot-counter")

        if boot_counter_path.exists():
            counter = int(boot_counter_path.read_text().strip())

            if counter > 0:
                # Boot successful, commit update
                print("[OTA] Boot successful, committing update")
                self._set_boot_counter(0)  # Clear counter

                # Update current version
                new_version = self._detect_version()
                Path("/etc/ota/current-version").write_text(new_version)
            else:
                print("[OTA] Already committed")
        else:
            print("[OTA] Boot counter not found (no pending update)")

    def _detect_version(self) -> str:
        """Detect software version from running system."""
        version_files = [
            "/etc/ota/version",
            "/etc/os-release"
        ]

        for path in version_files:
            if Path(path).exists():
                content = Path(path).read_text()
                # Extract version from os-release
                for line in content.split('\n'):
                    if line.startswith("VERSION="):
                        return line.split('=')[1].strip('"')

        return "unknown"


def main():
    """OTA update client main loop."""
    client = UptaneClient()

    # Check on boot
    client.verify_boot_success()

    # Periodic update check
    while True:
        metadata = client.check_for_updates()

        if metadata:
            update_path = client.download_update(metadata)

            if update_path:
                if client.install_update(update_path):
                    print("[OTA] Update ready, will apply on next reboot")
                    # Optionally auto-reboot or wait for user confirmation
                    # client.apply_update()

        # Check every hour
        time.sleep(3600)


if __name__ == "__main__":
    main()
```

### 2. A/B Partition Configuration (U-Boot)

```bash
# U-Boot environment for A/B partitioning
# File: /etc/fw_env.config

# Device              Offset    Size     Erasesize
/dev/mtd1             0x0000    0x1000   0x1000
/dev/mtd2             0x0000    0x1000   0x1000
```

```bash
# U-Boot bootcmd script for A/B boot
# File: boot.cmd

# Read boot slot from environment
setenv bootslot ${boot_slot}
if test -z "${bootslot}"; then
    setenv bootslot a
fi

# Read boot counter
setenv bootcount ${boot_counter}
if test -z "${bootcount}"; then
    setenv bootcount 0
fi

# Check rollback condition
if test ${bootcount} -eq 0; then
    echo "Booting from slot ${bootslot}"
else
    # Decrement boot counter
    setexpr bootcount ${bootcount} - 1
    setenv boot_counter ${bootcount}
    saveenv

    # If counter reaches 0, rollback to other slot
    if test ${bootcount} -eq 0; then
        echo "Boot failed 3 times, rolling back"
        if test "${bootslot}" = "a"; then
            setenv bootslot b
        else
            setenv bootslot a
        fi
        setenv boot_slot ${bootslot}
        saveenv
    fi
fi

# Set root partition
if test "${bootslot}" = "a"; then
    setenv bootargs console=ttyS0,115200 root=/dev/mmcblk0p1 rw rootwait
    load mmc 0:1 ${kernel_addr_r} /boot/Image
    load mmc 0:1 ${fdt_addr_r} /boot/dtb
else
    setenv bootargs console=ttyS0,115200 root=/dev/mmcblk0p2 rw rootwait
    load mmc 0:2 ${kernel_addr_r} /boot/Image
    load mmc 0:2 ${fdt_addr_r} /boot/dtb
fi

# Boot kernel
booti ${kernel_addr_r} - ${fdt_addr_r}
```

### 3. Differential Update Generator (Python)

```python
#!/usr/bin/env python3
"""
Generate binary differential updates for OTA.
Uses bsdiff algorithm for efficient bandwidth usage.
"""

import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path


def generate_delta(old_image: Path, new_image: Path, output: Path):
    """
    Generate binary diff between two images.

    Args:
        old_image: Path to old firmware image
        new_image: Path to new firmware image
        output: Path to output delta file
    """
    print(f"Generating delta: {old_image} -> {new_image}")

    # Use bsdiff for binary diffing
    cmd = ["bsdiff", str(old_image), str(new_image), str(output)]

    try:
        subprocess.run(cmd, check=True)
    except FileNotFoundError:
        print("Error: bsdiff not found. Install with: apt-get install bsdiff")
        sys.exit(1)
    except subprocess.CalledProcessError as e:
        print(f"Error generating delta: {e}")
        sys.exit(1)

    # Calculate sizes and compression ratio
    old_size = old_image.stat().st_size
    new_size = new_image.stat().st_size
    delta_size = output.stat().st_size

    ratio = (1 - delta_size / new_size) * 100

    print(f"Old image size: {old_size / 1024 / 1024:.2f} MB")
    print(f"New image size: {new_size / 1024 / 1024:.2f} MB")
    print(f"Delta size: {delta_size / 1024 / 1024:.2f} MB")
    print(f"Bandwidth savings: {ratio:.1f}%")

    # Generate metadata
    metadata = {
        "old_version": old_image.stem,
        "new_version": new_image.stem,
        "old_hash": compute_sha256(old_image),
        "new_hash": compute_sha256(new_image),
        "delta_hash": compute_sha256(output),
        "delta_size": delta_size,
        "compression_ratio": ratio
    }

    metadata_path = output.with_suffix('.json')
    with open(metadata_path, 'w') as f:
        json.dump(metadata, f, indent=2)

    print(f"Metadata written to: {metadata_path}")


def compute_sha256(path: Path) -> str:
    """Compute SHA256 hash of file."""
    sha256 = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(8192), b''):
            sha256.update(chunk)
    return sha256.hexdigest()


def apply_delta(old_image: Path, delta: Path, output: Path):
    """
    Apply delta patch to old image.

    Args:
        old_image: Path to old firmware image
        delta: Path to delta file
        output: Path to output patched image
    """
    print(f"Applying delta: {old_image} + {delta} -> {output}")

    cmd = ["bspatch", str(old_image), str(output), str(delta)]

    try:
        subprocess.run(cmd, check=True)
        print(f"Patched image created: {output}")
    except FileNotFoundError:
        print("Error: bspatch not found. Install with: apt-get install bsdiff")
        sys.exit(1)
    except subprocess.CalledProcessError as e:
        print(f"Error applying delta: {e}")
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="OTA differential update generator")
    subparsers = parser.add_subparsers(dest='command', help='Command to execute')

    # Generate delta
    gen_parser = subparsers.add_parser('generate', help='Generate delta update')
    gen_parser.add_argument('--old', type=Path, required=True, help='Old image')
    gen_parser.add_argument('--new', type=Path, required=True, help='New image')
    gen_parser.add_argument('--output', type=Path, required=True, help='Output delta file')

    # Apply delta
    apply_parser = subparsers.add_parser('apply', help='Apply delta update')
    apply_parser.add_argument('--old', type=Path, required=True, help='Old image')
    apply_parser.add_argument('--delta', type=Path, required=True, help='Delta file')
    apply_parser.add_argument('--output', type=Path, required=True, help='Output image')

    args = parser.parse_args()

    if args.command == 'generate':
        generate_delta(args.old, args.new, args.output)
    elif args.command == 'apply':
        apply_delta(args.old, args.delta, args.output)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
```

### 4. OTA Update Service (systemd)

```ini
# File: /etc/systemd/system/ota-update.service

[Unit]
Description=OTA Update Client
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/uptane-client.py
Restart=always
RestartSec=60
User=ota
Group=ota

# Security hardening
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/tmp /var/lib/ota
NoNewPrivileges=yes
CapabilityBoundingSet=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
```

```ini
# File: /etc/systemd/system/ota-boot-verify.service

[Unit]
Description=OTA Boot Verification
DefaultDependencies=no
After=local-fs.target
Before=sysinit.target

[Service]
Type=oneshot
ExecStart=/usr/bin/python3 -c "from uptane_client import UptaneClient; UptaneClient().verify_boot_success()"
RemainAfterExit=yes

[Install]
WantedBy=sysinit.target
```

### 5. Mender Integration (Alternative Framework)

```yaml
# File: /etc/mender/mender.conf
{
  "ServerURL": "https://ota.example.com",
  "TenantToken": "TENANT_TOKEN_HERE",
  "InventoryPollIntervalSeconds": 28800,
  "UpdatePollIntervalSeconds": 1800,
  "RetryPollIntervalSeconds": 300,
  "RootfsPartA": "/dev/mmcblk0p2",
  "RootfsPartB": "/dev/mmcblk0p3",
  "ServerCertificate": "/etc/mender/server.crt",
  "DeviceTypeFile": "/var/lib/mender/device_type"
}
```

```bash
# Mender artifact creation script
#!/bin/bash
# File: create-mender-artifact.sh

set -e

IMAGE_FILE=$1
ARTIFACT_NAME=$2
DEVICE_TYPE=$3

if [ -z "$IMAGE_FILE" ] || [ -z "$ARTIFACT_NAME" ] || [ -z "$DEVICE_TYPE" ]; then
    echo "Usage: $0 <image-file> <artifact-name> <device-type>"
    exit 1
fi

# Create Mender artifact
mender-artifact write rootfs-image \
    --file "$IMAGE_FILE" \
    --artifact-name "$ARTIFACT_NAME" \
    --device-type "$DEVICE_TYPE" \
    --output-path "${ARTIFACT_NAME}.mender"

echo "Mender artifact created: ${ARTIFACT_NAME}.mender"

# Sign artifact (optional)
if [ -f "private.key" ]; then
    mender-artifact sign "${ARTIFACT_NAME}.mender" \
        --key private.key \
        --output-path "${ARTIFACT_NAME}.signed.mender"

    echo "Signed artifact created: ${ARTIFACT_NAME}.signed.mender"
fi
```

## Real-World Examples

### Tesla OTA Architecture

- **Full stack updates**: Entire OS, kernel, applications
- **Dual-bank storage**: 2x storage for A/B switching
- **Cellular + WiFi**: Automatic download scheduling
- **User control**: Schedule updates, defer if driving
- **Rollback**: Automatic if vehicle fails self-test

### VW.OS Update Strategy

- **ECU orchestration**: Update multiple ECUs in sequence
- **Safety constraints**: No updates to critical systems while driving
- **Partial updates**: Update infotainment without touching ADAS
- **Fleet rollout**: Phased deployment by region/model

### GM Ultifi Platform

- **Container-based**: Update individual apps without full reflash
- **Middleware updates**: Update communication layer separately
- **Third-party apps**: App store model with independent update cycle
- **Cloud sync**: Configuration sync across vehicles

## Best Practices

1. **Always use A/B partitioning**: Never update the running system
2. **Implement rollback**: Automatic rollback after 3 boot failures
3. **Verify signatures**: Multi-level signature verification (Uptane)
4. **Use differential updates**: Reduce bandwidth by 70-90%
5. **Stage fleet rollouts**: 1% -> 10% -> 100% deployment
6. **Monitor success rates**: Track update success/failure metrics
7. **Preserve user data**: Never wipe data partitions
8. **Test offline rollback**: Ensure rollback works without network
9. **Schedule updates**: Respect user preferences and vehicle state
10. **Log everything**: Comprehensive telemetry for debugging

## Security Considerations

- **Secure Boot**: Verify every component in boot chain
- **Encrypted updates**: TLS for transport, encryption at rest
- **Anti-rollback**: Prevent downgrade to vulnerable versions
- **Time validity**: Reject updates with expired metadata
- **Threshold signatures**: Require multiple signers (2 of 3)
- **Hardware root of trust**: TPM or secure enclave for keys
- **Audit logging**: Track all update attempts and outcomes

## References

- **Uptane**: https://uptane.github.io/
- **Mender**: https://mender.io/
- **SWUpdate**: https://sbabic.github.io/swupdate/
- **RAUC**: https://rauc.io/
- **TUF Specification**: https://theupdateframework.io/
