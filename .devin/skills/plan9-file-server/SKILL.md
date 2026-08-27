---
name: plan9-file-server
description: Work with 9P/Styx file servers, namespaces, and the libstyx code in EchoCog/inferno-os.
version: 1.0.0
tags: [inferno, 9p, styx, plan9, file-server, namespace]
triggers:
  - inferno 9p
  - styx file server
  - plan9 file server
  - libstyx
  - inferno namespace
  - 9p registry
---

# 9P / Styx File Server Skill for Inferno OS

Use this skill whenever you need to extend, debug, or deploy a 9P/Styx file server inside the EchoCog/inferno-os repository.

## Core concepts

- **9P / Styx** is the single protocol Inferno uses to expose all resources as files. Every service is either a 9P client or a 9P server.
- **Namespace** is the per-process file tree built with `bind` and `mount`.
- **Qid** identifies a server-side file; **Fid** is a client-side handle.
- **Emu** runs the hosted kernel; native ports live under `os/`.

## Where the code lives

| Component | Location |
|---|---|
| Portable Styx C library | `tools/libstyx/` |
| Styx test harness | `tools/styxtest/` |
| Inferno registry service (Styx server) | `appl/cmd/ndb/registry.b` |
| CPU pool grid service | `appl/grid/cpupool.b` |
| Kernel devices (native) | `os/port/dev*.c` |
| Cluster Styx services | `k8s/base/registry-*.yaml`, `k8s/base/cpupool-*.yaml` |
| Helm chart | `helm/inferno-cluster/` |
| Docs | `docs/ARCHITECTURE.md`, `docs/NAMESPACE.md`, `docs/NETWORK_PORTS.md` |

## Standard ports

| Name | Port | Protocol | Purpose |
|---|---|---|---|
| Registry | 6675 | Styx/9P | Service discovery |
| CPU Pool | 6676 | Styx/9P | Remote task execution |
| Emulator | 6677 | Styx/9P | Hosted Inferno instance |
| loco | 8080 | HTTP/gateway | Local services |
| grid | 9090 | HTTP/gateway | Shared / distributed services |

## Step-by-step usage

### 1. Explore the current namespace

In `emu` or a bootable image:

```bash
ls /dev
ns                            # show current namespace
mount -c tcp!host!6675 /net   # example: mount a remote 9P service
```

### 2. Work with `tools/libstyx`

This is the standalone C library for building Styx clients and servers outside of Inferno.

- `tools/libstyx/styxserver.c` — server-side helpers
- `tools/libstyx/styxaux.h` — shared definitions
- `tools/libstyx/Plan9.c`, `Posix.c`, `Nt.c` — platform-specific transport shims

To build on Windows/Linux, use the provided `mkfile` or the `mk` build system.

### 3. Validate protocol changes

Use `tools/styxtest/styxtest.c` and `tools/styxtest/styxtest0.c` to exercise the protocol.

```bash
cd tools/styxtest
mk                            # or the platform-specific mkfile
./styxtest -h host -p 6675    # example invocation
```

### 4. Add or modify a Styx service

For Limbo services:

1. Implement `Sys->file2chan` or use `draw`/`sys` modules to export a namespace.
2. Follow the registry pattern in `appl/cmd/ndb/registry.b`.
3. Register via `Registry.register` on `tcp!*!6675` or another Styx port.

For C services using `libstyx`:

1. Implement the 9P message handlers (`Tversion`, `Tattach`, `Twalk`, `Topen`, `Tread`, `Twrite`, `Tclunk`).
2. Use the `styxserver` helpers to parse and serialize messages.
3. Bind to a TCP port; ensure the Kubernetes Service or `iptables`/`ns` rules expose it.

### 5. Deploy in Kubernetes

The cluster exposes 9P services as TCP ClusterIP/LB services:

```bash
kustomize build k8s/overlay/staging | kubectl apply -f -
# or
helm install inferno helm/inferno-cluster --namespace inferno --create-namespace
```

Verify with a port-forward and a 9P client:

```bash
kubectl port-forward -n inferno svc/inferno-registry 6675:6675
# then use a 9P client (e.g. v9fs, 9pfuse, or a Python py9p client) against localhost:6675
```

### 6. Debug a 9P issue

1. Check that the service pod is listening (`netstat -l` inside the pod or `ss -ltn`).
2. Capture traffic on the Styx port; look for `Rerror` responses.
3. Inspect `tools/libstyx/styxserver.c` error paths and the Limbo service's `error` channel.
4. Cross-reference expected Qid/Fid behavior with `docs/NAMESPACE.md`.

## Safety reminders

- Do not expose Styx ports to `--public` without peerbot review; default deny is enforced.
- `Registry` and `CPU Pool` are cluster-internal by default for a reason.
- Read-only mounts are preferred when the client only needs to inspect state.
