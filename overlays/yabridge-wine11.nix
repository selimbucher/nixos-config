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
# yabridgectl reuses yabridge.src. The fork's yabridgectl is a member of a
# cargo workspace with Cargo.lock at the repository root, so it is built from
# there (see the yabridgectl override at the bottom).
#
# ROLLBACK: remove this overlay from common.nix and rebuild — but wine 11
# upgrades the ~/.wine* prefixes one-way on first launch, so also restore the
# prefix backups taken before the first wine-11 start.
{ inputs }:
final: prev:
let
  # Wine is built from nixpkgs-wine (pinned in flake.nix), NOT from the system
  # nixpkgs — see the note on that input. Only the Wine build closure comes
  # from here; yabridge below still tracks the system nixpkgs, since its
  # rebuild is minutes rather than an hour.
  winePkgs = import inputs.nixpkgs-wine {
    inherit (prev.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
  # giang17's d2d1-dcomp Wine fork (rebased onto Wine dev releases, NOT
  # staging): implements the D2D 1.3 + DirectComposition path that JUCE 8.0.x
  # plugin editors hardwire (pre-8.0.13 JUCE has no software fallback at all).
  # Without it, soothe3's editor is black and kills the host. The fork's
  # wine.inf hides wine_get_version from plug-in hosts (yabridge-host.exe,
  # reaper.exe, FL64.exe, ...); per prefix, HKCU\Software\Wine\HideWineVersion
  # or HKCU\Software\Wine\AppDefaults\<exe>\HideWineVersion = "Y"/"N"
  # overrides that (an AppDefaults value wins).
  #
  # wine/source.json pins the fork branch and commit. wine/patches/ are our
  # changes on top, applied in file name order; each patch header says what
  # it fixes. wine/update.sh moves both to a newer fork branch (wine/README.md).
  #
  # COST: no Hydra cache for a fork — a bump means a local ~1h wine build plus
  # a yabridge rebuild. builtins.fetchGit with a full rev is pure-eval-safe
  # and lets nix reuse a previously built source checkout.
  #
  # embedInstallers links the gecko/mono MSIs from nixpkgs-wine's sources.nix
  # (`unstable` set) into share/wine, so wineboot installs them on prefix
  # creation. Wine only picks them up by exact version: they must match
  # WINE_MONO_VERSION (dlls/mscoree/mscoree_private.h) and GECKO_VERSION
  # (dlls/appwiz.cpl/addons.c) of the fork; update.sh warns when a new branch
  # changes them, then bump the nixpkgs-wine input to a nixpkgs that ships them.
  #
  # EXIT STRATEGY: if oeksound ships soothe3 on JUCE >= 8.0.13 (asked via
  # wine-fixes/soothe3-d2d/oeksound-email.md), point `yabridge` back at
  # prev.wineWow64Packages.staging and delete all of this.
  wineSource = prev.lib.importJSON ./wine/source.json;
  winePatches = map (name: ./wine/patches + "/${name}")
    (builtins.sort builtins.lessThan (builtins.attrNames (prev.lib.filterAttrs
      (name: type: type == "regular" && prev.lib.hasSuffix ".patch" name)
      (builtins.readDir ./wine/patches))));
  wine-d2d1-dcomp = (winePkgs.wineWow64Packages.unstable.override {
    embedInstallers = true;
  }).overrideAttrs (old: {
    # "yabridge" in the store path: reaper-rescue finds the DAW's wineservers by it
    pname = "wine-yabridge";
    inherit (wineSource) version;
    src = builtins.fetchGit { inherit (wineSource) url ref rev; };
    patches = (old.patches or [ ]) ++ winePatches;
    # d2d1's shaders, compiled from the HLSL in device.c with the vkd3d
    # version Wine bundles for D3DCompile (see the d2d1 patch).
    postPatch = (old.postPatch or "") + ''
      ${prev.python3.interpreter} ${./wine/d2d1-shader-bytecode.py} \
        ${winePkgs.vkd3d}/bin/vkd3d-compiler dlls/d2d1/device.c > dlls/d2d1/builtin_shaders.h
    '';
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.autoconf prev.perl prev.flex prev.bison ];
    preConfigure = ''
      ./tools/make_requests || true
      ./tools/make_specfiles || true
      autoreconf -f -i || autoconf || true
    '' + (old.preConfigure or "");
    # nixpkgs' wow64 build embeds only the x86_64 gecko, but wineboot's
    # Wow64Install pass registers the 32-bit iexplore.exe too, and that one
    # asks for the x86 MSI.
    postInstall = (old.postInstall or "") + ''
      ln -s ${old.src.gecko32} $out/share/wine/gecko/${old.src.gecko32.name}
    '';
  });
  # yabridge comes from Selim's fork (github.com/selimbucher/yabridge, branch
  # main): samuel-asleep's ARA2 branch (robbert-vdh/yabridge PR #500, upstream
  # master + ARA behind -Dara=true) with our fixes and a few unmerged upstream
  # PRs as commits on top. Upstream doesn't tag releases; bump `rev` to a
  # pushed commit of the fork. ARA needs the headers-only Celemony ARA_API repo
  # (subprojects/ara.wrap) plus the branch's packagefiles/ara override of
  # ARAInterface.h, copied in the same way nixpkgs handles the other wraps.
  ara_api = prev.fetchFromGitHub {
    owner = "Celemony";
    repo = "ARA_API";
    rev = "65ec5c43b943a48cb5446f448a0492db6af8534b"; # from subprojects/ara.wrap
    hash = "sha256-oyKfVUMHB4GVqbZi8YblhgQfrfmVKQJ4LeffON793ns=";
  };
in
{
  wineWow64Packages = prev.wineWow64Packages // {
    # Was prev.wineWow64Packages.staging (11.14, Hydra-cached — see the COST
    # note above for what switching to the fork trades away).
    yabridge = wine-d2d1-dcomp;
  };

  yabridge = prev.yabridge.overrideAttrs (old: {
    version = "5.1.2-selim-20141f5";
    src = prev.fetchFromGitHub {
      owner = "selimbucher";
      repo = "yabridge";
      rev = "20141f508eaca41c1941a9db44070153daeba7f8";
      hash = "sha256-Cjm7ybhLjyud2M2V5B8ee/ZKAQzpscxeUKh2RHyIwss=";
    };
    postUnpack = (old.postUnpack or "") + ''
      cp -R --no-preserve=mode,ownership ${ara_api} "$sourceRoot/subprojects/ara"
    '';
    postPatch = (old.postPatch or "") + ''
      cp subprojects/packagefiles/ara/* subprojects/ara/
    '';
    mesonFlags = (old.mesonFlags or [ ]) ++ [ "-Dara=true" ];
    # Drop libyabridge-drop-32-bit-support.patch (first in the list): the
    # 32-bit handling it patched was reworked on master and bitbridge is
    # disabled anyway.
    patches = prev.lib.drop 1 old.patches;
  });
  yabridgectl = prev.yabridgectl.overrideAttrs (finalAttrs: old: {
    sourceRoot = finalAttrs.src.name;
    buildAndTestSubdir = "tools/yabridgectl";
    # nixpkgs' patches are against tools/yabridgectl with -p3
    patchFlags = [ "-p1" ];
    cargoDeps = final.rustPlatform.fetchCargoVendor {
      inherit (finalAttrs) src sourceRoot;
      name = "${finalAttrs.pname}-${finalAttrs.version}";
      hash = "sha256-WQ90IAyoUEDRf/N3XQPSSwZ/Lrtne1Tk6otFPKpA7Ik=";
    };
  });
}
