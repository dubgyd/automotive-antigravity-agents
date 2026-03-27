# Containerized Vehicle Apps — Container Runtimes for Automotive

Expert knowledge of container runtimes for automotive (Docker, Podman, containerd), manifest formats, resource limits, inter-container communication, and orchestration (Kubernetes, K3s).

## Core Concepts

### Container Runtimes for Automotive

1. **containerd**: Lightweight, industry-standard container runtime
2. **Docker**: Full container platform (heavier footprint)
3. **Podman**: Daemonless, rootless containers
4. **LXC/LXD**: System containers for full OS isolation
5. **Balena Engine**: IoT-optimized Docker fork

### Why Containers in Vehicles?

- **Isolation**: Apps can't interfere with critical systems
- **Portability**: Same app runs on different vehicle models
- **Updates**: Update apps without full system reflash
- **Third-party apps**: Safe execution of untrusted code
- **Resource control**: CPU, memory, network limits per app

## Production-Ready Implementation

### 1. Vehicle Container Runtime (containerd + systemd)

```bash
#!/bin/bash
# File: setup-vehicle-container-runtime.sh
# Setup containerd for automotive use

set -e

echo "[Setup] Installing containerd for vehicle platform"

# Install containerd
apt-get update
apt-get install -y containerd

# Configure containerd for automotive
mkdir -p /etc/containerd
cat > /etc/containerd/config.toml <<EOF
version = 2

# Root directory for containerd
root = "/var/lib/containerd"
state = "/run/containerd"

# OCI runtime
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
  runtime_type = "io.containerd.runc.v2"

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
  SystemdCgroup = true

# Resource limits
[plugins."io.containerd.grpc.v1.cri".containerd]
  default_runtime_name = "runc"

# Registry configuration
[plugins."io.containerd.grpc.v1.cri".registry]
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."vehicle-registry.local:5000"]
      endpoint = ["http://vehicle-registry.local:5000"]

# CNI plugins for networking
[plugins."io.containerd.grpc.v1.cri".cni]
  bin_dir = "/opt/cni/bin"
  conf_dir = "/etc/cni/net.d"
EOF

# Enable and start containerd
systemctl enable containerd
systemctl start containerd

# Install CNI plugins
mkdir -p /opt/cni/bin
curl -L https://github.com/containernetworking/plugins/releases/download/v1.3.0/cni-plugins-linux-arm64-v1.3.0.tgz | \
  tar -C /opt/cni/bin -xz

# Configure CNI networking
mkdir -p /etc/cni/net.d
cat > /etc/cni/net.d/10-vehicle-bridge.conf <<EOF
{
  "cniVersion": "1.0.0",
  "name": "vehicle-bridge",
  "type": "bridge",
  "bridge": "veh0",
  "isGateway": true,
  "ipMasq": true,
  "ipam": {
    "type": "host-local",
    "subnet": "10.88.0.0/16",
    "routes": [
      { "dst": "0.0.0.0/0" }
    ]
  }
}
EOF

echo "[Setup] Container runtime ready"
```

### 2. App Manifest Format (OCI-compatible)

```yaml
# Vehicle app manifest (OCI-compatible)
# File: spotify-app.yaml

apiVersion: vehicle.io/v1
kind: VehicleApp
metadata:
  name: spotify
  namespace: infotainment
  labels:
    category: media
    vendor: spotify
    safety-critical: "false"

spec:
  # Container specification
  container:
    image: vehicle-registry.local:5000/spotify/automotive:2.1.4
    imagePullPolicy: IfNotPresent

    # Resource limits
    resources:
      requests:
        memory: "256Mi"
        cpu: "250m"
        storage: "1Gi"
      limits:
        memory: "512Mi"
        cpu: "500m"
        storage: "2Gi"
        network:
          bandwidth: "10Mbps"

    # Security context
    securityContext:
      runAsUser: 1000
      runAsGroup: 1000
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
      capabilities:
        drop:
          - ALL
        add:
          - NET_BIND_SERVICE  # For network access

    # Environment variables
    env:
      - name: API_KEY
        valueFrom:
          secretRef:
            name: spotify-credentials
            key: api-key
      - name: VEHICLE_VIN
        valueFrom:
          fieldRef:
            fieldPath: metadata.vin

    # Volume mounts
    volumeMounts:
      - name: cache
        mountPath: /app/cache
      - name: config
        mountPath: /app/config
        readOnly: true
      - name: dbus-socket
        mountPath: /var/run/dbus

  # Volumes
  volumes:
    - name: cache
      emptyDir:
        sizeLimit: 500Mi
    - name: config
      configMap:
        name: spotify-config
    - name: dbus-socket
      hostPath:
        path: /var/run/dbus
        type: Socket

  # Networking
  networking:
    ports:
      - name: http
        containerPort: 8080
        protocol: TCP
    hostNetwork: false
    dnsPolicy: ClusterFirst

  # Lifecycle hooks
  lifecycle:
    postStart:
      exec:
        command: ["/app/scripts/post-start.sh"]
    preStop:
      exec:
        command: ["/app/scripts/graceful-shutdown.sh"]

  # Health checks
  livenessProbe:
    httpGet:
      path: /health
      port: 8080
    initialDelaySeconds: 10
    periodSeconds: 30
  readinessProbe:
    httpGet:
      path: /ready
      port: 8080
    initialDelaySeconds: 5
    periodSeconds: 10

  # Service integration
  services:
    - name: media-player
      type: dbus
      interface: org.mpris.MediaPlayer2
    - name: steering-controls
      type: vehicle-bus
      permissions: [read]

  # Safety constraints
  safety:
    disableWhileDriving: false
    touchLimit: true
    requireVoiceControl: false
    criticalityLevel: low

  # Update strategy
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
```

### 3. Container Orchestrator (K3s for Automotive)

```bash
#!/bin/bash
# File: install-k3s-automotive.sh
# Install K3s (lightweight Kubernetes) for vehicle platform

set -e

echo "[K3s] Installing K3s for vehicle platform"

# Install K3s with automotive-specific configuration
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
  --disable traefik \
  --disable servicelb \
  --disable local-storage \
  --write-kubeconfig-mode 644 \
  --kubelet-arg=max-pods=50 \
  --kubelet-arg=eviction-hard=memory.available<100Mi \
  --kubelet-arg=eviction-soft=memory.available<200Mi \
  --kubelet-arg=eviction-soft-grace-period=memory.available=1m \
  --kube-controller-manager-arg=node-monitor-period=10s \
  --kube-controller-manager-arg=node-monitor-grace-period=30s" sh -

# Wait for K3s to start
sleep 10

# Install vehicle-specific CRDs
cat <<EOF | kubectl apply -f -
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: vehicleapps.vehicle.io
spec:
  group: vehicle.io
  versions:
    - name: v1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                container:
                  type: object
                safety:
                  type: object
                services:
                  type: array
  scope: Namespaced
  names:
    plural: vehicleapps
    singular: vehicleapp
    kind: VehicleApp
    shortNames:
      - vapp
EOF

# Create namespaces
kubectl create namespace infotainment
kubectl create namespace adas
kubectl create namespace diagnostics

# Install resource quotas
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: infotainment-quota
  namespace: infotainment
spec:
  hard:
    requests.cpu: "2"
    requests.memory: "4Gi"
    persistentvolumeclaims: "10"
EOF

echo "[K3s] Installation complete"
```

### 4. App Deployment Script (Python)

```python
#!/usr/bin/env python3
"""
Vehicle app deployment tool using containerd API.
"""

import subprocess
import json
import yaml
from pathlib import Path
from typing import Dict


class VehicleAppDeployer:
    """Deploy containerized apps to vehicle platform."""

    def __init__(self, runtime: str = "containerd"):
        self.runtime = runtime
        self.namespace = "vehicle-apps"

    def deploy_app(self, manifest_path: str):
        """
        Deploy app from manifest.

        Args:
            manifest_path: Path to app manifest YAML
        """
        with open(manifest_path, 'r') as f:
            manifest = yaml.safe_load(f)

        app_name = manifest['metadata']['name']
        print(f"[Deploy] Deploying {app_name}")

        # Pull container image
        self._pull_image(manifest['spec']['container']['image'])

        # Create namespace
        self._create_namespace(manifest['metadata']['namespace'])

        # Create container
        container_id = self._create_container(manifest)

        # Start container
        self._start_container(container_id)

        print(f"[Deploy] {app_name} deployed successfully (ID: {container_id})")

    def _pull_image(self, image: str):
        """Pull container image."""
        print(f"[Deploy] Pulling image: {image}")

        cmd = [
            "ctr", "-n", self.namespace,
            "image", "pull", image
        ]

        subprocess.run(cmd, check=True)

    def _create_namespace(self, namespace: str):
        """Create containerd namespace."""
        # Containerd namespaces are created automatically on first use
        pass

    def _create_container(self, manifest: Dict) -> str:
        """Create container from manifest."""
        spec = manifest['spec']
        metadata = manifest['metadata']

        app_name = metadata['name']
        image = spec['container']['image']

        # Build OCI runtime spec
        runtime_spec = self._build_runtime_spec(spec)

        # Write spec to file
        spec_path = f"/tmp/{app_name}-spec.json"
        with open(spec_path, 'w') as f:
            json.dump(runtime_spec, f, indent=2)

        # Create container
        cmd = [
            "ctr", "-n", self.namespace,
            "container", "create",
            "--runtime", "io.containerd.runc.v2",
            "--config", spec_path,
            image,
            app_name
        ]

        result = subprocess.run(cmd, capture_output=True, text=True)

        if result.returncode != 0:
            raise RuntimeError(f"Container creation failed: {result.stderr}")

        return app_name

    def _build_runtime_spec(self, spec: Dict) -> Dict:
        """Build OCI runtime specification."""
        container = spec['container']
        resources = container.get('resources', {})

        # Parse resource limits
        memory_limit = self._parse_memory(
            resources.get('limits', {}).get('memory', '512Mi')
        )
        cpu_quota = self._parse_cpu(
            resources.get('limits', {}).get('cpu', '500m')
        )

        # Build OCI spec
        oci_spec = {
            "ociVersion": "1.0.2",
            "process": {
                "terminal": False,
                "user": {
                    "uid": container.get('securityContext', {}).get('runAsUser', 1000),
                    "gid": container.get('securityContext', {}).get('runAsGroup', 1000)
                },
                "env": self._build_env(container.get('env', [])),
                "cwd": "/app",
                "capabilities": {
                    "bounding": ["CAP_NET_BIND_SERVICE"],
                    "effective": ["CAP_NET_BIND_SERVICE"],
                    "inheritable": ["CAP_NET_BIND_SERVICE"],
                    "permitted": ["CAP_NET_BIND_SERVICE"]
                },
                "rlimits": [
                    {
                        "type": "RLIMIT_NOFILE",
                        "hard": 1024,
                        "soft": 1024
                    }
                ],
                "noNewPrivileges": True
            },
            "root": {
                "path": "rootfs",
                "readonly": container.get('securityContext', {}).get(
                    'readOnlyRootFilesystem', True
                )
            },
            "mounts": self._build_mounts(spec.get('volumes', [])),
            "linux": {
                "namespaces": [
                    {"type": "pid"},
                    {"type": "network"},
                    {"type": "ipc"},
                    {"type": "uts"},
                    {"type": "mount"}
                ],
                "resources": {
                    "memory": {
                        "limit": memory_limit
                    },
                    "cpu": {
                        "quota": cpu_quota,
                        "period": 100000
                    }
                },
                "cgroupsPath": f"/vehicle-apps/{spec['container']['image'].split('/')[-1]}"
            }
        }

        return oci_spec

    def _build_env(self, env_vars: list) -> list:
        """Build environment variable list."""
        env = ["PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"]

        for var in env_vars:
            name = var['name']
            value = var.get('value')

            if value:
                env.append(f"{name}={value}")
            elif 'valueFrom' in var:
                # Resolve from secret/configmap
                # Simplified implementation
                env.append(f"{name}=<resolved-value>")

        return env

    def _build_mounts(self, volumes: list) -> list:
        """Build mount list."""
        mounts = [
            {
                "destination": "/proc",
                "type": "proc",
                "source": "proc"
            },
            {
                "destination": "/dev",
                "type": "tmpfs",
                "source": "tmpfs",
                "options": ["nosuid", "strictatime", "mode=755", "size=65536k"]
            },
            {
                "destination": "/dev/pts",
                "type": "devpts",
                "source": "devpts",
                "options": ["nosuid", "noexec", "newinstance", "ptmxmode=0666", "mode=0620"]
            },
            {
                "destination": "/sys",
                "type": "sysfs",
                "source": "sysfs",
                "options": ["nosuid", "noexec", "nodev", "ro"]
            }
        ]

        # Add application-specific mounts
        for volume in volumes:
            if volume.get('emptyDir'):
                mounts.append({
                    "destination": "/app/cache",
                    "type": "tmpfs",
                    "source": "tmpfs",
                    "options": ["nosuid", "nodev"]
                })
            elif volume.get('hostPath'):
                mounts.append({
                    "destination": "/var/run/dbus",
                    "type": "bind",
                    "source": volume['hostPath']['path'],
                    "options": ["rbind", "ro"]
                })

        return mounts

    def _start_container(self, container_id: str):
        """Start container."""
        print(f"[Deploy] Starting container: {container_id}")

        cmd = [
            "ctr", "-n", self.namespace,
            "task", "start", "-d",
            container_id
        ]

        subprocess.run(cmd, check=True)

    def _parse_memory(self, mem_str: str) -> int:
        """Parse memory string to bytes."""
        units = {'Ki': 1024, 'Mi': 1024**2, 'Gi': 1024**3}

        for unit, multiplier in units.items():
            if mem_str.endswith(unit):
                return int(mem_str[:-2]) * multiplier

        return int(mem_str)

    def _parse_cpu(self, cpu_str: str) -> int:
        """Parse CPU string to quota."""
        if cpu_str.endswith('m'):
            millicores = int(cpu_str[:-1])
            return millicores * 100  # quota in microseconds
        else:
            cores = float(cpu_str)
            return int(cores * 100000)

    def list_apps(self):
        """List deployed apps."""
        cmd = [
            "ctr", "-n", self.namespace,
            "container", "ls"
        ]

        result = subprocess.run(cmd, capture_output=True, text=True)
        print(result.stdout)

    def stop_app(self, app_name: str):
        """Stop running app."""
        print(f"[Deploy] Stopping app: {app_name}")

        # Stop task
        cmd = [
            "ctr", "-n", self.namespace,
            "task", "kill", app_name,
            "SIGTERM"
        ]

        subprocess.run(cmd, check=False)

    def remove_app(self, app_name: str):
        """Remove app."""
        print(f"[Deploy] Removing app: {app_name}")

        # Delete container
        cmd = [
            "ctr", "-n", self.namespace,
            "container", "rm", app_name
        ]

        subprocess.run(cmd, check=True)


def main():
    """Main deployment script."""
    deployer = VehicleAppDeployer()

    # Deploy app
    deployer.deploy_app("spotify-app.yaml")

    # List apps
    deployer.list_apps()


if __name__ == "__main__":
    main()
```

### 5. Inter-Container Communication (D-Bus)

```python
#!/usr/bin/env python3
"""
D-Bus service for inter-container communication.
Allows sandboxed apps to communicate with vehicle services.
"""

import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib


class VehicleServiceBus(dbus.service.Object):
    """
    D-Bus service for vehicle platform.

    Provides APIs for apps to:
    - Get vehicle state
    - Control audio
    - Receive user input (steering controls)
    - Display notifications
    """

    def __init__(self):
        bus_name = dbus.service.BusName('com.vehicle.Platform',
                                       bus=dbus.SystemBus())
        dbus.service.Object.__init__(self, bus_name, '/com/vehicle/Platform')

    @dbus.service.method('com.vehicle.Platform',
                        in_signature='', out_signature='a{sv}')
    def GetVehicleState(self):
        """Get current vehicle state."""
        return {
            'speed': dbus.Double(65.0),  # km/h
            'batterySoc': dbus.Double(75.0),  # %
            'range': dbus.Double(300.0),  # km
            'gear': dbus.String('D'),
            'isMoving': dbus.Boolean(True)
        }

    @dbus.service.method('com.vehicle.Platform',
                        in_signature='s', out_signature='b')
    def PlayAudio(self, url):
        """Play audio from URL."""
        print(f"[D-Bus] Playing audio: {url}")
        # Integrate with vehicle audio system
        return True

    @dbus.service.signal('com.vehicle.Platform', signature='s')
    def SteeringControlEvent(self, action):
        """Signal for steering control events."""
        print(f"[D-Bus] Steering control: {action}")

    @dbus.service.method('com.vehicle.Platform',
                        in_signature='ss', out_signature='b')
    def ShowNotification(self, title, message):
        """Display notification in vehicle cluster."""
        print(f"[D-Bus] Notification: {title} - {message}")
        # Send to instrument cluster
        return True


def main():
    """Start D-Bus service."""
    DBusGMainLoop(set_as_default=True)

    service = VehicleServiceBus()
    print("[D-Bus] Vehicle service bus started")

    # Run main loop
    loop = GLib.MainLoop()
    loop.run()


if __name__ == "__main__":
    main()
```

## Real-World Examples

### Tesla Container Strategy
- **Native apps**: Tesla apps run directly on Linux (no containers yet)
- **Future plans**: Exploring containers for third-party apps
- **Steam integration**: Games run in isolated environment

### GM Ultifi Platform
- **Full container orchestration**: Kubernetes-based
- **App marketplace**: Third-party containerized apps
- **Resource isolation**: CPU/memory limits per app
- **OTA updates**: Update containers independently

### Rivian App Platform
- **Docker-based**: Uses Docker for app isolation
- **Custom runtime**: Modified Docker daemon for automotive
- **Safety constraints**: Apps can't access CAN bus directly
- **Fleet deployment**: Kubernetes for managing app fleet

### Android Automotive
- **Container-like isolation**: APK sandboxing similar to containers
- **Resource limits**: Memory/CPU limits per app
- **Permission model**: Fine-grained permissions
- **Update mechanism**: Individual app updates

## Best Practices

1. **Use containerd**: Lightweight, industry-standard
2. **Resource limits**: Always set CPU/memory limits
3. **Read-only root**: Immutable container filesystem
4. **Drop capabilities**: Minimal Linux capabilities
5. **Network isolation**: Isolate app network traffic
6. **Health checks**: Liveness and readiness probes
7. **Graceful shutdown**: Handle SIGTERM properly
8. **Persistent data**: Use volumes for app data
9. **Image scanning**: Scan images for vulnerabilities
10. **Update strategy**: Rolling updates with rollback

## Security Considerations

- **User namespaces**: Run containers as non-root
- **Seccomp profiles**: Restrict system calls
- **AppArmor/SELinux**: Mandatory access control
- **Image signing**: Verify container image signatures
- **Network policies**: Restrict inter-container communication
- **Audit logging**: Log container lifecycle events
- **Resource quotas**: Prevent resource exhaustion

## References

- **containerd**: https://containerd.io/
- **OCI Runtime Spec**: https://github.com/opencontainers/runtime-spec
- **K3s**: https://k3s.io/
- **Podman**: https://podman.io/
- **Balena Engine**: https://www.balena.io/engine/
