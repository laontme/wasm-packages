{
  description = "WASI command packages for emmux and other runtimes";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  inputs.rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
  inputs.rust-overlay.url = "github:oxalica/rust-overlay";

  outputs = { self, nixpkgs, rust-overlay }:
    let
      systems = [ "aarch64-darwin" "x86_64-darwin" "aarch64-linux" "x86_64-linux" ];
      eachSystem = nixpkgs.lib.genAttrs systems;
    in {
      packages = eachSystem (system:
        let
          pkgs = import nixpkgs { inherit system; };
          cross = import nixpkgs {
            localSystem = system;
            crossSystem = nixpkgs.lib.systems.examples.wasm32-wasip1;
          };
          rustPkgs = import nixpkgs { inherit system; overlays = [ rust-overlay.overlays.default ]; };
          toolchain = rustPkgs.rust-bin.stable."1.85.0".minimal.override {
            targets = [ "wasm32-wasip1" "wasm32-wasip2" ];
          };
          rustPlatform = pkgs.makeRustPlatform { cargo = toolchain; rustc = toolchain; };
          mkRg = target: import ./packages/ripgrep.nix { inherit pkgs rustPlatform target; };
          rg-p1 = mkRg "wasm32-wasip1";
          rg-p2 = mkRg "wasm32-wasip2";
          jq = cross.callPackage ./packages/jq.nix { upstream = pkgs.jq; };
        in {
          inherit jq rg-p1 rg-p2;
          default = jq;
          rg = rg-p1;
          rg-p1-oci = import ./lib/oci.nix {
            inherit pkgs; package = rg-p1; name = "rg"; entrypoint = "/bin/rg.wasm";
          };
          rg-p2-oci = import ./lib/oci.nix {
            inherit pkgs; package = rg-p2; name = "rg"; entrypoint = "/bin/rg.wasm"; wasi = "wasip2";
          };
          jq-oci = import ./lib/oci.nix {
            inherit pkgs;
            package = jq;
            name = "jq";
            entrypoint = "/bin/jq.wasm";
          };
        });
      checks = eachSystem (system:
        let
          pkgs = import nixpkgs { inherit system; };
          packages = self.packages.${system};
        in {
          rg-p1 = pkgs.runCommand "rg-p1-check" { nativeBuildInputs = [ pkgs.wasmtime pkgs.python3 ]; } ''
            export HOME="$TMPDIR"
            bash ${./tests/rg.sh} ${packages.rg-p1}/bin/rg.wasm ${packages.rg-p1.version} 2
            python ${./tests/oci.py} ${packages.rg-p1-oci} ${packages.rg-p1}/bin/rg.wasm wasip1
            touch $out
          '';
          rg-p2 = pkgs.runCommand "rg-p2-check" { nativeBuildInputs = [ pkgs.wasmtime pkgs.python3 pkgs.wasm-tools ]; } ''
            export HOME="$TMPDIR"
            wasm-tools validate ${packages.rg-p2}/bin/rg.wasm
            wasm-tools component wit ${packages.rg-p2}/bin/rg.wasm > world.wit
            sed -n 's/^  import \(.*\);$/\1/p' world.wit > imports.txt
            diff -u ${./tests/rg-p2-imports.txt} imports.txt
            grep -q 'export wasi:cli/run@0.2.0;' world.wit
            bash ${./tests/rg.sh} ${packages.rg-p2}/bin/rg.wasm ${packages.rg-p2.version} 1
            python ${./tests/oci.py} ${packages.rg-p2-oci} ${packages.rg-p2}/bin/rg.wasm wasip2 ${./tests/rg-p2-imports.txt}
            touch $out
          '';
          jq = pkgs.runCommand "jq-wasi-check" {
            nativeBuildInputs = [ pkgs.wasmtime pkgs.python3 ];
          } ''
            export HOME="$TMPDIR"
            bash ${./tests/jq.sh} ${packages.jq}/bin/jq.wasm ${packages.jq.version}
            python ${./tests/oci.py} ${packages.jq-oci} ${packages.jq}/bin/jq.wasm
            touch $out
          '';
        });
      devShells = eachSystem (system:
        let pkgs = import nixpkgs { inherit system; };
        in { default = pkgs.mkShell { packages = [ pkgs.wasmtime pkgs.oras pkgs.wasm-tools ]; }; });
    };
}
