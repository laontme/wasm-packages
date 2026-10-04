{ pkgs, buildOCIImage, package, name, entrypoint }:
assert pkgs.lib.hasPrefix "/" entrypoint;
buildOCIImage {
  name = "${name}-${package.version}-oci";
  os = "wasi";
  arch = "wasm";
  ref = package.version;
  entrypoint = [ entrypoint ];
  workingDir = "/";
  labels = {
    "org.opencontainers.image.title" = name;
    "org.opencontainers.image.version" = package.version;
    "org.opencontainers.image.source" = "https://github.com/laontme/wasm-packages";
  };
  annotations = {
    "org.opencontainers.image.title" = name;
    "org.opencontainers.image.version" = package.version;
    "org.opencontainers.image.source" = "https://github.com/laontme/wasm-packages";
    "org.opencontainers.image.licenses" = pkgs.lib.concatMapStringsSep " AND "
      (license: license.spdxId) (pkgs.lib.toList package.meta.license);
    "io.emmux.wasi.preview" = "1";
  };
  # Stage guest files at the image root without including their Nix closure.
  extraCommands = ''
    cp -R ${package}/. .
    chmod -R u+w .
    find . -type d -exec chmod 0755 {} +
    find . -type f -exec chmod 0644 {} +
    chmod 0755 .${pkgs.lib.escapeShellArg entrypoint}
  '';
}
