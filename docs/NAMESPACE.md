# Your machine is a file tree

Distributed Inferno is powerful — and a bad first lesson.

Start where your custom IDE intuition already works: **CPU, GPU, net, and
processes show up as files in a tree.** Learn that locally. Exporting the
tree across the network is the same idea later, not a different religion.

---

## The one idea

| Old habit | Inferno habit |
|-----------|----------------|
| Special APIs per device | Paths under `/dev`, `/prog`, `/net`, … |
| “Open Device Manager” | `ls /dev` |
| “Attach debugger to PID” | `ls /prog` then read files in that dir |
| “Configure the NIC” | files under `/net/ether0` / `/net/ipifc` |
| Distributed magic | `export` / `mount` the **same** tree elsewhere |

If it felt intuitive when devices lived in your IDE’s file tree — that *is*
Inferno’s model. The window manager and Acme are optional clothing.

---

## Local tour (do this before “grid”)

After Express (`./try.sh`) or Bootable (`easyinit` shell):

```text
ls /
ls /dev
ls /prog
ls /net
```

Or run the guided tour (hosted build / full image):

```text
myspace
```

What you are looking at:

```text
/
├── dev/          devices & console  (sensors & actuators)
├── prog/         running processes  (each PID is a directory)
├── net/          ethernet, IP, TCP  (the wire as files)
├── chan/         IPC channels
├── env/          environment
├── dis/          programs (Dis modules)
└── n/            mount points for *other* trees (later)
```

### Devices as files

```text
cat /dev/sysname          # who am I?
ls /dev                   # what can I touch?
```

A “CPU device” or “GPU device” in an IDE sidebar is the same pattern:
something real, bound into the name space, opened like a file.

### Processes as directories

```text
ls /prog
ls /prog/1                # status, ns, ... for one process
```

### Network as a directory

```text
ls /net
```

When `/net` is there, you already have the substrate for loco (8080) and
grid (9090). You do **not** need to understand Styx federation yet.

---

## When distributed finally shows up

Only after the local tree feels boringly obvious:

1. Something on **this** machine listens (sensor) — often on **loco / 8080**
2. Something **exports** a subtree
3. Another machine **mounts** it under `/n/...`
4. **grid / 9090** is the shared fabric nickname for that wider world

Same open/read/write/close. Different place in the tree.

```text
/n/remote/...     # “someone else’s files” — still just paths
```

Details of ports and addresses: [NETWORK_PORTS.md](NETWORK_PORTS.md).

---

## Teaching order (stick to it)

1. **Tree** — `ls /`, `/dev`, `/prog`  
2. **Bind** — attach a device into the tree  
3. **Loco** — local service on 8080  
4. **Grid** — shared services on 9090  
5. **Export/mount** — the distributed punchline  

Skipping to step 5 is why people bounce.

---

## Related

- First boot: [GETTING_STARTED.md](GETTING_STARTED.md)
- Ports: [NETWORK_PORTS.md](NETWORK_PORTS.md)
- Expert: `ns` (namespace construction), `man/1/ftree`, `man/2/newns`
