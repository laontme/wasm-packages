{ pkgs, cross, rustPlatform }:
import ../lib/uutils-wasi.nix {
  inherit pkgs cross rustPlatform;
  name = "sed";
  version = "0.3.0-pre.e6829c3d";
  rev = "e6829c3d1673aae6615708ce0b22d9e7e7266d37";
  sourceHash = "sha256-43/86YykNwEvbNQxVYnnNSPztmys+ejfKe2Coolgito=";
  cargoHash = "sha256-BomWBWY387LtuI6dbC6Pv4fAbgeXvu7RDAyRStNbaFQ=";
  patches = [ ../patches/sed-wasi-shell-error.patch ];
  description = "Cross-platform Rust implementation of sed";
}
