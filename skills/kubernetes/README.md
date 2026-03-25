# Kubernetes Skills for Automotive

Production-ready Kubernetes skills for automotive cloud and edge deployments.

## Overview

This directory contains comprehensive Kubernetes skills covering:
- Cloud cluster management
- Edge computing (K3s)
- Fleet management (1,000-100,000+ vehicles)
- Helm chart creation
- Service mesh (Istio)
- Monitoring (Prometheus, Grafana)
- Security (PSS, OPA)
- Automotive compliance (ISO 26262, ASPICE)

## Skills Directory Structure

```
skills/kubernetes/
├── cluster/           # Cluster management
│   ├── k8s-cluster-setup.yaml
│   ├── k8s-autoscaling.yaml
│   └── [additional cluster skills]
├── edge/              # Edge computing
│   ├── k3s-edge-deployment.yaml
│   ├── edge-fleet-management.yaml
│   └── vehicle-to-cloud-sync.yaml
├── helm/              # Helm & packaging
│   └── helm-charts-creation.yaml
├── service-mesh/      # Service mesh
│   └── istio-setup.yaml
├── monitoring/        # Monitoring & observability
│   └── prometheus-setup.yaml
└── security/          # Security & compliance
    └── pod-security-policies.yaml
```

## Quick Start

### 1. Deploy Kubernetes Cluster
```bash
k8s-cluster-setup \
  --cluster-name=automotive-prod \
  --control-plane-nodes=3 \
  --worker-nodes=10 \
  --network-plugin=calico
```

### 2. Deploy K3s on Vehicle
```bash
k3s-edge-deployment \
  --node-name=vehicle-vin-abc123 \
  --deployment-mode=server-agent
```

### 3. Setup Fleet Management
```bash
edge-fleet-management \
  --fleet-name=production-fleet \
  --git-repository=https://github.com/automotive/fleet-configs \
  --enable-progressive-rollout=true
```

### 4. Create Helm Chart
```bash
helm-charts-creation \
  --chart-name=adas-service \
  --chart-version=1.0.0 \
  --app-version=2.5.0
```

## Skills Reference

### Cluster Management

#### k8s-cluster-setup
Deploy production Kubernetes clusters with HA configuration.

**Features:**
- Multi-master control plane
- CNI installation (Calico, Cilium, Flannel)
- Storage provisioning
- Core components (metrics-server, ingress, cert-manager)

**Usage:**
```bash
k8s-cluster-setup \
  --cluster-name=automotive-prod \
  --control-plane-nodes=3 \
  --worker-nodes=10 \
  --network-plugin=calico \
  --storage-class=longhorn \
  --enable-ha=true
```

#### k8s-autoscaling
Configure autoscaling (HPA, VPA, Cluster Autoscaler).

**Features:**
- Horizontal Pod Autoscaler
- Vertical Pod Autoscaler
- Cluster Autoscaler (AWS, Azure, GCP)
- metrics-server deployment

**Usage:**
```bash
k8s-autoscaling \
  --autoscaling-type=all \
  --hpa-enabled=true \
  --cluster-autoscaler-enabled=true \
  --cloud-provider=aws
```

### Edge Computing

#### k3s-edge-deployment
Deploy lightweight K3s on edge devices and vehicles.

**Features:**
- Minimal resource footprint (< 100MB)
- Offline-capable
- Airgap installation support
- Fleet agent integration

**Usage:**
```bash
k3s-edge-deployment \
  --node-name=vehicle-vin-abc123 \
  --deployment-mode=server-agent \
  --disable-components=traefik,servicelb \
  --enable-airgap=true
```

#### edge-fleet-management
Manage fleet of 1,000-100,000+ edge clusters.

**Features:**
- GitOps workflows
- Progressive rollout (pilot → early adopters → general)
- Auto-remediation
- Fleet-wide monitoring

**Usage:**
```bash
edge-fleet-management \
  --fleet-name=production-vehicle-fleet \
  --git-repository=https://github.com/automotive/fleet-configs \
  --enable-progressive-rollout=true \
  --rollout-strategy=staged
```

#### vehicle-to-cloud-sync
Bidirectional data synchronization between vehicles and cloud.

**Features:**
- Telemetry streaming
- Offline buffering
- Data prioritization
- OTA updates

**Usage:**
```bash
vehicle-to-cloud-sync \
  --sync-mode=bidirectional \
  --vehicle-id=1HGBH41JXMN109186 \
  --cloud-endpoint=https://api.automotive.example.com \
  --compression-enabled=true
```

### Helm & Packaging

#### helm-charts-creation
Create production-ready Helm charts.

**Features:**
- Multi-environment support
- Complete templates (deployment, service, ingress, HPA, PDB)
- Automotive compliance labels
- Security contexts

**Usage:**
```bash
helm-charts-creation \
  --chart-name=adas-service \
  --chart-version=1.0.0 \
  --include-hpa=true \
  --include-service-monitor=true
```

### Service Mesh

#### istio-setup
Deploy and configure Istio service mesh.

**Features:**
- Mutual TLS
- Traffic management
- Observability (Prometheus, Grafana, Jaeger, Kiali)
- Gateway configuration

**Usage:**
```bash
istio-setup \
  --profile=default \
  --enable-mtls=true \
  --mtls-mode=STRICT \
  --enable-tracing=true
```

### Monitoring & Observability

#### prometheus-setup
Deploy Prometheus monitoring stack.

**Features:**
- Prometheus Operator
- Automotive-specific alerts
- ServiceMonitor configuration
- Fleet metrics aggregation

**Usage:**
```bash
prometheus-setup \
  --deployment-method=operator \
  --retention-period=30d \
  --storage-size=100Gi \
  --enable-alertmanager=true
```

### Security

#### pod-security-policies
Implement Pod Security Standards and admission control.

**Features:**
- Pod Security Standards (PSS)
- OPA Gatekeeper
- ISO 26262 compliance
- Network policies

**Usage:**
```bash
pod-security-policies \
  --enforcement-mode=enforce \
  --default-level=restricted \
  --enable-policy-enforcement=true
```

## Automotive Patterns

### Vehicle Deployment
- **Scale**: 10,000-100,000+ vehicles
- **Resources**: 512MB RAM min, 1-2 CPU cores
- **Connectivity**: Intermittent (offline-capable)
- **Workloads**: ADAS, battery monitoring, connectivity

### Edge Gateway Deployment
- **Scale**: 100-1,000 gateways
- **Resources**: 4-8 CPU cores, 8-16GB RAM
- **Connectivity**: More stable
- **Role**: Regional data aggregation

### Manufacturing Edge
- **Scale**: 10-100 facilities
- **Resources**: High-performance
- **Connectivity**: Stable, high-bandwidth
- **Role**: Production integration

## Compliance

### ISO 26262
- Safety level labels (ASIL-A to ASIL-D)
- Resource guarantees
- Security contexts
- Network isolation
- Audit logging
- Immutable configuration

### ASPICE (AL2)
- Documented procedures
- Version control
- Traceability
- Testing procedures

### GDPR
- Data encryption
- Audit logging
- Access control
- Data retention policies

## Related Resources

- **Tool Adapters**: `/tools/adapters/kubernetes/`
- **Kubernetes Manifests**: `/kubernetes/`
- **Helm Charts**: `/helm/charts/`
- **Agents**: `/agents/kubernetes/`
- **Commands**: `/commands/kubernetes/`
- **Documentation**: `/knowledge-base/technologies/kubernetes/`

## Support

For issues, questions, or contributions:
- GitHub Issues: https://github.com/automotive/kubernetes-platform/issues
- Documentation: /knowledge-base/technologies/kubernetes/
- Skills Source: /skills/kubernetes/

## License

Proprietary - Automotive Platform Team
