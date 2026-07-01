# Inferno OS Cluster Monitoring Guide

## Overview

The Inferno OS cluster includes monitoring and observability infrastructure:
- **Prometheus** metrics collection via ServiceMonitors
- **Fluent Bit** log aggregation
- **Health checks** via liveness and readiness probes

## Prerequisites

### Prometheus Operator

Install the Prometheus Operator (or kube-prometheus-stack):
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace
```

### Fluent Bit (Optional)

```bash
helm repo add fluent https://fluent.github.io/helm-charts
helm install fluent-bit fluent/fluent-bit \
  --namespace logging \
  --create-namespace
```

## Metrics

### Exposed Metrics

All services expose metrics on port 9100 at the `/metrics` endpoint.

### ServiceMonitors

Three ServiceMonitor resources are created:
- `inferno-registry-monitor` - Registry metrics
- `inferno-cpupool-monitor` - CPU Pool metrics
- `inferno-emulator-monitor` - Emulator metrics

### Verify Prometheus Scraping

```bash
# Check ServiceMonitor resources
kubectl get servicemonitor -n inferno

# Port-forward to Prometheus UI
kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n monitoring

# Then visit http://localhost:9090/targets to verify inferno targets
```

### Key Metrics to Monitor

| Metric | Description | Alert Threshold |
|--------|-------------|----------------|
| Container CPU usage | CPU utilization per pod | >80% sustained |
| Container memory usage | Memory utilization per pod | >85% sustained |
| Pod restart count | Number of pod restarts | >3 in 5 minutes |
| Ready replicas | Healthy replicas per deployment | < desired |
| HPA current replicas | Current vs desired scaling | maxReplicas reached |

## Logging

### Log Format

Inferno services log in the following format:
```
<timestamp> <level> <component>: <message>
```

### Fluent Bit Configuration

The logging ConfigMap (`inferno-logging-config`) provides:
- **Input**: Tails log files from `/var/log/inferno/`
- **Filter**: Adds cluster and namespace metadata
- **Parser**: Extracts structured fields from log lines
- **Output**: Stdout in JSON format (configurable for Elasticsearch, Loki, etc.)

### Viewing Logs

```bash
# Stream logs from all pods of a service
kubectl logs -f -l app.kubernetes.io/component=registry -n inferno
kubectl logs -f -l app.kubernetes.io/component=cpupool -n inferno
kubectl logs -f -l app.kubernetes.io/component=emulator -n inferno

# View logs with timestamps
kubectl logs --timestamps -l app.kubernetes.io/component=registry -n inferno
```

## Health Checks

### Probe Configuration

| Service | Liveness | Readiness |
|---------|----------|-----------|
| Registry | TCP :6675, 30s initial, 10s period | TCP :6675, 10s initial, 5s period |
| CPU Pool | TCP :6676, 30s initial, 10s period | TCP :6676, 15s initial, 5s period |
| Emulator | exec `emu cat /dev/sysctl`, 30s initial, 15s period | exec `emu cat /dev/sysctl`, 15s initial, 10s period |

### Monitoring Health

```bash
# Check pod conditions
kubectl get pods -n inferno -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}'

# Describe pod for probe failures
kubectl describe pod <pod-name> -n inferno | grep -A5 "Conditions:"
```

## Alerting (Example Prometheus Rules)

```yaml
groups:
  - name: inferno-cluster
    rules:
      - alert: InfernoPodCrashLooping
        expr: rate(kube_pod_container_status_restarts_total{namespace="inferno"}[5m]) > 0.5
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Inferno pod crash looping"

      - alert: InfernoHighCPU
        expr: container_cpu_usage_seconds_total{namespace="inferno"} > 0.8
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Inferno pod high CPU usage"

      - alert: InfernoRegistryDown
        expr: kube_deployment_status_replicas_available{deployment="inferno-registry",namespace="inferno"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Inferno registry has no available replicas"

      - alert: InfernoHPAMaxedOut
        expr: kube_horizontalpodautoscaler_status_current_replicas{namespace="inferno"} == kube_horizontalpodautoscaler_spec_max_replicas{namespace="inferno"}
        for: 15m
        labels:
          severity: warning
        annotations:
          summary: "Inferno HPA running at maximum replicas"
```

## Dashboard

### Grafana Dashboard (JSON Model)

Import the following dashboard ID or create panels for:

1. **Cluster Overview**: Pod count, restart rate, CPU/memory usage
2. **Registry**: Connection count, response time, error rate
3. **CPU Pool**: Worker utilization, task queue depth, scaling events
4. **Emulator**: Instance count, resource usage, probe success rate
5. **Networking**: Ingress request rate, error rate, latency
