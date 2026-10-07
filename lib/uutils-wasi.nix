{ pkgs, cross, rustPlatform, name, version, rev, sourceHash, cargoHash, description, multicall ? null, patches ? [] }:
rustPlatform.buildRustPackage {
  pname = "uutils-${name}-wasi";
  inherit version cargoHash patches;
  src = pkgs.fetchFromGitHub { owner = "uutils"; repo = name; inherit rev; hash = sourceHash; };
  postPatch = pkgs.lib.optionalString (multicall != null) ''
    cp ${multicall} src/bin-wasi.rs
    cat >> Cargo.toml <<'CARGO'
    [[bin]]
    name = "findutils"
    path = "src/bin-wasi.rs"
    CARGO
  '';
  env.CC_wasm32_wasip1 = "${cross.stdenv.cc}/bin/${cross.stdenv.cc.targetPrefix}cc";
  env.AR_wasm32_wasip1 = "${cross.stdenv.cc.bintools}/bin/${cross.stdenv.cc.targetPrefix}ar";
  buildPhase = ''
    runHook preBuild
    cargo build --locked --offline --release --target wasm32-wasip1 --bin ${name} -j "$NIX_BUILD_CORES"
    runHook postBuild
  '';
  doCheck = false;
  # Native stripping is disabled; exported packages use lib/strip-wasm.nix.
  dontStrip = true;
  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/share/licenses/${name}
    cp target/wasm32-wasip1/release/${name}.wasm $out/bin/
    cp LICENSE $out/share/licenses/${name}/
    runHook postInstall
  '';
  meta = { inherit description; license = pkgs.lib.licenses.mit; homepage = "https://github.com/uutils/${name}"; };
}
