{ pkgs, ... }:
let
  # yabridge is hard-pinned to this exact wine build. ANYTHING that touches the
  # ~/.wine-ni prefix (plugin installers, wineserver, winetricks) must use this
  # same wine — a prefix has one wineserver and it speaks one protocol version,
  # so mixing this with wine64Packages.staging (11.12) triggers the
  # "server uses a different version" error. Never point 11.12 at ~/.wine-ni.
  wineNi = pkgs.wineWow64Packages.yabridge;
in
{
  home.packages = with pkgs; [
    reaper
    yabridge
    yabridgectl
    wine64Packages.staging   # interactive wine — for NON-plugin prefixes only
    qpwgraph
    winetricks
    pipewire.jack
    xdg-utils
    a2jmidid
    carla
    protontricks
    sox

    # yabridge's pinned wine, exposed under distinct names so it can coexist
    # with the interactive `wine` (11.12) on PATH. Use these for ANY prefix
    # that yabridge hosts plugins from — set WINEPREFIX yourself:
    #   WINEPREFIX=~/.wine-ni wine-yabridge ~/Downloads/Native\ Access.exe
    (writeShellScriptBin "wine-yabridge" ''
      exec ${wineNi}/bin/wine "$@"
    '')
    (writeShellScriptBin "wineserver-yabridge" ''
      exec ${wineNi}/bin/wineserver "$@"
    '')

    # Convenience shortcut for the main plugin prefix (~/.wine-ni).
    (writeShellScriptBin "wine-ni" ''
      export WINEPREFIX="$HOME/.wine-ni"
      exec ${wineNi}/bin/wine "$@"
    '')

    (writeShellScriptBin "reaper-launch" ''
      WINEPREFIX="$HOME/.wine-ni" ${wineNi}/bin/wineserver -k || true
      exec pw-jack reaper "$@"
    '')
  ];
}
