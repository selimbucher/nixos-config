{ inputs, pkgs, config, ... }:
{
  home.packages = with pkgs; [
    inputs.native-instruments.packages.${pkgs.stdenv.hostPlatform.system}.default

    blueman
    gparted
    ntfs3g
    arch-install-scripts
    gptfdisk
    icon-library
    signal-desktop
    vesktop
    gimp
    onlyoffice-desktopeditors
    libreoffice-fresh
    vscode
    nwg-displays
    tree
    vim
    localsend
    pavucontrol
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
    obs-studio
    playerctl
    neovim
    nwg-look
    inkscape
    obsidian
    proton-vpn
    blanket
    en-croissant
    brave
    geary
    gnome-text-editor
    thunderbird
    prismlauncher
  ];
}
