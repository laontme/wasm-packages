{ pkgs, rustPlatform }:
rustPlatform.buildRustPackage {
  pname = "uutils-coreutils-wasi";
  inherit (pkgs.uutils-coreutils) version src;
  cargoHash = "sha256-aLnQOXiQD9IL6ZiBi/ENF0aHud0kCyHZrnetkV+ZTFE=";
  postPatch = ''
    rm .cargo/config.toml
  '';
  buildPhase = ''
    runHook preBuild
    cargo build --locked --offline --release --no-default-features --features feat_wasm --target wasm32-wasip1 -j "$NIX_BUILD_CORES"
    runHook postBuild
  '';
  nativeBuildInputs = [ pkgs.wasmtime pkgs.python3 ];
  doCheck = false;
  dontStrip = true;
  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/share/licenses/coreutils
    cp target/wasm32-wasip1/release/coreutils.wasm $out/bin/
    cp LICENSE $out/share/licenses/coreutils/
    mkdir -p $out/share/coreutils
    export HOME="$TMPDIR"
    wasmtime $out/bin/coreutils.wasm --list | LC_ALL=C sort > applets.txt
    python ${../tests/coreutils-inventory.py} Cargo.toml applets.txt $out/share/coreutils
    { echo coreutils; cat applets.txt; } > $out/share/coreutils/commands.txt
    runHook postInstall
  '';
  meta = { inherit (pkgs.uutils-coreutils.meta) description license; };
}
