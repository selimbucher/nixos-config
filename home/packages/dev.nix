{ pkgs, ... }:
{
  home.packages = with pkgs; [
    python3
    julia
    ghc
    duckdb
    dnsutils
    usbutils

    cargo
    rustc
    rustfmt
    clippy
    rust-analyzer
    gnumake
    clang
    llvm
    uv
    neovim
    nodejs
  ];
}
