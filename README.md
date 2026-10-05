# wasm-packages

Nix builds of WASI command-line tools, packaged as OCI images for emmux and
other applications. Packages include **jq 1.8.2** and **ripgrep 15.2.0**. jq is built from upstream
source with bundled Oniguruma (regex support) and decimal-number support.
Nixpkgs, the source hash, and the LLVM/WASI toolchain are pinned by `flake.lock`.

## Build and run

```sh
nix build .#jq
nix develop
printf '%s\n' '{"hello":"world"}' | wasmtime result/bin/jq.wasm -r '.hello'
```

The jq output is a standalone WASI Preview 1 core module exporting `_start`.
No JavaScript glue or native libraries are needed. Files and directories must
be explicitly mounted by the host:

```sh
wasmtime --dir .::/work result/bin/jq.wasm '.' /work/input.json
```

Build hosts: ARM64 and x86-64 Linux/macOS. The guest target is always
`wasm32-unknown-wasip1`; it is independent of the build host's CPU.

```sh
nix flake check -L
nix build .#jq-oci -o result-oci
nix develop -c oras manifest fetch --oci-layout result-oci:1.8.2
```

Checks execute jq under Wasmtime (stdin, regex, arithmetic, slurp, mounted
files, and exit codes) and verify OCI blob digests and the packaged module.

## Ripgrep: Preview 1 and Preview 2

Both variants use pinned Rust **1.85.0**. `rg` aliases `rg-p1`.

```sh
nix build .#rg-p1 -o result-rg-p1
nix build .#rg-p2 -o result-rg-p2
nix develop
printf 'hello world\n' | wasmtime result-rg-p1/bin/rg.wasm hello -
printf 'hello world\n' | wasmtime result-rg-p2/bin/rg.wasm hello -
wasmtime --dir .::/work result-rg-p2/bin/rg.wasm hello /work
nix build .#rg-p1-oci -o result-rg-p1-oci
nix build .#rg-p2-oci -o result-rg-p2-oci
```

- `rg-p1`: `wasm32-wasip1` core module exporting `_start`, for P1 hosts such as wazero.
- `rg-p2`: directly compiled `wasm32-wasip2` component exporting `wasi:cli/run@0.2.0`, for component hosts. Plain wazero requires an additional component/P2 layer.
- P2 imports are pinned by `tests/rg-p2-imports.txt` and checked against the built component. Rust's standard library includes TCP/UDP interface imports even though these search tests do not use networking. Consumers must satisfy the listed interfaces; networking imports do not imply a network grant.
- Use an explicit `-` for stdin searches: upstream's automatic stdin detection assumes it is not readable on platforms other than Unix/Windows.
- Searches use one thread by default on these WASI targets; requesting multiple threads is unsupported. PCRE2 (`-P`), external preprocessors (`--pre`), and external decompression commands are not supported by these builds. The normal Rust regex engine is available.
- P1 retains statuses 0 (match), 1 (no match), and 2 (error). WASI 0.2 CLI exposes success/failure rather than numeric exit codes: P2 maps both no-match and errors to failure (Wasmtime status 1). Inspect stderr to distinguish them.

Checks cover stdin, regex matching, case-insensitive file search, recursive traversal, ignore/hidden-file filtering, exit behavior, P2 validation/interface imports, and OCI descriptors. P2 is verified with Wasmtime here; execution in Emmux's developing P2 implementation remains an integration check there.

CI builds separate binary/license and OCI-layout artifacts for `jq`, `rg-p1`, and `rg-p2`. Successful builds on pushes to `main` automatically publish the checked OCI artifacts. The manual publish workflow also accepts a package choice and targets `ghcr.io/<owner>/<repo>/<package>:<version>`. Pull requests and other branches only build and test.

## OCI contract

`jq-oci`, `rg-p1-oci`, and `rg-p2-oci` produce OCI layouts following the
[CNCF Wasm OCI artifact format](https://tag-runtime.cncf.io/wgs/wasm/deliverables/wasm-oci-artifact/).
`lib/oci.nix` supplies metadata to ORAS, the standard OCI artifact client from
pinned Nixpkgs. It does not implement blob or manifest serialization itself.

- Manifest: `application/vnd.oci.image.manifest.v1+json`.
- Config: `application/vnd.wasm.config.v0+json`, with `architecture: wasm`,
  `os: wasip1` for core modules or `os: wasip2` for the P2 component, and `layerDigests` matching the layer descriptor.
- P2 configs include `component.imports` and `component.exports`, extracted from the built component.
- Exactly one layer: `application/wasm`, containing the raw module or component.
- The first layer is the entrypoint; there is no filesystem entrypoint path,
  tar archive, compression, container image config, or Nix store closure.
- Source, version and license metadata are manifest annotations.
- License notices remain in the Nix package and the `jq-wasi` CI artifact.

Consumers verify the manifest/config/layer digests, read the layer as a module,
then run it with explicit stdin/stdout/stderr, arguments, environment and
filesystem grants. Runtime arguments and mounts are supplied by the host.
Metadata uses a fixed timestamp so identical inputs produce identical layouts.

The initial published `1.8.2` artifact used a conventional container-image
format (`wasi/wasm`, gzip tar). Consumers pinning that old digest retain the
old format; the corrected artifact has a different manifest digest.

emmux currently embeds Python through `goccy/go-python` / `pythonwasm2go`.
Its current checkout has no generic WASI command runner or OCI package loader.
This repo defines a proposed package contract; adding that consumer to emmux
is separate work. File access depends on preopens; process creation and Unix
signal behavior are constrained by WASI. Time-zone-dependent functions need
runtime-specific support and are not covered by the smoke checks.

## Publishing

Local builds and checks do not publish. The build workflow tests and uploads
GitHub Actions artifacts, then publishes all packages after all checks pass
on pushes to `main`. It copies the checked OCI layouts without rebuilding.
The separate publish workflow supports manual publication of one package to
`ghcr.io/<owner>/<repo>/<package>:<version>`, using `GITHUB_TOKEN` with `packages:write`.
There is no automatic `latest` update. GHCR package visibility is managed
separately in GitHub.

To publish manually when ready:

```sh
nix build .#jq-oci -o result-oci
nix develop
oras login ghcr.io
oras cp --from-oci-layout result-oci:1.8.2 ghcr.io/<owner>/<repo>/jq:1.8.2
```

## Add a package

Add its cross-build derivation under `packages/`, expose it in `flake.nix`,
then call `lib/oci.nix` with its output, name, and absolute guest entrypoint.
Add runtime checks before exposing a publishing workflow. Keep package
outputs limited to guest files and license notices.
