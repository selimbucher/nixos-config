{ pkgs, ... }:
{
  home.packages = with pkgs; [
    python3
    julia
    ghc
    # OCaml pinned to 4.13.1 for Compiler Design course
    ocaml-ng.ocamlPackages_4_13.ocaml
    ocaml-ng.ocamlPackages_4_13.ocamlbuild
    ocaml-ng.ocamlPackages_4_13.findlib
    ocaml-ng.ocamlPackages_4_13.dune_3
    ocaml-ng.ocamlPackages_4_13.utop

    duckdb
    dnsutils
    usbutils

    cargo
    rustc
    rustfmt
    clippy
    rust-analyzer
    gnumake
    zip
    unzip
    clang
    # ocamlopt 4.13 links via `gcc`; expose only that binary to avoid clashing with clang (ld, cc, ...)
    (writeShellScriptBin "gcc" ''
      exec ${gcc}/bin/gcc "$@"
    '')
    llvm
    uv
    neovim
    nodejs
  ];
}
