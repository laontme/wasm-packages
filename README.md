# wasm-packages

Nix builds of WASI command-line tools, packaged as OCI images for emmux and
other applications. The first package is **jq 1.8.2**, built from upstream
source with bundled Oniguruma (regex support) and decimal-number support.
Nixpkgs, the source hash, and the LLVM/WASI toolchain are pinned by `flake.lock`.

## Build and run

```sh
nix build .#jq
nix develop
printf '%s\n' '{"hello":"world"}' | wasmtime result/bin/jq.wasm -r '.hello'
```

The output is a standalone WASI Preview 1 core module exporting `_start`.
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

## OCI contract

`jq-oci` produces an OCI layout following the
[CNCF Wasm OCI artifact format](https://tag-runtime.cncf.io/wgs/wasm/deliverables/wasm-oci-artifact/).
`lib/oci.nix` supplies metadata to ORAS, the standard OCI artifact client from
pinned Nixpkgs. It does not implement blob or manifest serialization itself.

- Manifest: `application/vnd.oci.image.manifest.v1+json`.
- Config: `application/vnd.wasm.config.v0+json`, with `architecture: wasm`,
  `os: wasip1`, and `layerDigests` matching the layer descriptor.
- Exactly one layer: `application/wasm`, containing the raw jq module.
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

## Publishing later

Nothing is published by building or checking. The build workflow only tests
and uploads GitHub Actions artifacts. The publish workflow requires an
explicit manual dispatch and writes the versioned image to
`ghcr.io/<owner>/<repo>/jq:1.8.2`, using `GITHUB_TOKEN` with `packages:write`.
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
