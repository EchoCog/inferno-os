Inferno® is a distributed operating system, originally developed at Bell Labs, but now developed and maintained by Vita Nuova® as Free Software.  Applications written in Inferno's concurrent programming language, Limbo, are compiled to its portable virtual machine code (Dis), to run anywhere on a network in the portable environment that Inferno provides.  Unusually, that environment looks and acts like a complete operating system.

Inferno represents services and resources in a file-like name hierarchy.  Programs access them using only the file operations open, read/write, and close.  `Files' are not just stored data, but represent devices, network and protocol interfaces, dynamic data sources, and services.  The approach unifies and provides basic naming, structuring, and access control mechanisms for all system resources.  A single file-service protocol (the same as Plan 9's 9P) makes all those resources available for import or export throughout the network in a uniform way, independent of location. An application simply attaches the resources it needs to its own per-process name hierarchy ('name space').

Inferno can run 'native' on various ARM, PowerPC, SPARC and x86 platforms but also 'hosted', under an existing operating system (including AIX, FreeBSD, IRIX, Linux, MacOS X, Plan 9, and Solaris), again on various processor types.

This repository includes source code for the basic applications, Inferno itself (hosted and native), all supporting software, including the native compiler suite, essential executables and supporting files.

## Cluster Deployment

Inferno OS can be deployed as a distributed cluster on Kubernetes, containerizing the existing grid framework (registry, CPU pool, emulator) as microservices.

### Quick Start

**Docker:**
```bash
# Development build
docker build -t inferno-os:dev .

# Production build (multi-stage, non-root)
docker build -f Dockerfile.production -t inferno-os:latest .
```

**Kubernetes (Kustomize):**
```bash
# Deploy to staging
kustomize build k8s/overlay/staging | kubectl apply -f -

# Deploy to production
kustomize build k8s/overlay/production | kubectl apply -f -
```

**Kubernetes (Helm):**
```bash
helm install inferno helm/inferno-cluster --namespace inferno --create-namespace
```

### Cluster Architecture

| Service | Component | Port | Protocol |
|---------|-----------|------|----------|
| Registry | `ndb/registry` | 6675 | Styx/9P |
| CPU Pool | `grid/cpupool` | 6676 | Styx/9P |
| Emulator | `emu` | 6677 | Styx/9P |

### Documentation

- [Deployment Guide](docs/DEPLOYMENT.md) - Complete deployment instructions
- [Kubernetes Reference](docs/KUBERNETES.md) - K8s manifest details
- [Architecture](docs/ARCHITECTURE.md) - System design and component mapping
- [Operations](docs/OPERATIONS.md) - Scaling, troubleshooting, maintenance
- [Monitoring](docs/MONITORING.md) - Prometheus, logging, alerting

### CI/CD

GitHub Actions pipeline (`.github/workflows/build-deploy.yml`) provides automated build, test, validation, and deployment to staging/production.
This repository includes source code for the basic applications, Inferno itself (hosted and native), all supporting software, including the native compiler suite, essential executables and supporting files.

<!-- Declarative environment verification -->
