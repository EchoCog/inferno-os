# Inferno OS Cluster Architecture

## Overview

The Inferno OS cluster deployment modernizes the existing grid computing framework
(`appl/grid/`) into a Kubernetes-native distributed system while preserving Inferno's
core Styx protocol-based service model.

## System Components

### Core Services

```
┌─────────────────────────────────────────────────────────────────┐
│                     Kubernetes Cluster                          │
│                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐        │
│  │   Ingress   │    │ cert-manager│    │  Prometheus  │        │
│  │  Controller │    │             │    │   Operator   │        │
│  └──────┬──────┘    └─────────────┘    └──────┬──────┘        │
│         │                                      │               │
│  ┌──────▼──────────────────────────────────────▼──────┐        │
│  │                 inferno namespace                   │        │
│  │                                                     │        │
│  │  ┌───────────┐  ┌───────────┐  ┌───────────┐      │        │
│  │  │ Registry  │  │  CPU Pool │  │  Emulator  │      │        │
│  │  │ Deployment│  │ Deployment│  │ Deployment │      │        │
│  │  │ (2-3 pods)│  │ (3-20pods)│  │ (2-10pods) │      │        │
│  │  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘      │        │
│  │        │               │               │            │        │
│  │  ┌─────▼─────┐  ┌─────▼─────┐  ┌─────▼─────┐      │        │
│  │  │  ClusterIP│  │  ClusterIP│  │LoadBalancer│      │        │
│  │  │  :6675    │  │  :6676    │  │  :6677     │      │        │
│  │  └───────────┘  └───────────┘  └───────────┘      │        │
│  │                                                     │        │
│  │  ┌─────────────────────────────────────────────┐   │        │
│  │  │          NetworkPolicies                     │   │        │
│  │  │  - Default deny                             │   │        │
│  │  │  - Registry: accept from cluster + ingress  │   │        │
│  │  │  - CPU Pool: connect to registry            │   │        │
│  │  │  - Emulator: connect to registry + cpupool  │   │        │
│  │  └─────────────────────────────────────────────┘   │        │
│  └─────────────────────────────────────────────────────┘        │
└─────────────────────────────────────────────────────────────────┘
```

### Mapping from Legacy Grid to Kubernetes

| Legacy Component | Source File | Kubernetes Resource |
|-----------------|-------------|-------------------|
| Registry | `appl/cmd/ndb/registry.b` | `inferno-registry` Deployment + ClusterIP Service |
| CPU Pool | `appl/grid/cpupool.b` | `inferno-cpupool` Deployment + ClusterIP Service |
| Register | `appl/grid/register.b` | Handled by cpupool init via `-r` flag |
| Listen | `appl/grid/reglisten.b` | Kubernetes Service discovery replaces manual listen |
| Inferno Emulator | `emu/` | `inferno` Deployment + LoadBalancer Service |

### Protocol Flow

```
Client Request
     │
     ▼
┌─────────┐     ┌──────────┐     ┌──────────┐
│ Ingress │────►│ Emulator │────►│ Registry │
│ (HTTPS) │     │  (Styx)  │     │  (Styx)  │
└─────────┘     └────┬─────┘     └──────────┘
                     │                  ▲
                     │                  │
                     ▼                  │
                ┌──────────┐            │
                │ CPU Pool │────────────┘
                │  (Styx)  │  (registers)
                └──────────┘
```

## Deployment Strategies

### Kustomize (Recommended for simple setups)

- Base manifests in `k8s/base/`
- Environment-specific overlays in `k8s/overlay/{staging,production}/`
- Patches for resource limits, replica counts, and HPA settings

### Helm (Recommended for complex/multi-tenant setups)

- Parameterized chart in `helm/inferno-cluster/`
- All services configurable via `values.yaml`
- Supports enabling/disabling individual components
- Template helpers for consistent labeling

## Scaling Architecture

### Horizontal Pod Autoscaling

- **Emulator**: Scales based on CPU (70%) and memory (80%) utilization
- **CPU Pool**: Scales more aggressively based on CPU (60%) with faster scale-up

### Scale-Down Protection

- Stabilization windows prevent flapping (300s for scale-down)
- Gradual scale-down: 1-2 pods per minute
- Aggressive scale-up: 2-4 pods per minute

## Observability

### Metrics (Prometheus)
- All pods expose metrics on port 9100
- ServiceMonitor resources for Prometheus Operator
- Pod annotations for direct scraping

### Logging (Fluent Bit)
- Structured log format: `timestamp level component: message`
- Logs collected from `/var/log/inferno/`
- Log rotation: 7 days, 100MB max per file

### Health Checks
- Registry/CPU Pool: TCP socket probes on Styx ports
- Emulator: exec probe running `emu cat /dev/sysctl`

## Security

### Network Isolation
- Default deny-all policy
- Explicit allow rules per service
- DNS egress permitted for all pods
- Metrics scraping permitted from monitoring namespace

### Container Security
- Non-root user (`inferno`) in production Dockerfile
- Read-only filesystem where possible
- Resource limits enforced on all containers

## CI/CD Integration

```
Push to master ──► Build Image ──► Test ──► Validate K8s ──► Deploy Staging
                                                                    │
Tag v* ─────────────────────────────────────────────────────► Deploy Production
```
