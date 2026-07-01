# Inferno OS Cluster Deployment Guide

This guide covers deploying Inferno OS as a distributed cluster on Kubernetes.

## Prerequisites

- Kubernetes cluster (v1.25+)
- `kubectl` configured for your cluster
- `kustomize` (v5+) or `helm` (v3+)
- Container registry access (defaults to `ghcr.io/echocog/inferno-os`)

## Quick Start

### Using Kustomize

Deploy to staging:
```bash
kustomize build k8s/overlay/staging | kubectl apply -f -
```

Deploy to production:
```bash
kustomize build k8s/overlay/production | kubectl apply -f -
```

### Using Helm

```bash
helm install inferno helm/inferno-cluster \
  --namespace inferno \
  --create-namespace
```

With custom values:
```bash
helm install inferno helm/inferno-cluster \
  --namespace inferno \
  --create-namespace \
  -f my-values.yaml
```

## Architecture

The cluster consists of three core services:

| Service | Description | Default Port |
|---------|-------------|-------------|
| **Registry** (`ndb/registry`) | Service discovery backbone using Styx protocol | 6675 |
| **CPU Pool** (`grid/cpupool`) | Distributed compute workers | 6676 |
| **Emulator** (`emu`) | Main Inferno OS instances | 6677 |

```
                    ┌──────────────┐
                    │   Ingress    │
                    └──────┬───────┘
                           │
          ┌────────────────┼────────────────┐
          │                │                │
    ┌─────▼─────┐   ┌─────▼─────┐   ┌─────▼─────┐
    │  Registry  │   │  CPU Pool  │   │  Emulator  │
    │  (Styx)    │◄──│  Workers   │   │  Instances │
    │  port 6675 │   │  port 6676 │   │  port 6677 │
    └────────────┘   └────────────┘   └────────────┘
```

## Building the Docker Image

### Development build
```bash
docker build -t inferno-os:dev .
```

### Production build (multi-stage)
```bash
docker build -f Dockerfile.production -t inferno-os:latest .
```

## Configuration

### Environment-Specific Settings

Configuration is managed through:
- **Kustomize overlays** in `k8s/overlay/{staging,production}/`
- **Helm values** in `helm/inferno-cluster/values.yaml`
- **mkconfig files** in `config/{staging,production}.mkconfig`

### Key Configuration Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `REGISTRY_ADDR` | Registry listen address | `tcp!*!6675` |
| `CPUPOOL_MAX_WORKERS` | Max CPU pool workers | `8` |
| `EMU_FLAGS` | Emulator flags | `-c1` |

## Deployment Environments

### Staging

- Single replica per service
- Reduced resource limits
- NodePort service type
- Let's Encrypt staging certificates
- Namespace: `inferno-staging`

### Production

- Multiple replicas with HPA
- Higher resource limits
- LoadBalancer service type
- Let's Encrypt production certificates
- Namespace: `inferno`
- Rate limiting on ingress

## CI/CD Pipeline

The GitHub Actions workflow (`.github/workflows/build-deploy.yml`) provides:

1. **Build**: Multi-platform Docker image build
2. **Test**: Smoke tests using `emu cat /dev/sysctl`
3. **Validate**: Kubernetes manifest and Helm chart validation
4. **Deploy Staging**: Automatic on push to `master`/`main`
5. **Deploy Production**: On version tags (`v*`)

### Required Secrets

| Secret | Description |
|--------|-------------|
| `GITHUB_TOKEN` | Auto-provided for GHCR push |
| `KUBE_CONFIG_STAGING` | kubectl config for staging cluster |
| `KUBE_CONFIG_PRODUCTION` | kubectl config for production cluster |

## TLS/Certificate Management

The deployment uses cert-manager annotations for automatic TLS certificate provisioning:

```yaml
cert-manager.io/cluster-issuer: letsencrypt-prod
```

Ensure cert-manager is installed in your cluster:
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml
```

## Scaling

### Manual Scaling
```bash
kubectl scale deployment inferno-cpupool --replicas=10 -n inferno
```

### Autoscaling (HPA)

HPAs are configured for both the emulator and CPU pool:
- Emulator: 2-10 replicas (70% CPU, 80% memory target)
- CPU Pool: 2-20 replicas (60% CPU, 75% memory target)

Production overlays increase these limits significantly.

## Network Policies

Network policies enforce:
- Default deny all ingress/egress (except DNS)
- Registry accepts connections from all cluster services
- CPU Pool connects to Registry for service registration
- Emulator connects to both Registry and CPU Pool
- Ingress controller can reach all services
- Metrics port accessible for Prometheus scraping
