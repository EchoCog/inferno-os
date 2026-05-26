# Kubernetes Deployment Reference

## Directory Structure

```
k8s/
├── base/                          # Base manifests (Kustomize)
│   ├── kustomization.yaml         # Resource aggregation
│   ├── namespace.yaml             # inferno namespace
│   ├── configmap.yaml             # Inferno configuration
│   ├── registry-deployment.yaml   # Registry (ndb/registry.b)
│   ├── registry-service.yaml      # Registry ClusterIP service
│   ├── cpupool-deployment.yaml    # CPU Pool (grid/cpupool.b)
│   ├── cpupool-service.yaml       # CPU Pool ClusterIP service
│   ├── inferno-deployment.yaml    # Inferno emulator instances
│   ├── inferno-service.yaml       # Emulator LoadBalancer service
│   ├── hpa.yaml                   # HorizontalPodAutoscalers
│   ├── ingress.yaml               # Ingress resource
│   ├── network-policy.yaml        # NetworkPolicy rules
│   ├── servicemonitor.yaml        # Prometheus ServiceMonitors
│   └── logging-configmap.yaml     # Fluent Bit logging config
├── overlay/
│   ├── production/
│   │   └── kustomization.yaml     # Production patches
│   └── staging/
│       └── kustomization.yaml     # Staging patches
```

## Service Ports

| Service | Port | Protocol | Purpose |
|---------|------|----------|---------|
| Registry | 6675 | TCP/Styx | Service discovery |
| CPU Pool | 6676 | TCP/Styx | Compute workers |
| Emulator | 6677 | TCP/Styx | Main instances |
| Metrics | 9100 | TCP/HTTP | Prometheus metrics |

## Kustomize Usage

### Preview rendered manifests
```bash
# Base
kustomize build k8s/base

# Staging
kustomize build k8s/overlay/staging

# Production
kustomize build k8s/overlay/production
```

### Apply
```bash
kustomize build k8s/overlay/staging | kubectl apply -f -
```

### Diff before applying
```bash
kustomize build k8s/overlay/production | kubectl diff -f -
```

## Resource Requirements

### Staging (per pod)

| Service | CPU Request | CPU Limit | Memory Request | Memory Limit |
|---------|------------|-----------|----------------|-------------|
| Registry | 50m | 250m | 64Mi | 128Mi |
| CPU Pool | 100m | 500m | 128Mi | 256Mi |
| Emulator | 100m | 500m | 128Mi | 256Mi |

### Production (per pod)

| Service | CPU Request | CPU Limit | Memory Request | Memory Limit |
|---------|------------|-----------|----------------|-------------|
| Registry | 250m | 1000m | 256Mi | 512Mi |
| CPU Pool | 500m | 2000m | 512Mi | 1Gi |
| Emulator | 500m | 2000m | 512Mi | 1Gi |

## Health Checks

### Registry & CPU Pool
- **Liveness**: TCP socket check on Styx port
- **Readiness**: TCP socket check on Styx port

### Emulator
- **Liveness**: `emu cat /dev/sysctl` exec probe
- **Readiness**: `emu cat /dev/sysctl` exec probe

## Styx Protocol

Inferno services communicate via the Styx protocol (also known as 9P). In Kubernetes:

- Services use ClusterIP for internal discovery
- The Registry service acts as the service discovery backbone
- CPU Pool workers register with the Registry on startup
- Emulator instances connect to both Registry and CPU Pool

### Service Discovery Flow
1. Registry starts and listens on port 6675
2. CPU Pool workers start and register with Registry via `tcp!inferno-registry!6675`
3. Emulator instances connect to Registry for service discovery
4. All inter-service communication uses the Styx protocol

## Troubleshooting

### Check pod status
```bash
kubectl get pods -n inferno
```

### View logs
```bash
kubectl logs -f deployment/inferno-registry -n inferno
kubectl logs -f deployment/inferno-cpupool -n inferno
kubectl logs -f deployment/inferno -n inferno
```

### Check services
```bash
kubectl get svc -n inferno
```

### Test Styx connectivity
```bash
kubectl exec -it deployment/inferno -n inferno -- emu cat /dev/sysctl
```

### Check HPA status
```bash
kubectl get hpa -n inferno
```

### View network policies
```bash
kubectl get networkpolicy -n inferno
```
