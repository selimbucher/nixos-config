{ inputs, pkgs, config, ... }:
{
  home.packages = with pkgs; [
    awww
    blueman
    sl

    gparted
    ntfs3g
    arch-install-scripts
    gptfdisk

    inputs.kiwi.packages.${pkgs.stdenv.hostPlatform.system}.default
    inputs.native-instruments.packages.${pkgs.stdenv.hostPlatform.system}.default
    inputs.selim-icons.packages.${pkgs.stdenv.hostPlatform.system}.default

    icon-library

    signal-desktop
    vesktop
    gimp
    onlyoffice-desktopeditors
    libreoffice-fresh
    vscode
    nwg-displays
    tree
    uv
    vim

    localsend
    rofi
    pavucontrol
    libnotify

    showtime
    decibels
    gnome-sound-recorder
    gnome-calendar
    smile
    loupe
    foliate
    transmission_4-gtk
    snapshot
    evince
    gnome-calculator
    baobab
    gnome-font-viewer
    gnome-connections
    simple-scan
    gnome-weather
    clairvoyant
    collision
    commit
    gnome-decoder
    dialect
    forge-sparks
    fretboard
    hieroglyphic
    keypunch
    mousai
    file-roller

    (lutris.overrideAttrs (old: rec {
      version = "0.5.22";
      name = "lutris-${version}";
      src = pkgs.fetchFromGitHub {
        owner = "lutris";
        repo = "lutris";
        rev = "v${version}";
        hash = "sha256-4mNknvfJQJEPZjQoNdKLQcW4CI93D6BUDPj8LtD940A=";
      };
    }))

    spotify

    fastfetch
    tetris
    obs-studio

    playerctl
    neovim
    nwg-look

    jq
    inkscape
    obsidian
    proton-vpn
    blanket

    openconnect
    networkmanager-openconnect

    mailspring
    en-croissant
    brave
  ];
}
