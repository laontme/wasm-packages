{ pkgs, cross, rustPlatform }:
import ../lib/uutils-wasi.nix {
  inherit pkgs cross rustPlatform;
  name = "findutils";
  version = "0.11.0-pre.eef2c971";
  rev = "eef2c9718230f04666a91ccaf0a346f16b89c088";
  sourceHash = "sha256-M3VSs+M8g/ArpP/SuJWpuH+jbqN+jWLPsWrCT9YJGDA=";
  cargoHash = "sha256-pbCBkgM6DyzLfq30AgpPNYriiwy3n7BD1GKqVB++cfA=";
  description = "Rust implementation of GNU findutils";
  patches = [ ../patches/findutils-wasi-database-paths.patch ];
  multicall = ./findutils-main.rs;
}
