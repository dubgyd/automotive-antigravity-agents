# V2X Security and Certificates

## Overview
Comprehensive guide to V2X security including IEEE 1609.2 security services, SCMS (Security Credential Management System), certificate enrollment, pseudonym certificates, misbehavior detection, and revocation mechanisms.

## IEEE 1609.2 Security Standard

### Security Services

**Core Security Goals:**
```
1. Authentication: Verify message sender identity
2. Integrity: Detect message tampering
3. Non-repudiation: Sender cannot deny transmission
4. Privacy: Protect sender identity (pseudonymity)
5. Confidentiality: Encrypt sensitive data (optional for V2V)
```

### Certificate Types

| Certificate Type | Purpose | Lifetime | Usage |
|-----------------|---------|----------|-------|
| Root CA | Trust anchor | 10-20 years | Signs intermediate CAs |
| Intermediate CA | Issue enrollment certs | 3-5 years | Signs PCAs and enrollment certs |
| PCA (Pseudonym CA) | Issue pseudonym certs | 3-5 years | Signs pseudonym certificates |
| Enrollment Certificate | Device identity | 3 years | Request pseudonym certificates |
| Pseudonym Certificate | Message signing | 1 week | Sign BSMs, CAMs, etc. |
| Application Certificate | Specific app | Variable | Application-specific signing |

### IEEE 1609.2 Message Structure

```cpp
// ieee1609dot2_message.hpp
#pragma once

#include <vector>
#include <cstdint>
#include <array>

namespace v2x {
namespace security {

// ECDSA-256 with NIST P-256 curve
constexpr size_t SIGNATURE_SIZE = 64;  // r || s (32 bytes each)
constexpr size_t PUBLIC_KEY_SIZE = 64;  // x || y coordinates
constexpr size_t CERT_ID_SIZE = 8;     // HashedId8

enum class SecurityProfileIdentifier : uint8_t {
    NO_SECURITY = 0,
    BSM_SIGN = 1,
    DENM_SIGN = 2,
    CAM_SIGN = 3
};

// Hashed certificate identifier
using HashedId8 = std::array<uint8_t, CERT_ID_SIZE>;

// ECDSA signature
struct ECDSASignature {
    std::array<uint8_t, 32> r;
    std::array<uint8_t, 32> s;
};

// Public key (ECC Point)
struct ECCPoint {
    uint8_t compression;  // 0x04 for uncompressed
    std::array<uint8_t, 32> x;
    std::array<uint8_t, 32> y;
};

// Certificate structure (simplified IEEE 1609.2)
struct Certificate {
    uint8_t version;  // v3 = 3
    uint8_t type;     // explicit = 0, implicit = 1
    HashedId8 issuer; // Hashed ID of issuing CA

    // Subject info
    uint8_t subject_type;  // enrollment_credential = 0, pseudonym = 1

    // Validity period
    uint32_t start_time;  // Seconds since 2004-01-01 00:00:00 UTC
    uint32_t end_time;

    // Public key
    ECCPoint public_key;

    // Permissions (application permissions)
    std::vector<uint8_t> app_permissions;

    // Issuer signature
    ECDSASignature signature;
};

// Secured message structure
struct SecuredMessage {
    uint8_t protocol_version;  // 3 for IEEE 1609.2-2016

    // Header
    uint8_t security_profile;
    uint32_t generation_time;  // Microseconds since 2004-01-01
    uint64_t generation_location;  // 3D location (lat, lon, elev)

    // Signer info
    enum SignerType : uint8_t {
        CERTIFICATE = 0,
        CERTIFICATE_DIGEST = 1,
        CERTIFICATE_CHAIN = 2
    } signer_type;

    union {
        Certificate certificate;
        HashedId8 cert_digest;
        std::vector<Certificate> cert_chain;
    } signer_info;

    // Payload
    std::vector<uint8_t> payload;  // Actual message (BSM, CAM, etc.)

    // Signature
    ECDSASignature signature;
};

class IEEE1609Dot2Security {
public:
    IEEE1609Dot2Security();

    // Sign a message with pseudonym certificate
    SecuredMessage signMessage(
        const std::vector<uint8_t>& payload,
        const Certificate& signing_cert,
        const std::array<uint8_t, 32>& private_key,
        SecurityProfileIdentifier profile
    );

    // Verify received secured message
    bool verifyMessage(
        const SecuredMessage& secured_msg,
        const std::vector<Certificate>& trusted_certs
    );

    // Extract payload from secured message
    std::vector<uint8_t> extractPayload(const SecuredMessage& secured_msg);

private:
    // ECDSA sign with NIST P-256
    ECDSASignature ecdsaSign(
        const std::vector<uint8_t>& data,
        const std::array<uint8_t, 32>& private_key
    );

    // ECDSA verify
    bool ecdsaVerify(
        const std::vector<uint8_t>& data,
        const ECDSASignature& signature,
        const ECCPoint& public_key
    );

    // SHA-256 hash
    std::array<uint8_t, 32> sha256(const std::vector<uint8_t>& data);

    // Generate HashedId8 from certificate
    HashedId8 hashCertificate(const Certificate& cert);
};

} // namespace security
} // namespace v2x
```

## Security Credential Management System (SCMS)

### SCMS Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    SCMS Root CA                              │
│  (Offline, air-gapped, generates root certificate)          │
└────────────────────────┬─────────────────────────────────────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
        ▼                ▼                ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ Intermediate │  │ Intermediate │  │ Intermediate │
│   CA (ICA)   │  │   CA (ICA)   │  │   CA (ICA)   │
└──────┬───────┘  └──────┬───────┘  └──────┬───────┘
       │                 │                 │
       └────────┬────────┴─────────────────┘
                │
        ┌───────┴────────┐
        │                │
        ▼                ▼
┌──────────────┐  ┌──────────────┐
│ Enrollment   │  │  Pseudonym   │
│ Certificate  │  │   CA (PCA)   │
│ Authority    │  │              │
│   (ECA)      │  │              │
└──────┬───────┘  └──────┬───────┘
       │                 │
       │                 │
       │    ┌────────────┼────────────┐
       │    │            │            │
       ▼    ▼            ▼            ▼
    ┌─────────────────────────────────────┐
    │           OBU (Vehicle)             │
    │  - Enrollment Certificate           │
    │  - Pseudonym Certificate Pool       │
    │    (100-300 certificates)           │
    │  - Certificate change strategy      │
    └─────────────────────────────────────┘
```

### Certificate Enrollment Process

```python
# scms_enrollment.py
"""
SCMS certificate enrollment and pseudonym management.
"""

import hashlib
import secrets
import time
from dataclasses import dataclass
from typing import List, Optional
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.backends import default_backend

@dataclass
class CertificateRequest:
    """Certificate Signing Request (CSR)"""
    subject_type: str  # "enrollment" or "pseudonym"
    public_key: bytes  # DER encoded public key
    validity_period_days: int
    permissions: List[str]  # ["bsm", "denm", "cam"]
    request_time: int
    nonce: bytes

@dataclass
class Certificate:
    """V2X Certificate"""
    version: int
    cert_id: bytes  # HashedId8
    issuer_id: bytes  # HashedId8
    subject_type: str
    public_key: bytes
    start_time: int  # Epoch
    end_time: int
    permissions: List[str]
    signature: bytes

    def is_valid(self, current_time: int) -> bool:
        """Check if certificate is currently valid."""
        return self.start_time <= current_time <= self.end_time

    def is_expired(self, current_time: int) -> bool:
        """Check if certificate has expired."""
        return current_time > self.end_time

class SCMSEnrollment:
    """
    SCMS certificate enrollment and management.
    """

    def __init__(self, device_id: str):
        self.device_id = device_id

        # Generate enrollment key pair (long-term)
        self.enrollment_private_key = ec.generate_private_key(
            ec.SECP256R1(), default_backend()
        )
        self.enrollment_public_key = self.enrollment_private_key.public_key()

        # Certificate storage
        self.enrollment_cert: Optional[Certificate] = None
        self.pseudonym_cert_pool: List[Certificate] = []
        self.current_pseudonym_index: int = 0

        # Revocation list
        self.revoked_cert_ids: set = set()

    def enroll(self, eca_url: str) -> bool:
        """
        Enroll with SCMS Enrollment Certificate Authority.

        Args:
            eca_url: URL of ECA service

        Returns:
            True if enrollment successful
        """
        print(f"Enrolling device {self.device_id} with ECA...")

        # Create enrollment certificate request
        csr = CertificateRequest(
            subject_type="enrollment",
            public_key=self.enrollment_public_key.public_bytes(
                encoding=serialization.Encoding.DER,
                format=serialization.PublicFormat.SubjectPublicKeyInfo
            ),
            validity_period_days=1095,  # 3 years
            permissions=["request_pseudonym_certs"],
            request_time=int(time.time()),
            nonce=secrets.token_bytes(16)
        )

        # Sign CSR with enrollment private key
        csr_signature = self._sign_request(csr)

        # Send to ECA (simulated)
        enrollment_cert = self._request_enrollment_cert(eca_url, csr, csr_signature)

        if enrollment_cert:
            self.enrollment_cert = enrollment_cert
            print(f"Enrollment successful. Certificate ID: {enrollment_cert.cert_id.hex()}")
            return True
        else:
            print("Enrollment failed")
            return False

    def request_pseudonym_certificates(
        self,
        pca_url: str,
        count: int = 20,
        duration_days: int = 7
    ) -> int:
        """
        Request batch of pseudonym certificates from PCA.

        Args:
            pca_url: URL of PCA service
            count: Number of pseudonym certificates to request
            duration_days: Validity period for each certificate

        Returns:
            Number of certificates received
        """
        if not self.enrollment_cert:
            print("ERROR: Must enroll first")
            return 0

        print(f"Requesting {count} pseudonym certificates from PCA...")

        # Generate key pairs for pseudonym certificates
        pseudonym_keys = []
        for i in range(count):
            private_key = ec.generate_private_key(ec.SECP256R1(), default_backend())
            public_key = private_key.public_key()
            pseudonym_keys.append((private_key, public_key))

        # Create batch request
        public_keys_der = [
            pk.public_bytes(
                encoding=serialization.Encoding.DER,
                format=serialization.PublicFormat.SubjectPublicKeyInfo
            )
            for _, pk in pseudonym_keys
        ]

        # Request pseudonym certificates (simulated)
        pseudonym_certs = self._request_pseudonym_certs(
            pca_url,
            public_keys_der,
            duration_days
        )

        if pseudonym_certs:
            self.pseudonym_cert_pool.extend(pseudonym_certs)
            print(f"Received {len(pseudonym_certs)} pseudonym certificates")
            print(f"Certificate pool size: {len(self.pseudonym_cert_pool)}")
            return len(pseudonym_certs)

        return 0

    def get_current_pseudonym_cert(self) -> Optional[Certificate]:
        """Get current pseudonym certificate for message signing."""
        if not self.pseudonym_cert_pool:
            return None

        # Check if current cert is still valid
        current_time = int(time.time())
        current_cert = self.pseudonym_cert_pool[self.current_pseudonym_index]

        if current_cert.is_expired(current_time):
            # Move to next certificate
            self.rotate_pseudonym_cert()
            current_cert = self.pseudonym_cert_pool[self.current_pseudonym_index]

        return current_cert

    def rotate_pseudonym_cert(self):
        """
        Rotate to next pseudonym certificate.

        Certificate change strategy:
        - Time-based: Every 5 minutes
        - Location-based: When crossing region boundaries
        - Random: Add unpredictability
        """
        if not self.pseudonym_cert_pool:
            return

        # Move to next certificate in pool
        self.current_pseudonym_index = (self.current_pseudonym_index + 1) % len(self.pseudonym_cert_pool)

        new_cert = self.pseudonym_cert_pool[self.current_pseudonym_index]
        print(f"Rotated to pseudonym certificate: {new_cert.cert_id.hex()[:16]}...")

        # Check pool health
        current_time = int(time.time())
        valid_certs = sum(1 for cert in self.pseudonym_cert_pool if cert.is_valid(current_time))

        if valid_certs < 10:
            print(f"WARNING: Only {valid_certs} valid certificates remaining")
            print("Consider requesting new batch")

    def check_revocation(self, cert_id: bytes, crl_url: str) -> bool:
        """
        Check if certificate has been revoked.

        Args:
            cert_id: Certificate ID to check
            crl_url: URL of Certificate Revocation List

        Returns:
            True if revoked, False otherwise
        """
        # Check local cache
        if cert_id in self.revoked_cert_ids:
            return True

        # Query CRL (simulated)
        # In production, download and verify CRL signature
        is_revoked = self._query_crl(crl_url, cert_id)

        if is_revoked:
            self.revoked_cert_ids.add(cert_id)

        return is_revoked

    def _sign_request(self, csr: CertificateRequest) -> bytes:
        """Sign certificate request with enrollment private key."""
        # Serialize CSR
        csr_bytes = self._serialize_csr(csr)

        # Sign with ECDSA
        signature = self.enrollment_private_key.sign(
            csr_bytes,
            ec.ECDSA(hashes.SHA256())
        )

        return signature

    def _serialize_csr(self, csr: CertificateRequest) -> bytes:
        """Serialize CSR to bytes."""
        # Simplified serialization
        data = b''
        data += csr.subject_type.encode()
        data += csr.public_key
        data += str(csr.validity_period_days).encode()
        data += ','.join(csr.permissions).encode()
        data += str(csr.request_time).encode()
        data += csr.nonce
        return data

    def _request_enrollment_cert(
        self,
        eca_url: str,
        csr: CertificateRequest,
        signature: bytes
    ) -> Optional[Certificate]:
        """
        Request enrollment certificate from ECA.
        (Simulated - in production, this would be HTTPS POST)
        """
        # Simulate ECA processing
        print(f"Connecting to ECA at {eca_url}")
        print("Verifying device identity...")
        print("Issuing enrollment certificate...")

        # Generate cert ID
        cert_id = hashlib.sha256(csr.public_key).digest()[:8]

        # Simulate issued certificate
        cert = Certificate(
            version=3,
            cert_id=cert_id,
            issuer_id=b'\x00' * 8,  # ECA ID
            subject_type="enrollment",
            public_key=csr.public_key,
            start_time=int(time.time()),
            end_time=int(time.time()) + (csr.validity_period_days * 86400),
            permissions=csr.permissions,
            signature=b'\x00' * 64  # Simulated signature
        )

        return cert

    def _request_pseudonym_certs(
        self,
        pca_url: str,
        public_keys: List[bytes],
        duration_days: int
    ) -> List[Certificate]:
        """
        Request pseudonym certificates from PCA.
        (Simulated)
        """
        print(f"Connecting to PCA at {pca_url}")
        print(f"Requesting {len(public_keys)} pseudonym certificates...")

        certs = []
        current_time = int(time.time())

        for i, pub_key in enumerate(public_keys):
            # Stagger validity periods to avoid all expiring at once
            start_time = current_time + (i * 3600)  # Start 1 hour apart
            end_time = start_time + (duration_days * 86400)

            cert_id = hashlib.sha256(pub_key + str(i).encode()).digest()[:8]

            cert = Certificate(
                version=3,
                cert_id=cert_id,
                issuer_id=b'\xFF' * 8,  # PCA ID
                subject_type="pseudonym",
                public_key=pub_key,
                start_time=start_time,
                end_time=end_time,
                permissions=["bsm", "cam", "denm"],
                signature=b'\x00' * 64
            )
            certs.append(cert)

        return certs

    def _query_crl(self, crl_url: str, cert_id: bytes) -> bool:
        """
        Query Certificate Revocation List.
        (Simulated)
        """
        # In production: Download CRL, verify signature, check cert_id
        return False  # Assume not revoked for simulation


# Example usage
if __name__ == "__main__":
    # Initialize SCMS enrollment
    enrollment = SCMSEnrollment(device_id="OBU-12345678")

    # Step 1: Enroll with ECA
    if enrollment.enroll(eca_url="https://eca.scms.example.com"):
        # Step 2: Request pseudonym certificates
        cert_count = enrollment.request_pseudonym_certificates(
            pca_url="https://pca.scms.example.com",
            count=20,
            duration_days=7
        )

        if cert_count > 0:
            # Step 3: Use pseudonym certificates
            for i in range(5):
                current_cert = enrollment.get_current_pseudonym_cert()
                if current_cert:
                    print(f"\nUsing certificate: {current_cert.cert_id.hex()[:16]}...")
                    print(f"  Valid until: {time.ctime(current_cert.end_time)}")

                    # Simulate certificate usage
                    time.sleep(1)

                    # Rotate after some time/messages
                    if i % 2 == 1:
                        enrollment.rotate_pseudonym_cert()
```

## Misbehavior Detection

### Misbehavior Types

| Misbehavior Category | Description | Detection Method |
|---------------------|-------------|------------------|
| Position Consistency | Impossible position jumps | Plausibility check |
| Speed Consistency | Unrealistic speed values | Physical limits check |
| Acceleration Consistency | Impossible acceleration | Physical limits check |
| Heading Consistency | Erratic heading changes | Temporal consistency |
| Duplicate Messages | Message replay attacks | Sequence number check |
| Invalid Signatures | Forged messages | Cryptographic verification |
| Revoked Certificates | Using revoked certs | CRL lookup |

### Misbehavior Detection Implementation

```cpp
// misbehavior_detector.hpp
#pragma once

#include <cstdint>
#include <map>
#include <deque>
#include <vector>

namespace v2x {
namespace security {

enum class MisbehaviorType {
    POSITION_JUMP,
    SPEED_EXCEEDED,
    ACCEL_EXCEEDED,
    HEADING_INCONSISTENT,
    DUPLICATE_MESSAGE,
    INVALID_SIGNATURE,
    REVOKED_CERTIFICATE,
    TIMEOUT,
    FREQUENCY_VIOLATION
};

struct VehicleStateHistory {
    uint32_t vehicle_id;
    double latitude;
    double longitude;
    double speed_mps;
    double heading_deg;
    uint32_t timestamp_ms;
    uint16_t message_count;
};

struct MisbehaviorReport {
    uint32_t sender_id;
    MisbehaviorType type;
    uint32_t detection_time;
    double confidence;  // 0.0-1.0
    std::string details;
};

class MisbehaviorDetector {
public:
    MisbehaviorDetector();

    // Process received V2V message
    std::vector<MisbehaviorReport> checkMessage(
        uint32_t sender_id,
        double latitude,
        double longitude,
        double speed_mps,
        double heading_deg,
        uint16_t msg_count,
        uint32_t timestamp_ms
    );

    // Check position plausibility
    bool checkPositionPlausibility(
        uint32_t sender_id,
        double lat,
        double lon,
        uint32_t timestamp_ms
    );

    // Check speed plausibility
    bool checkSpeedPlausibility(double speed_mps);

    // Check acceleration plausibility
    bool checkAccelerationPlausibility(
        uint32_t sender_id,
        double current_speed,
        uint32_t timestamp_ms
    );

    // Report misbehavior to misbehavior authority
    void reportMisbehavior(const MisbehaviorReport& report);

    // Get misbehavior score for sender
    double getMisbehaviorScore(uint32_t sender_id);

private:
    // Vehicle state history (last N messages per vehicle)
    std::map<uint32_t, std::deque<VehicleStateHistory>> history_;

    // Misbehavior scores
    std::map<uint32_t, double> misbehavior_scores_;

    // Physical limits
    const double MAX_SPEED_MPS = 70.0;  // 252 km/h
    const double MAX_ACCEL_MPS2 = 10.0;  // ~1g
    const double MAX_POSITION_JUMP_M = 200.0;  // 200m in 100ms
    const double MAX_HEADING_CHANGE_DEG = 45.0;  // per 100ms

    // History size
    const size_t HISTORY_SIZE = 10;

    // Calculate distance between two points
    double calculateDistance(double lat1, double lon1, double lat2, double lon2);

    // Update misbehavior score
    void updateMisbehaviorScore(uint32_t sender_id, double penalty);
};

} // namespace security
} // namespace v2x
```

## Certificate Revocation

### Certificate Revocation List (CRL)

```python
# certificate_revocation.py
"""
Certificate Revocation List (CRL) management.
"""

from dataclasses import dataclass
from typing import List, Set
import time
import hashlib

@dataclass
class CRLEntry:
    """Single entry in CRL."""
    cert_id: bytes  # HashedId8
    revocation_time: int  # Epoch timestamp
    reason: str  # "compromised", "misbehavior", "expired"

@dataclass
class CRL:
    """Certificate Revocation List."""
    version: int
    issuer_id: bytes  # CRL issuer (MA)
    this_update: int  # Epoch timestamp
    next_update: int  # Epoch timestamp
    revoked_certs: List[CRLEntry]
    signature: bytes  # MA signature

class CRLManager:
    """
    Manage Certificate Revocation Lists.
    """

    def __init__(self):
        self.current_crl: CRL = None
        self.revoked_cert_cache: Set[bytes] = set()
        self.last_update_time: int = 0

    def update_crl(self, new_crl: CRL) -> bool:
        """
        Update to new CRL version.

        Args:
            new_crl: New CRL from Misbehavior Authority

        Returns:
            True if CRL validated and updated
        """
        # Verify CRL signature (simplified)
        if not self._verify_crl_signature(new_crl):
            print("ERROR: CRL signature verification failed")
            return False

        # Check that CRL is newer
        if self.current_crl and new_crl.this_update <= self.current_crl.this_update:
            print("WARNING: CRL is not newer than current version")
            return False

        # Update revoked certificate cache
        self.revoked_cert_cache.clear()
        for entry in new_crl.revoked_certs:
            self.revoked_cert_cache.add(entry.cert_id)

        self.current_crl = new_crl
        self.last_update_time = int(time.time())

        print(f"CRL updated: {len(new_crl.revoked_certs)} revoked certificates")
        return True

    def is_revoked(self, cert_id: bytes) -> bool:
        """
        Check if certificate is revoked.

        Args:
            cert_id: Certificate ID (HashedId8)

        Returns:
            True if revoked
        """
        return cert_id in self.revoked_cert_cache

    def get_revocation_reason(self, cert_id: bytes) -> str:
        """Get revocation reason for certificate."""
        if not self.current_crl:
            return "unknown"

        for entry in self.current_crl.revoked_certs:
            if entry.cert_id == cert_id:
                return entry.reason

        return "not_revoked"

    def download_crl(self, crl_url: str) -> bool:
        """
        Download CRL from Misbehavior Authority.
        (Simulated)
        """
        print(f"Downloading CRL from {crl_url}")

        # Simulate CRL download
        # In production: HTTPS GET, verify signature

        new_crl = CRL(
            version=1,
            issuer_id=b'\xAA' * 8,
            this_update=int(time.time()),
            next_update=int(time.time()) + 86400,  # 24 hours
            revoked_certs=[],
            signature=b'\x00' * 64
        )

        return self.update_crl(new_crl)

    def _verify_crl_signature(self, crl: CRL) -> bool:
        """Verify CRL signature from Misbehavior Authority."""
        # In production: ECDSA verify with MA public key
        return True  # Simplified


# Example usage
if __name__ == "__main__":
    crl_mgr = CRLManager()

    # Download CRL
    crl_mgr.download_crl("https://ma.scms.example.com/crl")

    # Check if certificate is revoked
    test_cert_id = hashlib.sha256(b"test_certificate").digest()[:8]

    if crl_mgr.is_revoked(test_cert_id):
        reason = crl_mgr.get_revocation_reason(test_cert_id)
        print(f"Certificate revoked: {reason}")
    else:
        print("Certificate is valid (not revoked)")
```

## Security Performance Metrics

| Operation | Latency Target | Typical Implementation |
|-----------|---------------|----------------------|
| ECDSA Sign | < 2 ms | Hardware crypto accelerator |
| ECDSA Verify | < 5 ms | Hardware crypto accelerator |
| Certificate validation | < 10 ms | Local cache + CRL check |
| Message overhead | ~200-300 bytes | Certificate digest mode |
| Certificate change | < 1 ms | Pre-loaded cert pool |

## References

1. **IEEE 1609.2-2016**: Security Services for Applications and Management Messages
2. **SCMS Proof of Concept**: US Department of Transportation
3. **CAMP VSC3**: Vehicle Safety Communications 3 Consortium
4. **ETSI TS 103 097**: Security header and certificate formats
5. **C2C-CC**: Car 2 Car Communication Consortium Security Specifications
