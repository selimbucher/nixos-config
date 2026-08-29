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

  # The gecko/mono MSI installers matching this nixpkgs' wine — the same
  # fetchurls the wine build itself would embed with embedInstallers = true.
  # Importing sources.nix directly keeps the versions in lockstep with wine
  # across nixpkgs bumps, without overriding wine (which would lose the
  # cache.nixos.org hit and force a local ~1h wine-staging build).
  # wineWow64Packages.staging is built from the `unstable` source set.
  wineAddonSources = import "${pkgs.path}/pkgs/applications/emulators/wine/sources.nix" { inherit pkgs; };
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

    # Installs wine-gecko (32+64) and wine-mono into a prefix. Run once per
    # prefix (and again after a nixpkgs wine bump changes the MSI versions):
    #   WINEPREFIX=~/.wine-ni wine-install-addons
    # Needed because wine here is the stock cached build without
    # embedInstallers, so wineboot has no MSIs to auto-install on prefix
    # creation. Dropping the MSIs in ~/.cache/wine did NOT work (wineboot -u
    # ignored them); direct msiexec /i is the verified method.
    (writeShellScriptBin "wine-install-addons" ''
      set -eu
      : "''${WINEPREFIX:?set WINEPREFIX to the target prefix, e.g. ~/.wine-ni}"
      for msi in ${wineAddonSources.unstable.gecko32} \
                 ${wineAddonSources.unstable.gecko64} \
                 ${wineAddonSources.unstable.mono}; do
        echo "installing ''${msi##*/} into $WINEPREFIX"
        ${wine}/bin/msiexec /i "$msi"
      done
      ${wine}/bin/wineserver -w
      echo "done"
    '')

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
