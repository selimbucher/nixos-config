{ inputs, pkgs, config, ... }:
{
  home.packages = with pkgs; [
    awww
    sl
    gparted
    ntfs3g
    arch-install-scripts
    tree
    uv
    jq
    libnotify
    openconnect
    networkmanager-openconnect
    xkill
    hyprpicker
    pi-coding-agent
    gocryptfs
    claude-code
    codex
    (callPackage ../../pkgs/transcribe { })
    tigervnc
    (callPackage ../../pkgs/ethvpn.nix { })
    (callPackage ../../pkgs/tardis.nix { })
  ];
}
