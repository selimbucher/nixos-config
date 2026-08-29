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
    # 11.14 at time of writing. Deliberately NOT overridden (e.g. with
    # embedInstallers): any .override makes this a non-Hydra derivation and
    # forces a local ~1h wine-staging build plus a yabridge rebuild. The
    # gecko/mono MSIs that embedInstallers would have baked in (needed for an
    # HTML engine in the prefixes — JUCE WebBrowserComponent sign-in panels
    # draw nothing without one) are installed per-prefix instead via the
    # wine-install-addons script in home/packages/media.nix, which pulls the
    # exact MSI versions this wine expects from nixpkgs' own sources.nix.
    yabridge = prev.wineWow64Packages.staging;
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
