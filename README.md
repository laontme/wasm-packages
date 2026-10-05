# wasm-packages

Nix builds of WASI command-line tools for Emmux and other consumers, published
as CNCF Wasm OCI artifacts to GHCR.

## Packages and tags

| Package | Version | Minimum WASI | Commands | GHCR |
|---|---|---|---|---|
| jq | 1.8.2 | Preview 1 | `jq` | `ghcr.io/laontme/wasm-packages/jq:1.8.2` |
| ripgrep | 15.2.0 | Preview 1 | `rg` | `ghcr.io/laontme/wasm-packages/ripgrep:15.2.0` |

Each package has a software-version tag and `latest`. Neither includes a WASI
suffix. Build for the **lowest WASI version that supports the required tool
behavior**: computation/file tools such as jq and rg use P1; a networking tool
such as curl would target P2 when its port requires P2 networking. P3 is chosen
only when needed. Do not publish redundant variants or a multi-platform index.
The config records the selected WASI target, and consumers must check it.
Pin a digest when exact bytes matter; version and `latest` tags may move.

Nixpkgs and the toolchains are pinned in `flake.lock`. Ripgrep uses Rust 1.85.0.
Build hosts are ARM64/x86-64 Linux/macOS; guest architecture is always Wasm.
Different build hosts can produce different bytes, even with the same sources.

## Build and run

```sh
nix build .#jq -o result-jq
nix build .#ripgrep -o result-rg
nix build .#ripgrep-oci -o result-rg-oci
nix develop
printf '{"hello":"world"}\n' | wasmtime result-jq/bin/jq.wasm -r '.hello'
printf 'hello world\n' | wasmtime result-rg/bin/rg.wasm hello -
wasmtime --dir .::/work result-rg/bin/rg.wasm hello /work
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
`lib/oci.nix` uses ORAS to serialize and assemble artifacts.

- Manifest: `application/vnd.oci.image.manifest.v1+json`.
- Config: `application/vnd.wasm.config.v0+json`, `architecture: wasm`,
  `os: wasip1` (or the minimum required target), and matching `layerDigests`.
- One raw `application/wasm` layer; no tar layer, compression or Nix closure.
- P2 components include their imports/exports in `component` config metadata.
- Manifest annotation `me.laont.wasm.commands` is an ordered comma-separated
  string: `jq` or `rg` for current packages. No spaces or duplicate entries.
  The main command is first; package names and command names may differ.
- Description (from the pinned Nixpkgs upstream package metadata), source, version, license and a fixed creation timestamp are annotations.
  License notices remain in the Nix package and CI binary/license artifact.

For a multicall coreutils package, the annotation will look like
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
exit codes, plus OCI content and command metadata.

## CI/CD

Pushes, pull requests and manual builds check packages and upload their binaries,
licenses and OCI layouts. After all checks pass, pushes to `main` automatically
publish the exact checked layouts under version tags and update `latest`.
The separate manual publish workflow accepts `jq` or `ripgrep`. Local builds never
publish. GHCR package visibility is managed separately in GitHub.

## Next package: full uutils coreutils

Package one multicall executable as `coreutils`, rather than separate images
for individual applets. Inventory and build the full upstream command suite;
do not silently select a small subset to make the build pass. Determine the
minimum WASI target from actual functionality and dependencies, and record
unavailable OS features explicitly. A full suite may require porting because
WASI does not provide all native process, user-management or terminal APIs.

Expose `coreutils` and `coreutils-oci` in the flake. Supply `commands` to
`lib/oci.nix`, with `coreutils` first and the built applets following. Add the
package to both workflow matrices/choices. Verify the advertised list against
the binary, test `coreutils <applet>` dispatch, and exercise representative
read/write/filesystem operations with grants and expected exit codes.
