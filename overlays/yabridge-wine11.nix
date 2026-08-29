# yabridge from master (Wine 10/11 embedding support, merged upstream
# 2026-04-26) built against wine-staging 11.x instead of the 9.21 pin.
#
# Why: wine-9.21-era bugs wedge/kill the plugin hosts (X11 embedding races,
# GUI thread deadlocks) and every such wedge freezes or crashes REAPER through
# yabridge's blocking IPC — see ~/reaper-crashlogs and robbert-vdh/yabridge
# issue #409. The 5.1.1 release only works with wine <= 9.21; master supports
# current wine (community-verified with REAPER + NI/FabFilter/XLN on
# wine 11.7-11.14, incl. a NixOS build of this exact shape).
#
# Everything follows wineWow64Packages.yabridge — the yabridge build itself,
# its hardcoded WINELOADER, yabridgectl's winedump PATH, and the `wine` on
# PATH plus the wineserver-yabridge wrapper in home/packages/media.nix —
# so replacing that one attribute migrates the whole stack consistently.
# Note that since media.nix dropped its separate wine64Packages.staging,
# this attribute is also the interactive wine, so a rollback here rolls
# back everything, not just the plugin hosts.
# yabridgectl needs no changes: it reuses yabridge.src, and master's
# Cargo.lock is identical to 5.1.1's (verified), so the cargoHash holds.
#
# ROLLBACK: remove this overlay from common.nix and rebuild — but wine 11
# upgrades the ~/.wine* prefixes one-way on first launch, so also restore the
# prefix backups taken before the first wine-11 start.
final: prev: {
  wineWow64Packages = prev.wineWow64Packages // {
    # 11.14 at time of writing.
    #
    # embedInstallers symlinks the wine-gecko and wine-mono MSIs into
    # $out/share/wine/{gecko,mono}, the directory wineboot searches when it
    # creates or updates a prefix. Without it NO prefix on this machine gets an
    # HTML engine (~/.wine-spectrasonics had only the 60K npmshtml.dll shim),
    # so anything rendering into an embedded IE/MSHTML control draws nothing —
    # JUCE's WebBrowserComponent, which is what plugin "activate / sign in"
    # panels are built from. Dropping the MSIs in ~/.cache/wine does not work:
    # wineboot -u ignored them there, only a manual msiexec /i installed them.
    #
    # Cost: wine is no longer a cache hit, so this is a local wine-staging
    # build (and a yabridge rebuild after it, since yabridge follows this
    # attribute). Same 11.14 source, so the wineserver protocol version is
    # unchanged and the ~/.wine* prefixes are not migrated or touched.
    #
    # Existing prefixes do not pick gecko up retroactively — run
    # `WINEPREFIX=~/.wine-<name> wineboot -u` once per prefix after rebuilding.
    yabridge = prev.wineWow64Packages.staging.override { embedInstallers = true; };
  };

  yabridge = prev.yabridge.overrideAttrs (old: {
    version = "5.1.2-alpha-b580a9f";
    src = prev.fetchFromGitHub {
      owner = "robbert-vdh";
      repo = "yabridge";
      rev = "b580a9f7fc46509767ca156d4f92872552b9e571"; # master, 2026-08-02
      hash = "sha256-TiKiyE3GZYCX1+vooHdD03fAhNQPAA1IzTfkG++I7TY=";
    };
    # Drop libyabridge-drop-32-bit-support.patch (first in the list): the
    # 32-bit handling it patched was reworked on master and bitbridge is
    # disabled anyway — same recipe as the NixOS report in yabridge#409.
    patches = prev.lib.drop 1 old.patches;
  });
}
