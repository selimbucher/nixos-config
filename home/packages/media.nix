{ pkgs, ... }:
let
  # The single wine for the whole stack: the wow64 wine-staging build that
  # yabridge is compiled against (overlays/yabridge-wine11.nix). Being the
  # ONLY wine on PATH is what keeps a foreign build off the plugin prefixes —
  # that used to be a comment plus a second, deliberately 64-bit-only package;
  # now it is structural. A prefix has one wineserver speaking one protocol
  # version, and a different wine booting a prefix upgrades/corrupts it (that
  # is what broke the ROLI prefix in July).
  #
  # This build is wow64, so 32-bit installers work — the old interactive
  # `wine` (wine64Packages.staging) could not run them at all.
  #
  # Set WINEPREFIX yourself for anything that touches a plugin prefix:
  #   WINEPREFIX=~/.wine-ni wine ~/Downloads/Native\ Access.exe
  wine = pkgs.wineWow64Packages.yabridge;
in
{
  home.packages = with pkgs; [
    reaper
    yabridge
    yabridgectl
    qpwgraph
    winetricks
    pipewire.jack
    xdg-utils
    a2jmidid
    carla
    protontricks
    sox

    # Room EQ Wizard — room measurement with the UMIK-1 (serial 7203116; cal
    # files live in ~/Documents/UMIK-1). Unfree, which common.nix already
    # allows. Pin matters: this is the no-JRE upstream build and nixpkgs wraps
    # it with openjdk 8, which is the only runtime it works against.
    #
    # In Preferences -> Soundcard pick the raw ALSA devices (UMIK1 [plughw:2,0]
    # in, M4 [plughw:4,0] out), NOT "Default Device" — the PipeWire bridge
    # negotiates 16-bit, the direct devices give 24.
    roomeqwizard

    # Provides wine, wineserver, winecfg, wineboot, winedump. winetricks
    # needs no pinning: it resolves WINE="${WINE:-wine}" from PATH, and this
    # is the only wine there.
    wine

    # Kept under its own name because pkgs/reaper-tools/reaper-rescue.sh
    # invokes it directly when killing wedged plugin hosts.
    (writeShellScriptBin "wineserver-yabridge" ''
      exec ${wine}/bin/wineserver "$@"
    '')

    # Kept as an alias for muscle memory — reaper-logged (home/apps/
    # reaper-tools.nix) cleans ALL ~/.wine* prefixes and captures crash logs.
    (writeShellScriptBin "reaper-launch" ''
      exec reaper-logged "$@"
    '')
  ];
}
