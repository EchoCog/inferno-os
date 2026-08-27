---
name: agent-zero
description: Specialize the generalized Agent Zero framework for the Inferno OS / 9P file-server architecture.
version: 1.0.0
tags: [agent-zero, inferno, 9p, styx, tools, specialization]
triggers:
  - agent zero inferno
  - specialize agent zero
  - agent zero tools 9p
  - inferno agent profile
  - agent zero styx
---

# Agent Zero Specialization for Inferno OS

Use this skill when you need to turn Agent Zero's generalized agent into an Inferno OS / 9P specialist. The generalized agent already handles reasoning and tool-calling; this skill specializes its **tool definitions** and **agent profile** for the Inferno architecture.

## What to specialize

Agent Zero discovers its capabilities from:

- `agents/<profile>/agent.yaml` — profile metadata
- `agents/<profile>/prompts/` — prompt overrides
- `agents/<profile>/tools/` — profile-specific `Tool` subclasses
- `agents/<profile>/extensions/` — lifecycle hooks

The base generalized profile is `agents/generalized/` in the Agent Zero framework.

## Working directory

If Agent Zero is not already available, clone it adjacent to this repo:

```bash
cd ..
git clone https://github.com/ReZorg/agent-zero.git
```

Then create the specialization under `agent-zero/agents/inferno-os/` (or an equivalent `usr/agents/inferno-os/` path in an Agent Zero container).

## Step 1: Create the agent profile

Create `agent-zero/agents/inferno-os/agent.yaml`:

```yaml
title: Inferno OS Specialist
description: Agent specialized in the Inferno distributed operating system, 9P/Styx file servers, namespaces, and the Limbo/Dis toolchain.
context: Use this agent when working on Inferno OS code, 9P/Styx services, namespace construction, k8s/helm deployments, or Limbo debugging.
```

Create `agent-zero/agents/inferno-os/prompts/agent.system.main.specifics.md`:

```markdown
## Your role

You are an Inferno OS specialist. You understand the Styx/9P protocol, Limbo/Dis, the hosted emulator (`emu`), native kernel ports (`os/`), and the Kubernetes cluster deployment.

## Expertise
- 9P/Styx clients and servers (`tools/libstyx`, `appl/cmd/ndb/registry.b`)
- Namespace construction (`bind`, `mount`, `namespace`)
- Limbo source under `appl/` and the Dis VM under `libinterp/`
- Native and hosted build systems (`mkfiles/`, `emu/`, `os/`)
- Cluster deployment with `k8s/` and `helm/inferno-cluster/`

## Operating principles
- Prefer read-only mounts for inspection.
- Keep Styx ports cluster-internal by default (6675, 6676, 6677).
- Respect `peerbot` training wheels: use `loco` (8080) and `grid` (9090) before `--public` or expert 667x ports, and require `tools/peerbot/learn.sh` progress for wider publishes.
- Validate protocol changes with `tools/styxtest` before deploying.
- When modifying a device or file server, preserve the `Qid`/`Fid` contract.
```

## Step 2: Add Inferno-specific tools

Create profile tools in `agent-zero/agents/inferno-os/tools/`. Each file is a `Tool` subclass; add a matching prompt file in `prompts/`.

### Example: `inferno_namespace.py`

```python
from helpers.tool import Tool, Response
import subprocess

class InfernoNamespaceTool(Tool):
    async def execute(self, method="ls", path="/", host="localhost", port="6677", **kwargs) -> Response:
        """Inspect or manipulate an Inferno namespace over 9P."""
        # Arguments are passed as a list, so no shell quoting is needed.

        # Use a 9P client available in the environment, e.g. 9pfs, v9fs, or a Python 9P client.
        # This example assumes a helper executable `9pread` that speaks 9P.
        if method == "ls":
            cmd = ["9pread", f"tcp!{host}!{port}", path]
        elif method == "read":
            cmd = ["9pread", "-f", f"tcp!{host}!{port}", path]
        elif method == "stat":
            cmd = ["9pread", "-s", f"tcp!{host}!{port}", path]
        else:
            return Response(message=f"Unsupported method: {method}", break_loop=False)

        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30, check=False)
            out = result.stdout + result.stderr
            if result.returncode != 0:
                return Response(message=f"9P error ({result.returncode}): {out}", break_loop=False)
            return Response(message=out, break_loop=False)
        except Exception as e:
            return Response(message=f"Namespace tool failed: {e}", break_loop=False)
```

### Example prompt: `prompts/agent.system.tool.inferno_namespace.md`

```markdown
## inferno_namespace

Inspect or manipulate an Inferno namespace over 9P.

Parameters:
- `method` (string): one of `ls`, `read`, `stat`
- `path` (string): absolute path in the remote namespace, default `/`
- `host` (string): host offering the 9P service, default `localhost`
- `port` (string): Styx port, default `6677`

Use this tool to explore `/dev`, `/net`, registry mounts, and CPU-pool names before attempting writes.
```

## Step 3: Wire the profile-specific response tool (optional)

If you need a different final-response format for Inferno deliverables, copy `agents/_example/tools/response.py` to `agents/inferno-os/tools/response.py` and adjust.

## Step 4: Test by spawning a subordinate

From a superior Agent Zero, delegate:

```python
# inside a tool or agent loop
call_subordinate(agent_name="inferno-os", message="List the /dev directory on the emulator at tcp!localhost!6677")
```

Then verify:

1. The agent profile appears in the UI/agent list.
2. `agent.system.main.specifics.md` loads into the system prompt.
3. `inferno_namespace` is callable and returns namespace entries.

## Step 5: Keep the specialization in sync

- When the cluster chart changes (new Styx ports, NetworkPolicies), update the tool defaults and the agent prompt.
- When `tools/libstyx` gains new helpers, update tool implementations to use them.
- Re-read the `plan9-file-server` skill for 9P/Styx protocol details.

## Peerbot training wheels

`inferno-os` exposes ports through `tools/peerbot` so developers learn the name space before opening the grid. When building Agent Zero tools that publish or connect to host ports, mirror these stages:

| Stage | User can open | Agent Zero rule |
|-------|---------------|-----------------|
| 0 — closed | nothing | Do not publish host ports. Inspect `/dev`, `/prog`, and `/net` locally. |
| 1 — loco | `8080` on `127.0.0.1` | Allow local-only services and loopback `9P` mounts. |
| 2 — grid | `9090` on `127.0.0.1` | Allow shared / discovery fabric, still without `--public`. |
| 3 — public | `0.0.0.0` | Require an explicit user confirmation before binding all interfaces. |
| 4 — expert | `6675`–`6677`, raw port assignments | Reserved for cluster debugging; prefer `loco`/`grid` aliases. |

Encourage the user to run `tools/peerbot/learn.sh` before unlocking wider access. In scripts, check progress with `tools/peerbot/peerbot.sh status --allow <nick>` and let peerbot print the gate error rather than overriding it.

## Common mistakes

- **Do not** hardcode Styx ports other than the standard registry/cpu-pool/emulator trio unless the user explicitly asks.
- **Do not** bypass `peerbot` gates silently; if the user needs `--public`, surface the gate message and let them run `learn.sh` or set `PEERBOT_EXPERT=1` explicitly.
- **Do not** run destructive namespace operations (`unmount`, `remove`) without confirming the target.
- **Do not** commit API keys or kubeconfigs in the agent profile; use Agent Zero project secrets.
