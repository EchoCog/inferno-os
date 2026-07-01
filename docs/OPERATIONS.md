# Inferno OS Cluster Operations Guide

## Common Operations

### Viewing Cluster Status

```bash
# Overview of all resources
kubectl get all -n inferno

# Pod status with node info
kubectl get pods -n inferno -o wide

# Service endpoints
kubectl get endpoints -n inferno

# HPA status
kubectl get hpa -n inferno
```

### Scaling Services

#### Manual Scaling
```bash
# Scale CPU pool workers
kubectl scale deployment inferno-cpupool --replicas=10 -n inferno

# Scale emulator instances
kubectl scale deployment inferno --replicas=5 -n inferno
```

#### Adjusting Autoscaler
```bash
# Edit HPA directly
kubectl edit hpa inferno-cpupool-hpa -n inferno

# Or patch specific values
kubectl patch hpa inferno-hpa -n inferno \
  --type merge -p '{"spec":{"maxReplicas":15}}'
```

### Rolling Updates

```bash
# Update image for all services
kubectl set image deployment/inferno-registry registry=ghcr.io/echocog/inferno-os:v2.0 -n inferno
kubectl set image deployment/inferno-cpupool cpupool=ghcr.io/echocog/inferno-os:v2.0 -n inferno
kubectl set image deployment/inferno inferno=ghcr.io/echocog/inferno-os:v2.0 -n inferno

# Monitor rollout
kubectl rollout status deployment/inferno-registry -n inferno
kubectl rollout status deployment/inferno-cpupool -n inferno
kubectl rollout status deployment/inferno -n inferno
```

### Rollback

```bash
# View rollout history
kubectl rollout history deployment/inferno -n inferno

# Rollback to previous version
kubectl rollout undo deployment/inferno -n inferno

# Rollback to specific revision
kubectl rollout undo deployment/inferno --to-revision=2 -n inferno
```

## Troubleshooting

### Pod Issues

```bash
# Check pod events
kubectl describe pod <pod-name> -n inferno

# View logs
kubectl logs <pod-name> -n inferno

# Follow logs
kubectl logs -f deployment/inferno-registry -n inferno

# Previous container logs (after restart)
kubectl logs <pod-name> -n inferno --previous

# Exec into pod
kubectl exec -it <pod-name> -n inferno -- /bin/sh
```

### Service Connectivity

```bash
# Test Registry connectivity from within the cluster
kubectl run test-styx --rm -it --image=busybox -n inferno -- \
  nc -zv inferno-registry 6675

# Test CPU Pool connectivity
kubectl run test-styx --rm -it --image=busybox -n inferno -- \
  nc -zv inferno-cpupool 6676

# DNS resolution
kubectl run test-dns --rm -it --image=busybox -n inferno -- \
  nslookup inferno-registry.inferno.svc.cluster.local
```

### Network Policy Debugging

```bash
# List all policies
kubectl get networkpolicy -n inferno

# Describe specific policy
kubectl describe networkpolicy inferno-registry-policy -n inferno

# Temporarily allow all traffic (for debugging only)
# kubectl delete networkpolicy inferno-default-deny -n inferno
```

### Resource Issues

```bash
# Check resource usage
kubectl top pods -n inferno
kubectl top nodes

# Check resource quotas
kubectl describe resourcequota -n inferno

# Check events for scheduling issues
kubectl get events -n inferno --sort-by='.lastTimestamp'
```

## Maintenance

### Certificate Renewal

Certificates are managed automatically by cert-manager. To check status:
```bash
kubectl get certificate -n inferno
kubectl describe certificate inferno-tls -n inferno
```

### Configuration Updates

```bash
# Update ConfigMap
kubectl edit configmap inferno-config -n inferno

# Restart pods to pick up changes
kubectl rollout restart deployment/inferno-registry -n inferno
kubectl rollout restart deployment/inferno-cpupool -n inferno
kubectl rollout restart deployment/inferno -n inferno
```

### Backup and Recovery

#### Export current state
```bash
kubectl get all -n inferno -o yaml > inferno-backup.yaml
```

#### Registry data backup
```bash
kubectl exec deployment/inferno-registry -n inferno -- \
  tar czf /tmp/registry-backup.tar.gz /usr/inferno/services
kubectl cp inferno/$(kubectl get pod -l app.kubernetes.io/component=registry -n inferno -o jsonpath='{.items[0].metadata.name}'):/tmp/registry-backup.tar.gz ./registry-backup.tar.gz
```

## Disaster Recovery

### Full Cluster Rebuild

1. Ensure Docker images are available in the registry
2. Apply manifests:
   ```bash
   kustomize build k8s/overlay/production | kubectl apply -f -
   ```
3. Verify all pods are running:
   ```bash
   kubectl wait --for=condition=ready pod --all -n inferno --timeout=300s
   ```
4. Verify service registration:
   ```bash
   kubectl exec deployment/inferno -n inferno -- emu cat /dev/sysctl
   ```

### Single Service Recovery

```bash
# Delete and recreate a specific deployment
kubectl delete deployment inferno-cpupool -n inferno
kustomize build k8s/overlay/production | kubectl apply -f -
```

## Performance Tuning

### CPU Pool Worker Optimization

Adjust the number of maximum workers per CPU pool pod:
```bash
kubectl edit configmap inferno-config -n inferno
# Change CPUPOOL_MAX_WORKERS value
```

### Emulator Memory Tuning

For memory-intensive workloads, increase limits:
```bash
kubectl patch deployment inferno -n inferno --type json \
  -p '[{"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/memory","value":"2Gi"}]'
```
