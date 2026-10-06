{ pkgs, package }:
pkgs.runCommand "${package.pname}-stripped-${package.version}" {
  inherit (package) pname version meta;
  nativeBuildInputs = [ pkgs.wasm-tools ];
} ''
  cp -r ${package}/. $out/
  chmod -R u+w $out/bin
  for module in $out/bin/*.wasm; do
    # Preserve ABI/feature metadata, including component-type and dylink.0.
    wasm-tools strip -d '^(name|\.debug_.*|sourceMappingURL|external_debug_info)$' "$module" -o "$module.stripped"
    mv "$module.stripped" "$module"
    chmod 555 "$module"
  done
''
