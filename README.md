# wasm-packages

Nix builds of WASI command-line tools for Emmux and other consumers, published
as CNCF Wasm OCI artifacts to GHCR.

## Packages and tags

| Package | Version | Minimum WASI | Commands | GHCR |
|---|---|---|---|---|
| jq | 1.8.2 | Preview 1 | `jq` | `ghcr.io/laontme/wasm-packages/jq:1.8.2` |
| ripgrep | 15.2.0 | Preview 1 | `rg` | `ghcr.io/laontme/wasm-packages/ripgrep:15.2.0` |
| Python | 3.14.7 | Preview 1 | `python` | `ghcr.io/laontme/wasm-packages/python:3.14.7` |
| uutils coreutils | 0.12.0 | Preview 1 | `coreutils` + 79 applets | `ghcr.io/laontme/wasm-packages/coreutils:0.12.0` |
| uutils findutils | 0.11.0-pre.eef2c971 | Preview 1 | `findutils`, `find`, `locate`, `updatedb` | `ghcr.io/laontme/wasm-packages/findutils:0.11.0-pre.eef2c971` |
| uutils grep | 0.2.0-pre.89fa10cb | Preview 1 | `grep` | `ghcr.io/laontme/wasm-packages/grep:0.2.0-pre.89fa10cb` |
| uutils sed | 0.3.0-pre.e6829c3d | Preview 1 | `sed` | `ghcr.io/laontme/wasm-packages/sed:0.3.0-pre.e6829c3d` |

Each package has a software-version tag and `latest`. Neither includes a WASI
suffix. Build for the **lowest WASI version that supports the required tool
behavior**: computation/file tools such as jq and rg use P1; a networking tool
such as curl would target P2 when its port requires P2 networking. P3 is chosen
only when needed. Do not publish redundant variants or a multi-platform index.
The config records the selected WASI target, and consumers must check it.
Pin a digest when exact bytes matter; version and `latest` tags may move.

Nixpkgs and the toolchains are pinned in `flake.lock`. Ripgrep uses Rust 1.85.0; the uutils packages use Rust 1.88.0.
Build hosts are ARM64 macOS and ARM64/x86-64 Linux; guest architecture is always Wasm.
Different build hosts can produce different bytes, even with the same sources.

## Build and run

```sh
nix build .#jq -o result-jq
nix build .#ripgrep -o result-rg
nix build .#ripgrep-oci -o result-rg-oci
nix build .#python -o result-python
nix build .#coreutils -o result-coreutils
nix build .#coreutils-oci -o result-coreutils-oci
nix develop
printf '{"hello":"world"}\n' | wasmtime result-jq/bin/jq.wasm -r '.hello'
printf 'hello world\n' | wasmtime result-rg/bin/rg.wasm hello -
wasmtime --dir .::/work result-rg/bin/rg.wasm hello /work
wasmtime result-coreutils/bin/coreutils.wasm --list
printf 'hello\n' | wasmtime result-coreutils/bin/coreutils.wasm cat
wasmtime --dir .::/ result-coreutils/bin/coreutils.wasm ls /
wasmtime result-python/bin/python.wasm -c 'import json; print(json.dumps({"hello": "world"}))'
nix flake check -L
```

Files/directories require explicit filesystem grants from the consumer.
For rg stdin searches, pass `-`: upstream automatic stdin detection assumes
stdin is not readable on platforms other than Unix/Windows. Ripgrep defaults
to one thread on this target; multiple threads, PCRE2 (`-P`), external
preprocessors and external decompression commands are unsupported. Normal
Rust regex matching is supported. P1 retains rg's exit codes 0/1/2.

## OCI and command discovery

Layouts follow the [CNCF Wasm OCI format](https://tag-runtime.cncf.io/wgs/wasm/deliverables/wasm-oci-artifact/).
`lib/strip-wasm.nix` removes DWARF, debug names and source-map references from
every exported package before testing and OCI assembly. ABI/feature custom
sections are preserved. `lib/oci.nix` uses ORAS to serialize and assemble artifacts.

- Manifest: `application/vnd.oci.image.manifest.v1+json`.
- Config: `application/vnd.wasm.config.v0+json`, `architecture: wasm`,
  `os: wasip1` (or the minimum required target), and matching `layerDigests`.
- One raw `application/wasm` layer; no tar layer, compression or Nix closure.
- P2 components include their imports/exports in `component` config metadata.
- Manifest annotation `me.laont.wasm.commands` is an ordered comma-separated
  string: `jq`, `rg`, or `coreutils` followed by its applets. No spaces or duplicate entries.
  The main command is first; package names and command names may differ.
- Description (from upstream package metadata), source, version, license and a fixed creation timestamp are annotations.
  License notices remain in the Nix package and CI binary/license artifact.

For the multicall coreutils package, the annotation looks like
`coreutils,cat,cp,mv,rm,...`, with the complete supported command list derived
from the built executable. `coreutils` is first and supports dispatch such as
`coreutils cat /work/file`. The consumer can expose each listed applet using
the same module; it must preserve the requested invocation, either through the
multicall binary's argv[0] dispatch or by invoking `coreutils <applet> ...`.
The annotation advertises commands; it does not grant permissions or claim
that all POSIX features are supported.

Consumers verify all digests and target requirements before executing with
explicit arguments, environment, standard streams and filesystem grants.
Checks cover jq processing and rg matching, traversal, ignore rules, stdin,
exit codes, all coreutils applet help/dispatch and representative file operations,
plus OCI content and command metadata.

## CI/CD

Pushes, pull requests and manual builds check packages and upload their binaries,
licenses, command inventories and OCI layouts. After all checks pass, pushes to `main` automatically
publish the exact checked layouts under version tags and update `latest`.
The separate manual publish workflow accepts `jq`, `ripgrep`, `coreutils`, `python`, `findutils`, `grep` or `sed`. Local builds never
publish. GHCR package visibility is managed separately in GitHub.

## uutils coreutils

The package builds [uutils coreutils](https://github.com/uutils/coreutils) 0.12.0
with its complete upstream `feat_wasm` feature set for `wasm32-wasip1`:
79 applets in one multicall module. The build verifies `coreutils --list` against
upstream's feature graph and derives the OCI command annotation from that list.
The Nix output and CI binary artifact include `share/coreutils/commands.txt`,
`inventory.json` and `excluded-commands.txt`.

Upstream excludes these native applets from this WASI feature set:
`chcon`, `chgrp`, `chmod`, `chown`, `chroot`, `df`, `du`, `env`, `groups`, `hostname`,
`id`, `install`, `kill`, `logname`, `mkfifo`, `mknod`, `more`, `nohup`, `pinky`,
`runcon`, `stat`, `stdbuf`, `stty`, `sync`, `tac`, `timeout`, `uptime`, `users`, `who`,
`whoami`. Included applets can still have target-specific limitations: WASI P1
provides filesystem access through grants, but does not provide every native
process, ownership or terminal operation. The package follows upstream's WASI
support; inclusion does not promise every GNU option works.

For coreutils, mount the working tree at guest `/` (for example,
`wasmtime --dir .::/ ...`). Path canonicalization in applets such as `mv`
requires access to guest `/`; granting only `/work` can make these operations
fail even when both operands are inside `/work`. Only the granted host tree
is accessible through that guest root.

## Python

The package builds upstream CPython 3.14.7 for WASI P1. Pure-Python standard
library modules are frozen into the executable, so the single raw OCI Wasm
layer runs without a separate stdlib directory. Tests, IDLE/Tk, turtle demos
and ensurepip are omitted. The included frozen-module inventory is available
in `share/python/frozen-stdlib.txt`; optional C extensions depend on the build
and unavailable OS features remain unavailable. This build includes zlib/gzip
and omits SQLite, SSL, ctypes, bz2/lzma/zstd, readline and the C UUID extension. Frozen modules have no backing
source files or package data directory. `-X frozen_modules=off` is unsupported.

Use `python -c`, `python -m`, stdin, or a script file. Grant the consumer access
to your scripts and data, for example:

```sh
wasmtime --dir .::/ result-python/bin/python.wasm /script.py
```

This is a Python CLI, not Emmux's existing `goccy/go-python` embedding API.
Both execute real CPython, but go-python transpiles its Wasm build into Go and
adds typed callbacks and host policy hooks. A standard WASI P1 command does
not include those hooks: Emmux must provide a separate protocol for tool calls.
Networking, subprocess execution, native threads and arbitrary native pip
extensions are not supported by this package. No pip/ensurepip is bundled. The stripped module is about 18 MB, exceeding
Emmux's current 16 MiB module limit; using it there requires a higher limit
or a smaller stdlib build.

## uutils findutils, grep and sed

These packages pin upstream development commits, with `-pre.<commit>` versions:
released versions lag the current WASI work. Sources and Cargo dependencies are
hash-pinned. They provide common shell operations on P1 without extra host APIs.
Upstream targets GNU compatibility, but these are not complete GNU replacements;
regex, locale and OS-specific options can differ. In particular, uutils sed
supports byte/UTF-8 processing rather than arbitrary locale encodings.

Findutils is packaged as one multicall module. Invoke `findutils find ...`,
`findutils locate ...`, or `findutils updatedb ...`; argv[0] applet dispatch is
also supported. Its command annotation is `findutils,find,locate,updatedb`.
A WASI-only patch replaces Rust's panicking `split_paths` in locate with
colon-separated database paths. Sed shell-execution requests return an error
instead of trapping on WASI. Create and query a database inside a granted tree:

```sh
nix build .#findutils -o result-findutils
nix build .#grep -o result-grep
nix build .#sed -o result-sed
nix develop
wasmtime --dir .::/ result-findutils/bin/findutils.wasm find / -name '*.rs'
wasmtime --dir .::/ result-findutils/bin/findutils.wasm updatedb --localpaths=/ --prunepaths= --output=/locatedb
wasmtime --dir .::/ result-findutils/bin/findutils.wasm locate -d /locatedb '*.rs'
printf 'hello world\n' | wasmtime result-grep/bin/grep.wasm hello
printf 'hello world\n' | wasmtime result-sed/bin/sed.wasm 's/world/WASI/'
```

Mount the working tree at guest `/` for file operations. `xargs` is excluded:
P1 has no child-process API. Find's `-exec`/`-execdir`/`-ok` and sed's shell
execution commands are unsupported for the same reason. GNU originals would
also require a host process extension to perform these operations on P1.
Checks cover grep regex modes, recursion, stdin and exit codes; sed ranges,
backreferences, hold space, script files and in-place editing; find filters,
regex, depth, null output and deletion; updatedb/locate round trips; and OCI
metadata and stripping for all three packages.
