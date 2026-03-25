# Containerization and Orchestration for Automotive HPC

**Category:** automotive-hpc
**Version:** 1.0.0
**Maturity:** production
**Complexity:** advanced

## Overview

Comprehensive guide to container technologies and orchestration for automotive HPC platforms. Covers Docker, Podman, Kubernetes for vehicles, application lifecycle management, and OTA container updates with safety considerations.

## Core Competencies

### 1. Automotive Container Architecture

**Why Containers in Automotive:**
- **Rapid Updates**: Deploy new algorithms without full ECU reflash
- **Isolation**: Separate safety-critical from non-critical workloads
- **Portability**: Same container runs on test bench, HIL, and production vehicle
- **Resource Control**: cgroups for CPU/memory limits per ASIL level
- **Versioning**: Atomic rollback for failed updates

**Container vs Traditional ECU:**
```
Traditional ECU:               Containerized Platform:
┌──────────────────┐          ┌─────────────────────────────┐
│   App Binary     │          │ Container 1: ADAS (ASIL-D)  │
│   (Monolithic)   │          │ Container 2: IVI (QM)       │
├──────────────────┤          │ Container 3: Telematics     │
│   AUTOSAR RTE    │          ├─────────────────────────────┤
├──────────────────┤          │ Container Runtime (containerd)│
│   OS (QNX/Linux) │          ├─────────────────────────────┤
│   Bare Metal     │          │ OS (Linux/QNX)              │
└──────────────────┘          └─────────────────────────────┘
Update: Full flash (30min)    Update: Container only (2min)
```

### 2. Container Runtime for Automotive

#### Docker for Development

**Dockerfile for ADAS Application:**
```dockerfile
# Multi-stage build for ADAS perception pipeline
FROM nvcr.io/nvidia/l4t-base:r35.3.1 AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    cuda-toolkit-11-4 \
    libeigen3-dev \
    libopencv-dev \
    && rm -rf /var/lib/apt/lists/*

# Build ADAS application
WORKDIR /app
COPY src/ /app/src/
COPY CMakeLists.txt /app/

RUN mkdir build && cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release .. && \
    make -j$(nproc)

# Runtime stage (minimal image)
FROM nvcr.io/nvidia/l4t-base:r35.3.1

# Install runtime dependencies only
RUN apt-get update && apt-get install -y \
    libopencv-core4.5d \
    libopencv-imgproc4.5d \
    cuda-cudart-11-4 \
    && rm -rf /var/lib/apt/lists/*

# Copy only built artifacts
COPY --from=builder /app/build/adas_perception /usr/local/bin/
COPY --from=builder /app/models/ /opt/models/

# Non-root user for security
RUN useradd -m -u 1000 adas && \
    chown -R adas:adas /opt/models

USER adas

# CUDA device access
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES compute,utility

# Health check
HEALTHCHECK --interval=5s --timeout=3s --retries=3 \
    CMD /usr/local/bin/adas_perception --health-check

ENTRYPOINT ["/usr/local/bin/adas_perception"]
CMD ["--config", "/etc/adas/config.yaml"]
```

**Docker Compose for Development Environment:**
```yaml
# docker-compose.yaml - Local ADAS development
version: '3.8'

services:
  # Sensor simulation
  sensor_sim:
    image: autoware/sensor-simulator:latest
    volumes:
      - ./data/rosbag:/data:ro
    networks:
      - vehicle_net
    command: ["--replay", "/data/test_drive.bag"]

  # ADAS perception
  adas_perception:
    build:
      context: .
      dockerfile: Dockerfile
    runtime: nvidia
    environment:
      - CUDA_VISIBLE_DEVICES=0
      - ROS_MASTER_URI=http://sensor_sim:11311
    volumes:
      - ./models:/opt/models:ro
      - ./logs:/var/log/adas:rw
    networks:
      - vehicle_net
    depends_on:
      - sensor_sim
    deploy:
      resources:
        limits:
          cpus: '4'
          memory: 4G
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]

  # Visualization
  rviz:
    image: osrf/ros:noetic-desktop-full
    environment:
      - DISPLAY=$DISPLAY
      - ROS_MASTER_URI=http://sensor_sim:11311
    volumes:
      - /tmp/.X11-unix:/tmp/.X11-unix:rw
    networks:
      - vehicle_net
    depends_on:
      - adas_perception

networks:
  vehicle_net:
    driver: bridge
```

#### Podman for Production (Rootless & Daemonless)

**Why Podman for Automotive:**
- **Rootless**: Better security, no privileged daemon
- **Systemd Integration**: Native systemd unit generation
- **OCI Compliant**: Compatible with Kubernetes
- **No Daemon**: Reduces attack surface

**Podman Container for Safety-Critical ADAS:**
```bash
#!/bin/bash
# Build and run ADAS container with Podman

# Build image
podman build -t adas-perception:1.0.0 -f Dockerfile.adas .

# Run with systemd integration and resource limits
podman run -d \
  --name adas-safety \
  --security-opt label=type:adas_t \
  --cap-drop=ALL \
  --cap-add=SYS_NICE \
  --cpuset-cpus=4-7 \
  --memory=4G \
  --memory-swap=0 \
  --oom-score-adj=-1000 \
  --device=/dev/nvidia0 \
  --device=/dev/can0 \
  --volume=/etc/adas/config.yaml:/etc/adas/config.yaml:ro,Z \
  --volume=/var/log/adas:/var/log/adas:rw,Z \
  --network=host \
  --restart=on-failure:3 \
  adas-perception:1.0.0

# Generate systemd service
podman generate systemd --new --name adas-safety \
  --restart-policy=always \
  --start-timeout=30 \
  --stop-timeout=10 \
  > /etc/systemd/system/adas-safety.service

systemctl enable adas-safety.service
systemctl start adas-safety.service
```

### 3. Kubernetes for Automotive

**Lightweight Kubernetes Distributions:**
- **K3s**: Minimal Kubernetes (40MB binary) for edge/embedded
- **MicroK8s**: Snap-based, fast cluster setup
- **KubeEdge**: Extends Kubernetes to edge devices

**K3s Installation on Vehicle ECU:**
```bash
#!/bin/bash
# Install K3s on automotive HPC (NVIDIA Orin)

# Install K3s server (control plane + worker)
curl -sfL https://get.k3s.io | sh -s - \
  --disable traefik \
  --disable servicelb \
  --kubelet-arg="cpu-manager-policy=static" \
  --kubelet-arg="topology-manager-policy=single-numa-node" \
  --kubelet-arg="reserved-cpus=0-1" \
  --kubelet-arg="system-reserved=cpu=2,memory=2Gi" \
  --kube-apiserver-arg="feature-gates=CPUManager=true,TopologyManager=true"

# Install NVIDIA GPU device plugin
kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/main/nvidia-device-plugin.yml

# Verify installation
kubectl get nodes
kubectl describe node $(hostname)
```

**ADAS Deployment Manifest:**
```yaml
# adas-deployment.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: adas-safety
  labels:
    asil: "d"
    safety-critical: "true"

---
# ConfigMap for ADAS configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: adas-config
  namespace: adas-safety
data:
  config.yaml: |
    perception:
      camera_count: 8
      lidar_enabled: true
      radar_count: 5
      fusion_rate_hz: 10
    planning:
      algorithm: "model_predictive_control"
      horizon_seconds: 5
      safety_margin_meters: 2.0

---
# ADAS Perception Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: adas-perception
  namespace: adas-safety
  labels:
    app: adas-perception
    asil: "d"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: adas-perception
  template:
    metadata:
      labels:
        app: adas-perception
        asil: "d"
    spec:
      # Node affinity for HPC cores
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: node-role.kubernetes.io/hpc
                operator: In
                values:
                - "true"

      # Host networking for low-latency CAN/Ethernet
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet

      # Security context
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault

      containers:
      - name: perception
        image: adas-perception:1.0.0
        imagePullPolicy: IfNotPresent

        # Resource requests/limits (guaranteed QoS)
        resources:
          requests:
            cpu: "4"
            memory: "4Gi"
            nvidia.com/gpu: "1"
          limits:
            cpu: "4"
            memory: "4Gi"
            nvidia.com/gpu: "1"

        # Environment variables
        env:
        - name: CUDA_VISIBLE_DEVICES
          value: "0"
        - name: OMP_NUM_THREADS
          value: "4"

        # Volume mounts
        volumeMounts:
        - name: config
          mountPath: /etc/adas
          readOnly: true
        - name: models
          mountPath: /opt/models
          readOnly: true
        - name: logs
          mountPath: /var/log/adas
        - name: dev-can
          mountPath: /dev/can0

        # Liveness probe
        livenessProbe:
          exec:
            command:
            - /usr/local/bin/health-check
            - --type=liveness
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3

        # Readiness probe
        readinessProbe:
          exec:
            command:
            - /usr/local/bin/health-check
            - --type=readiness
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3

        # Security capabilities
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
            add:
            - SYS_NICE  # For RT scheduling
          readOnlyRootFilesystem: true

      # Volumes
      volumes:
      - name: config
        configMap:
          name: adas-config
      - name: models
        hostPath:
          path: /opt/adas/models
          type: Directory
      - name: logs
        emptyDir:
          sizeLimit: 1Gi
      - name: dev-can
        hostPath:
          path: /dev/can0
          type: CharDevice

      # Tolerations for dedicated HPC nodes
      tolerations:
      - key: "hpc"
        operator: "Equal"
        value: "true"
        effect: "NoSchedule"

      # Priority class for safety-critical workload
      priorityClassName: safety-critical

---
# PriorityClass for ASIL-D workloads
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: safety-critical
value: 1000000
globalDefault: false
description: "Reserved for ASIL-D safety-critical applications"
```

### 4. OTA Container Updates

**Safe OTA Update Strategy:**
```python
#!/usr/bin/env python3
"""
Automotive OTA Container Update Manager
Implements A/B partition scheme for safe rollback
"""

import subprocess
import json
import hashlib
from enum import Enum
from dataclasses import dataclass
from typing import Optional

class UpdateStatus(Enum):
    IDLE = "idle"
    DOWNLOADING = "downloading"
    VALIDATING = "validating"
    INSTALLING = "installing"
    TESTING = "testing"
    COMMITTED = "committed"
    ROLLING_BACK = "rolling_back"
    FAILED = "failed"

@dataclass
class ContainerUpdate:
    name: str
    current_version: str
    target_version: str
    image_url: str
    checksum_sha256: str
    asil_level: str

class OTAUpdateManager:
    def __init__(self):
        self.update_partition = "B"  # A=active, B=update
        self.status = UpdateStatus.IDLE

    def update_container(self, update: ContainerUpdate) -> bool:
        """
        Perform safe OTA container update with rollback capability
        """
        try:
            # 1. Pre-update validation
            if not self.validate_preconditions(update):
                return False

            # 2. Download new container image
            self.status = UpdateStatus.DOWNLOADING
            if not self.download_image(update):
                return False

            # 3. Validate checksum
            self.status = UpdateStatus.VALIDATING
            if not self.verify_checksum(update):
                return False

            # 4. Install to inactive partition
            self.status = UpdateStatus.INSTALLING
            if not self.install_to_partition(update, self.update_partition):
                return False

            # 5. Test new version (smoke test)
            self.status = UpdateStatus.TESTING
            if not self.smoke_test(update):
                self.rollback(update)
                return False

            # 6. Commit update (switch active partition)
            self.status = UpdateStatus.COMMITTED
            self.commit_update(update)

            # 7. Monitor for stability (2 minutes)
            if not self.monitor_stability(update, duration_sec=120):
                self.rollback(update)
                return False

            self.status = UpdateStatus.IDLE
            return True

        except Exception as e:
            self.status = UpdateStatus.FAILED
            print(f"Update failed: {e}")
            self.rollback(update)
            return False

    def validate_preconditions(self, update: ContainerUpdate) -> bool:
        """Check vehicle state before update"""
        # Don't update while driving
        vehicle_speed = self.get_vehicle_speed()
        if vehicle_speed > 0:
            print("Update blocked: Vehicle in motion")
            return False

        # Check battery SOC (>20% for safety)
        if self.get_battery_soc() < 20.0:
            print("Update blocked: Low battery")
            return False

        # Verify parking brake engaged
        if not self.is_parking_brake_engaged():
            print("Update blocked: Parking brake not engaged")
            return False

        return True

    def download_image(self, update: ContainerUpdate) -> bool:
        """Download container image from OTA server"""
        print(f"Downloading {update.name}:{update.target_version}")

        result = subprocess.run([
            'podman', 'pull',
            f'{update.image_url}:{update.target_version}'
        ], capture_output=True, text=True)

        return result.returncode == 0

    def verify_checksum(self, update: ContainerUpdate) -> bool:
        """Verify image integrity"""
        result = subprocess.run([
            'podman', 'image', 'inspect',
            f'{update.image_url}:{update.target_version}',
            '--format', '{{.Id}}'
        ], capture_output=True, text=True)

        image_id = result.stdout.strip()
        # Extract SHA256 from image ID (sha256:abc123...)
        actual_checksum = image_id.split(':')[1][:64]

        if actual_checksum != update.checksum_sha256:
            print(f"Checksum mismatch: {actual_checksum} != {update.checksum_sha256}")
            return False

        return True

    def install_to_partition(self, update: ContainerUpdate, partition: str) -> bool:
        """Install container to inactive partition"""
        # Tag image for specific partition
        subprocess.run([
            'podman', 'tag',
            f'{update.image_url}:{update.target_version}',
            f'{update.name}:partition-{partition}'
        ])

        # Create new container (don't start yet)
        result = subprocess.run([
            'podman', 'create',
            '--name', f'{update.name}-{partition}',
            '--cpuset-cpus', '4-7',
            '--memory', '4G',
            f'{update.name}:partition-{partition}'
        ], capture_output=True, text=True)

        return result.returncode == 0

    def smoke_test(self, update: ContainerUpdate) -> bool:
        """Start container and verify basic functionality"""
        container_name = f'{update.name}-{self.update_partition}'

        # Start container
        subprocess.run(['podman', 'start', container_name])

        # Wait for container to be ready
        import time
        time.sleep(5)

        # Check health endpoint
        result = subprocess.run([
            'podman', 'exec', container_name,
            '/usr/local/bin/health-check'
        ], capture_output=True)

        if result.returncode != 0:
            print("Smoke test failed: Health check returned error")
            subprocess.run(['podman', 'stop', container_name])
            return False

        # For ASIL-D: Run extended validation
        if update.asil_level == "D":
            if not self.asil_d_validation(container_name):
                subprocess.run(['podman', 'stop', container_name])
                return False

        return True

    def commit_update(self, update: ContainerUpdate):
        """Switch active partition"""
        old_container = f'{update.name}-A'
        new_container = f'{update.name}-{self.update_partition}'

        # Stop old version
        subprocess.run(['podman', 'stop', old_container])

        # Rename containers (swap partitions)
        subprocess.run(['podman', 'rename', old_container, f'{update.name}-OLD'])
        subprocess.run(['podman', 'rename', new_container, old_container])

        # Update systemd service to point to new container
        subprocess.run(['systemctl', 'restart', f'{update.name}.service'])

    def monitor_stability(self, update: ContainerUpdate, duration_sec: int) -> bool:
        """Monitor container for crashes/errors after update"""
        import time
        container_name = f'{update.name}-A'

        start_time = time.time()
        while time.time() - start_time < duration_sec:
            # Check if container is still running
            result = subprocess.run([
                'podman', 'inspect',
                '--format', '{{.State.Running}}',
                container_name
            ], capture_output=True, text=True)

            if result.stdout.strip() != 'true':
                print("Container crashed during stability monitoring")
                return False

            # Check error logs
            result = subprocess.run([
                'podman', 'logs', '--tail', '10', container_name
            ], capture_output=True, text=True)

            if 'FATAL' in result.stdout or 'CRITICAL' in result.stdout:
                print("Critical errors detected in logs")
                return False

            time.sleep(10)

        return True

    def rollback(self, update: ContainerUpdate):
        """Rollback to previous version"""
        self.status = UpdateStatus.ROLLING_BACK
        print(f"Rolling back {update.name} to {update.current_version}")

        new_container = f'{update.name}-A'
        old_container = f'{update.name}-OLD'

        # Stop failed new version
        subprocess.run(['podman', 'stop', new_container])

        # Restore old version
        subprocess.run(['podman', 'rename', new_container, f'{update.name}-FAILED'])
        subprocess.run(['podman', 'rename', old_container, new_container])
        subprocess.run(['podman', 'start', new_container])

        # Restore systemd service
        subprocess.run(['systemctl', 'restart', f'{update.name}.service'])

    def asil_d_validation(self, container_name: str) -> bool:
        """Extended validation for ASIL-D containers"""
        # Run safety test suite
        result = subprocess.run([
            'podman', 'exec', container_name,
            '/usr/local/bin/safety-test-suite'
        ], capture_output=True)

        return result.returncode == 0

    # Mock functions for vehicle state
    def get_vehicle_speed(self) -> float:
        return 0.0  # km/h

    def get_battery_soc(self) -> float:
        return 80.0  # %

    def is_parking_brake_engaged(self) -> bool:
        return True

# Example usage
if __name__ == '__main__':
    manager = OTAUpdateManager()

    update = ContainerUpdate(
        name='adas-perception',
        current_version='1.0.0',
        target_version='1.1.0',
        image_url='registry.oem.com/adas-perception',
        checksum_sha256='abc123def456...',
        asil_level='D'
    )

    success = manager.update_container(update)
    print(f"Update {'successful' if success else 'failed'}")
```

### 5. Container Resource Management

**CPU and Memory Isolation:**
```yaml
# cgroup v2 configuration for container resource limits
# /sys/fs/cgroup/adas-perception.slice/cpu.max
# Format: $MAX $PERIOD (microseconds)
400000 100000  # 4 CPUs worth (4 * 100ms = 400ms per 100ms period)

# /sys/fs/cgroup/adas-perception.slice/memory.max
4294967296  # 4 GB

# /sys/fs/cgroup/adas-perception.slice/memory.swap.max
0  # No swap for safety-critical

# /sys/fs/cgroup/adas-perception.slice/cpuset.cpus
4-7  # Pin to CPU cores 4-7

# /sys/fs/cgroup/adas-perception.slice/cpuset.mems
0  # NUMA node 0
```

## Use Cases

1. **Modular ADAS Updates**: Update perception algorithm without touching planning/control
2. **A/B Testing**: Run two algorithm versions side-by-side for validation
3. **Multi-Tenant ECU**: IVI, telematics, and ADAS on single HPC with isolation
4. **CI/CD Integration**: Automated testing and deployment pipeline

## Automotive Standards

- **ISO 26262**: Container isolation for FFI compliance
- **ISO 21434**: Secure container registry and image signing
- **ASPICE CL3**: Container lifecycle management process

## Tools Required

- **Docker/Podman**: Container runtime
- **K3s/MicroK8s**: Lightweight Kubernetes
- **Helm**: Kubernetes package manager
- **Harbor**: Container registry with security scanning
- **Notary**: Container image signing (TUF framework)

## Performance Metrics

- **Container Startup**: <2s for ADAS application
- **Overhead**: <2% CPU, <50MB memory for runtime
- **Update Time**: <5min for full container replacement
- **Rollback Time**: <30s to previous version

## References

- CNCF Automotive Edge Computing Whitepaper
- AGL (Automotive Grade Linux) Container Guidelines
- Kubernetes for Edge Computing (K3s documentation)
- "Containers in Safety-Critical Systems" (SAE Paper)

---

**Version:** 1.0.0
**Last Updated:** 2026-03-19
**Author:** Automotive Claude Code Agents
