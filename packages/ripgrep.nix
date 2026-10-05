{ pkgs, rustPlatform, target }:
rustPlatform.buildRustPackage {
  pname = "ripgrep-${target}";
  inherit (pkgs.ripgrep) version src;
  cargoHash = "sha256-AqizStE9ICd6mNDZWdeXg6dHuTiY+B0TNauQQYWUa84=";
  # The native buildRustPackage hook otherwise adds the build-host target too.
  buildPhase = ''
    runHook preBuild
    cargo build --locked --offline --release --no-default-features --target ${target} -j "$NIX_BUILD_CORES"
    runHook postBuild
  '';
  doCheck = false;
  dontStrip = true;
  installPhase = ''
    mkdir -p $out/bin $out/share/licenses/rg
    cp target/${target}/release/rg.wasm $out/bin/rg.wasm
    cp LICENSE-MIT UNLICENSE $out/share/licenses/rg/
  '';
  meta.license = [ pkgs.lib.licenses.mit pkgs.lib.licenses.unlicense ];
}
