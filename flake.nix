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
            targets = [ "wasm32-wasip1" ];
          };
          rustPlatform = pkgs.makeRustPlatform { cargo = toolchain; rustc = toolchain; };
          ripgrep = import ./packages/ripgrep.nix { inherit pkgs rustPlatform; target = "wasm32-wasip1"; };
          jq = cross.callPackage ./packages/jq.nix { upstream = pkgs.jq; };
        in {
          inherit jq ripgrep;
          default = jq;
          ripgrep-oci = import ./lib/oci.nix {
            inherit pkgs; package = ripgrep; name = "ripgrep"; commands = [ "rg" ]; entrypoint = "/bin/rg.wasm";
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
          ripgrep = pkgs.runCommand "ripgrep-check" { nativeBuildInputs = [ pkgs.wasmtime pkgs.python3 ]; } ''
            export HOME="$TMPDIR"
            bash ${./tests/rg.sh} ${packages.ripgrep}/bin/rg.wasm ${packages.ripgrep.version} 2
            python ${./tests/oci.py} ${packages.ripgrep-oci} ${packages.ripgrep}/bin/rg.wasm wasip1
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
