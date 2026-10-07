{ pkgs, cross, rustPlatform }:
import ../lib/uutils-wasi.nix {
  inherit pkgs cross rustPlatform;
  name = "grep";
  version = "0.2.0-pre.89fa10cb";
  rev = "89fa10cbe01e8f67c07cb609b498039070c7508e";
  sourceHash = "sha256-c1ZYeI8dd/x5KjbGpSP0ZR3/uItIrgBpcPjErgkYAqc=";
  cargoHash = "sha256-bVQKBJKebVf0FWxWOw26giXssQ2RZfUywqNAJhVi/5Y=";
  description = "Rust implementation of GNU Grep";
}
