{
  description = "WASI command packages for emmux and other runtimes";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  inputs.rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
  inputs.rust-overlay.url = "github:oxalica/rust-overlay";

  outputs = { self, nixpkgs, rust-overlay }:
    let
      systems = [ "aarch64-darwin" "aarch64-linux" "x86_64-linux" ];
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
          coreutilsToolchain = rustPkgs.rust-bin.stable."1.88.0".minimal.override { targets = [ "wasm32-wasip1" ]; };
          coreutilsRust = pkgs.makeRustPlatform { cargo = coreutilsToolchain; rustc = coreutilsToolchain; };
          stripWasm = package: import ./lib/strip-wasm.nix { inherit pkgs package; };
          coreutils = stripWasm (import ./packages/coreutils.nix { inherit pkgs; rustPlatform = coreutilsRust; });
          ripgrep = stripWasm (import ./packages/ripgrep.nix { inherit pkgs rustPlatform; target = "wasm32-wasip1"; });
          python = stripWasm (cross.callPackage ./packages/python.nix { upstream = pkgs.python314; buildPython = pkgs.python314; });
          findutils = stripWasm (import ./packages/findutils.nix { inherit pkgs cross; rustPlatform = coreutilsRust; });
          grep = stripWasm (import ./packages/grep.nix { inherit pkgs cross; rustPlatform = coreutilsRust; });
          sed = stripWasm (import ./packages/sed.nix { inherit pkgs cross; rustPlatform = coreutilsRust; });
          jq = stripWasm (cross.callPackage ./packages/jq.nix { upstream = pkgs.jq; });
        in {
          inherit jq ripgrep coreutils python findutils grep sed;
          default = jq;
          findutils-oci = import ./lib/oci.nix { inherit pkgs; package = findutils; name = "findutils"; entrypoint = "/bin/findutils.wasm"; commands = [ "findutils" "find" "locate" "updatedb" ]; };
          grep-oci = import ./lib/oci.nix { inherit pkgs; package = grep; name = "grep"; entrypoint = "/bin/grep.wasm"; };
          sed-oci = import ./lib/oci.nix { inherit pkgs; package = sed; name = "sed"; entrypoint = "/bin/sed.wasm"; };
          python-oci = import ./lib/oci.nix {
            inherit pkgs; package = python; name = "python"; entrypoint = "/bin/python.wasm";
          };
          coreutils-oci = import ./lib/oci.nix {
            inherit pkgs; package = coreutils; name = "coreutils"; entrypoint = "/bin/coreutils.wasm";
            commandsFile = "${coreutils}/share/coreutils/commands.txt";
          };
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
          findutils = pkgs.runCommand "findutils-check" { nativeBuildInputs = [ pkgs.wasmtime pkgs.python3 ]; } ''
            export HOME="$TMPDIR"
            python ${./tests/text-tools.py} findutils ${packages.findutils}/bin/findutils.wasm
            python ${./tests/oci.py} ${packages.findutils-oci} ${packages.findutils}/bin/findutils.wasm wasip1 - findutils,find,locate,updatedb
            touch $out
          '';
          grep = pkgs.runCommand "grep-check" { nativeBuildInputs = [ pkgs.wasmtime pkgs.python3 ]; } ''
            export HOME="$TMPDIR"
            python ${./tests/text-tools.py} grep ${packages.grep}/bin/grep.wasm
            python ${./tests/oci.py} ${packages.grep-oci} ${packages.grep}/bin/grep.wasm wasip1 - grep
            touch $out
          '';
          sed = pkgs.runCommand "sed-check" { nativeBuildInputs = [ pkgs.wasmtime pkgs.python3 ]; } ''
            export HOME="$TMPDIR"
            python ${./tests/text-tools.py} sed ${packages.sed}/bin/sed.wasm
            python ${./tests/oci.py} ${packages.sed-oci} ${packages.sed}/bin/sed.wasm wasip1 - sed
            touch $out
          '';
          python = pkgs.runCommand "python-check" { nativeBuildInputs = [ pkgs.wasmtime pkgs.python3 ]; } ''
            export HOME="$TMPDIR"
            python ${./tests/python.py} ${packages.python}/bin/python.wasm ${packages.python.version}
            python ${./tests/oci.py} ${packages.python-oci} ${packages.python}/bin/python.wasm wasip1 - python
            touch $out
          '';
          coreutils = pkgs.runCommand "coreutils-check" { nativeBuildInputs = [ pkgs.wasmtime pkgs.python3 ]; } ''
            export HOME="$TMPDIR"
            python ${./tests/coreutils.py} ${packages.coreutils}/bin/coreutils.wasm ${packages.coreutils}/share/coreutils/commands.txt
            python ${./tests/oci.py} ${packages.coreutils-oci} ${packages.coreutils}/bin/coreutils.wasm wasip1 - "$(paste -sd, ${packages.coreutils}/share/coreutils/commands.txt)"
            touch $out
          '';
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
