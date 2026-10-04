{ pkgs, package, name, entrypoint }:
let
  annotations = {
    "org.opencontainers.image.title" = name;
    "org.opencontainers.image.version" = package.version;
    "org.opencontainers.image.source" = "https://github.com/laontme/wasm-packages";
    "org.opencontainers.image.licenses" = pkgs.lib.concatMapStringsSep " AND "
      (license: license.spdxId) (pkgs.lib.toList package.meta.license);
    "org.opencontainers.image.created" = "1970-01-01T00:00:00Z";
  };
  annotationFlags = pkgs.lib.concatStringsSep " " (pkgs.lib.mapAttrsToList
    (key: value: "--annotation ${pkgs.lib.escapeShellArg "${key}=${value}"}") annotations);
in
assert pkgs.lib.hasPrefix "/" entrypoint;
pkgs.runCommand "${name}-${package.version}-oci" {
  nativeBuildInputs = [ pkgs.oras pkgs.jq pkgs.coreutils ];
} ''
  cp ${package}${entrypoint} ${pkgs.lib.escapeShellArg "${name}.wasm"}
  digest="sha256:$(sha256sum ${pkgs.lib.escapeShellArg "${name}.wasm"} | cut -d ' ' -f 1)"
  jq -cnS --arg digest "$digest" \
    '{architecture: "wasm", os: "wasip1", layerDigests: [$digest]}' > config.json
  oras push --no-tty --oci-layout "$out:${package.version}" --image-spec v1.0 \
    --config config.json:application/vnd.wasm.config.v0+json \
    ${annotationFlags} ${pkgs.lib.escapeShellArg "${name}.wasm:application/wasm"}
''
