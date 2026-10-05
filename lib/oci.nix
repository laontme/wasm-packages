{ pkgs, package, name, entrypoint, wasi ? "wasip1", commands ? [ name ] }:
let
  annotations = {
    "me.laont.wasm.commands" = pkgs.lib.concatStringsSep "," commands;
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
assert commands != [ ] && builtins.head commands == name;
assert pkgs.lib.length (pkgs.lib.unique commands) == pkgs.lib.length commands;
assert pkgs.lib.all (command: builtins.match "[^,[:space:]]+" command != null) commands;
pkgs.runCommand "${name}-${package.version}-oci" {
  nativeBuildInputs = [ pkgs.oras pkgs.jq pkgs.coreutils ] ++ pkgs.lib.optional (wasi == "wasip2") pkgs.wasm-tools;
} ''
  cp ${package}${entrypoint} ${pkgs.lib.escapeShellArg "${name}.wasm"}
  digest="sha256:$(sha256sum ${pkgs.lib.escapeShellArg "${name}.wasm"} | cut -d ' ' -f 1)"
  ${pkgs.lib.optionalString (wasi == "wasip2") ''
    wasm-tools component wit ${pkgs.lib.escapeShellArg "${name}.wasm"} > component.wit
    sed -n 's/^  import \(.*\);$/\1/p' component.wit | jq -Rn '[inputs]' > imports.json
    sed -n 's/^  export \(.*\);$/\1/p' component.wit | jq -Rn '[inputs]' > exports.json
  ''}
  jq -cnS ${pkgs.lib.optionalString (wasi == "wasip2") "--slurpfile imports imports.json --slurpfile exports exports.json"} --arg digest "$digest" --arg os ${pkgs.lib.escapeShellArg wasi} \
    '{architecture: "wasm", os: $os, layerDigests: [$digest]} ${pkgs.lib.optionalString (wasi == "wasip2") "+ {component: {imports: $imports[0], exports: $exports[0]}}"}' > config.json
  oras push --no-tty --oci-layout "$out:${package.version}" --image-spec v1.0 \
    --config config.json:application/vnd.wasm.config.v0+json \
    ${annotationFlags} ${pkgs.lib.escapeShellArg "${name}.wasm:application/wasm"}
''
