# AGENTS.md

## Cursor Cloud specific instructions

### What this repo is
Inferno OS (a distributed OS) plus a Kubernetes "cluster deployment" layer that runs
three existing components as Styx/9P microservices: `ndb/registry` (6675),
`grid/cpupool` (6676) and `emu` (6677). See `README.md` and `INSTALL`. The build
system is Plan 9 `mk` (not make); the hosted target is **Linux/386 (32-bit)**.

### What the startup update script already did (do NOT redo)
- Installed 32-bit build deps (`gcc-multilib`, `libc6-dev-i386`, `libx11-dev:i386`, `libxext-dev:i386`).
- Pointed `cc` at **gcc** (the build uses gcc-only flags like `-fno-aggressive-loop-optimizations`; the image default `cc` is clang, which fails).
- Symlinked `/usr/inferno -> /workspace` because the committed `mkconfig` hardcodes `ROOT=/usr/inferno`. Build/run from `/usr/inferno`.
- Cloned the freetype submodule into `libfreetype/libfreetype` and checked out commit `546237e1bbbb1269b5f76a878ea5eed3c8e268b5`. This exact commit is required: `.gitmodules` points at upstream freetype, but its current HEAD/releases do NOT match Inferno's patched `include/freetype` headers (they expect GPOS-kerning + COLRv1 fields together). `546237e1` is the commit upstream `inferno-os/inferno-os` pins.

### Building `emu` (this is a dev step, NOT in the update script)
```
export PATH=$PATH:/usr/inferno/Linux/386/bin
cd /usr/inferno
./makemk.sh
mk "EMUOPTIONS=-fcommon -Dpthread_yield=sched_yield" install
```
Gotchas:
- `-fcommon` is mandatory: modern GCC defaults to `-fno-common`, which breaks the emu link with "multiple definition" of tentative globals (`coherence`, `bflag`, `exdebug`, ...).
- `-Dpthread_yield=sched_yield`: glibc >= 2.31 removed `pthread_yield`.
- `mk install` builds all libraries and `emu` first, then **fails later in `utils/5c`** (native cross-compilers, same `-fno-common` issue). That failure is expected and irrelevant to hosted Inferno — `Linux/386/bin/emu` is already built by then.
- The freshly linked `emu` **crashes at startup under modern libX11**: libX11's ELF constructor calls `malloc()` (emu overrides malloc) which calls `coherence()` before `emu`'s `main()` initialises it. `emu/Linux/os.c` leaves `coherence` NULL (unlike `emu/NetBSD/os.c` / `emu/Nt/os.c`). Fix by relinking `emu` once with a tiny init object that mirrors those ports:
```
printf 'extern void nofence(void);\nvoid (*coherence)(void) = nofence;\n' > /tmp/coherence_init.c
cc -m32 -fno-common -c /tmp/coherence_init.c -o /tmp/coherence_init.o
cd /usr/inferno/emu/Linux
mk clean
mk "EMUOPTIONS=-fcommon -Dpthread_yield=sched_yield" install 2> /tmp/emu_build.log   # produces the crashing o.emu + build log
LINK=$(grep -m1 'cc -m32  -o o.emu ' /tmp/emu_build.log)
eval "${LINK/-o o.emu /-o o.emu \/tmp\/coherence_init.o }"
cp o.emu /usr/inferno/Linux/386/bin/emu
```

### Running services / hello-world
- **Always run `emu` WITHOUT `-c1`.** `-c1` enables the Dis JIT, which executes generated native code from non-executable memory and immediately faults ("sys: segmentation violation") on this NX kernel. The interpreter (omit `-c1`) is stable. Note the k8s/Docker manifests use `-c1`; drop it for local runs.
- Limbo bytecode (`.dis`) is prebuilt and committed under `dis/` (e.g. `dis/ndb/registry.dis`, `dis/grid/cpupool.dis`), so you do not need the Limbo compiler to run the services.
- The VM has **no X server**, so the GUI (`emu wm/wm`) is not usable; the cluster services are headless and unaffected.
- Registry demo (registers two services and queries them by attribute; see `man/4/registry`):
```
export PATH=$PATH:/usr/inferno/Linux/386/bin
cd /usr/inferno
printf '%s\n' \
 'mkdir /mnt' 'mkdir /mnt/registry' \
 'mount {ndb/registry} /mnt/registry' \
 'echo mysvc description hello persist 1 > /mnt/registry/new' \
 'cat /mnt/registry/index' \
 'ndb/regquery description hello' | emu sh
```
(`/` in the emu namespace maps to `/usr/inferno`; `mkdir /mnt` creates `/usr/inferno/mnt` on the host — clean it up afterward.)

### Cluster infra (k8s / Helm) validation
`kubectl` (includes kustomize) and `helm` are not installed by the update script; install them if needed. These validate offline: `kubectl kustomize k8s/overlay/{staging,production}`, `helm lint helm/inferno-cluster`, `helm template inferno helm/inferno-cluster`. `kubectl apply --dry-run=client` needs a live cluster API and will not work without one.

### Note on tracked build artifacts
The repo commits prebuilt binaries under `Linux/386/bin/` and `dis/`. A local build will modify/add several of these — do not commit those incidental artifact changes.
