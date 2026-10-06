{ lib, stdenv, upstream }:
stdenv.mkDerivation {
  pname = "jq-wasi";
  inherit (upstream) version src;
  strictDeps = true;
  enableParallelBuilding = true;
  configureFlags = [
    "--disable-shared"
    "--enable-static"
    "--disable-docs"
    "--with-oniguruma=builtin"
  ];
  env.CFLAGS = "-O2 -D_WASI_EMULATED_SIGNAL -D_WASI_EMULATED_PROCESS_CLOCKS";
  env.LDFLAGS = "-lwasi-emulated-signal -lwasi-emulated-process-clocks";
  # Native stripping is disabled; exported packages use lib/strip-wasm.nix.
  dontStrip = true;
  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/share/licenses/jq
    cp jq $out/bin/jq.wasm
    cp COPYING $out/share/licenses/jq/
    cp vendor/oniguruma/COPYING $out/share/licenses/jq/oniguruma-COPYING
    runHook postInstall
  '';
  meta = {
    description = upstream.meta.description;
    license = [ lib.licenses.mit lib.licenses.bsd2 ];
  };
}
