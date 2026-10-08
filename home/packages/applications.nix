{ inputs, pkgs, config, osConfig, ... }:
let
  # Native Access on yabridge's wine: ni-wine brings stock wine-staging, and
  # its NTK daemon outlives NA, so plugins in ~/.wine-ni then fail with
  # "wine client error: version mismatch". ni-wine honours $WINE; this only
  # rewraps the launcher, nothing is rebuilt on the wine side.
  ni-wine = inputs.native-instruments.packages.${pkgs.stdenv.hostPlatform.system}.default.overridePythonAttrs (old: {
    makeWrapperArgs = old.makeWrapperArgs ++ pkgs.lib.optionals osConfig.deviceConfig.wineFork
      [ "--set-default" "WINE" "${pkgs.wineWow64Packages.yabridge}/bin/wine" ];
  });
  demucs = pkgs.callPackage ../../pkgs/demucs.nix { };
  basic-pitch = pkgs.callPackage ../../pkgs/basic-pitch.nix { };
in
{
  home.packages = with pkgs; [
    ni-wine
    inputs.claude-desktop-bin.packages.${pkgs.stdenv.hostPlatform.system}.default

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
    r2modman
    demucs
    basic-pitch
    (pkgs.callPackage ../../pkgs/stem2midi.nix { inherit demucs basic-pitch; })
    todoist-electron
  ];
}
