{ pkgs, ... }:
{
  home.packages = with pkgs; [
    reaper
    yabridge
    yabridgectl
    wineWowPackages.staging
    qpwgraph
    winetricks
    pipewire.jack
    xdg-utils
    a2jmidid
    carla
    protontricks
    sox

    (writeShellScriptBin "reaper-launch" ''
      WINEPREFIX="$HOME/.wine-ni" wineserver -k || true
      exec pw-jack reaper "$@"
    '')
  ];
}
