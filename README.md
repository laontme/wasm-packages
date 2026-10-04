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
nix develop -c skopeo inspect --raw oci:result-oci:1.8.2
```

Checks execute jq under Wasmtime (stdin, regex, arithmetic, slurp, mounted
files, and exit codes) and verify OCI blob digests and the packaged module.

## OCI contract

`jq-oci` produces an OCI image layout, with one gzip-compressed tar layer:

`lib/oci.nix` is a small wrapper around pinned
[systemstart/nix-oci](https://github.com/systemstart/nix-oci), which writes the
OCI blobs and metadata. Shell only stages guest files and their permissions.
Python is used only for validation. A local patch normalizes symlink modes
across macOS/Linux; the writer's full upstream test suite remains enabled.

- Platform: `wasi/wasm` (WASI Preview 1, recorded in `io.emmux.wasi.preview`).
- Entrypoint: `/bin/jq.wasm`; caller arguments follow it.
- Files: the module and jq/Oniguruma license notices under `/share/licenses/jq`.
- No runtime, shell, base image, or Nix store closure inside the image.
- Content-addressed blobs; sorted paths, fixed timestamps, ownership and modes.

Consumers fetch the manifest/layer, extract the entrypoint, and run it in a
WASI runtime with explicit stdin/stdout/stderr, arguments, environment and
filesystem grants. This is an image distribution format; ordinary native
Docker execution needs a WASI runtime integration.

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
skopeo login ghcr.io
skopeo copy --insecure-policy --preserve-digests \
  oci:result-oci:1.8.2 docker://ghcr.io/<owner>/<repo>/jq:1.8.2
```

## Add a package

Add its cross-build derivation under `packages/`, expose it in `flake.nix`,
then call `lib/oci.nix` with its output, name, and absolute guest entrypoint.
Add runtime checks before exposing a publishing workflow. Keep package
outputs limited to guest files and license notices.
