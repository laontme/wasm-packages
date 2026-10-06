{ lib, stdenv, upstream, buildPython, zlib, pkg-config }:
stdenv.mkDerivation {
  pname = "python-wasi";
  inherit (upstream) version src;
  strictDeps = true;
  nativeBuildInputs = [ buildPython pkg-config ];
  buildInputs = [ zlib ];
  enableParallelBuilding = true;
  preConfigure = ''
    export CONFIG_SITE="$PWD/Tools/wasm/wasi/config.site-wasm32-wasi"
  '';
  postConfigure = ''
    make pybuilddir.txt
    cp "$(cat pybuilddir.txt)"/_sysconfigdata_*.py Lib/
    ${buildPython}/bin/python3 ${../lib/freeze-python-stdlib.py}
  '';
  configureFlags = [
    "--with-build-python=${buildPython}/bin/python3"
    "--disable-shared"
    "--disable-test-modules"
    "--without-ensurepip"
    "--with-frozen-modules"
  ];
  env.CFLAGS = "-O2 -g0";
  # Native stripping is disabled; exported packages use lib/strip-wasm.nix.
  dontStrip = true;
  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/share/licenses/python $out/share/python
    cp python.wasm $out/bin/python.wasm
    cp LICENSE $out/share/licenses/python/
    cp frozen-stdlib.txt $out/share/python/
    runHook postInstall
  '';
  meta = { inherit (upstream.meta) description license; };
}
