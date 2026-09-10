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
final: prev:
let
  # giang17's d2d1-dcomp Wine fork (wine 11.16 based, NOT staging): implements
  # the D2D 1.3 + DirectComposition path that JUCE 8.0.x plugin editors
  # hardwire (pre-8.0.13 JUCE has no software fallback at all). Without it,
  # soothe3's editor is black and kills the host; with it plus the two patches
  # below, the full UI renders and is interactive (verified 2026-08-30,
  # pluginval strictness 10 all green + REAPER; see Obsidian "VST Plugins on
  # Wine.md" § soothe3 and ~/.local/share/wine-fixes/soothe3-d2d/).
  #
  # - dcomp-wndproc-loop-guard.patch (ours, offered upstream): the fork's
  #   dcomp.dll/dxgi.dll subclass the editor HWND alongside JUCE and PACE;
  #   the saved wndprocs are user32 winproc handles so identity checks can't
  #   see a cycle, the chain can close into a ring, and one forwarded message
  #   then recurses until the 1MB thread stack overflows. The patch caps
  #   same-window forward nesting at 32.
  # - hide-wine-exports.patch: hides wine_get_version and friends (the fork is
  #   not staging-based, so the Staging HideWineExports registry key from the
  #   Antares note doesn't exist here). Side effect on JUCE >= 8.0.13 plugins:
  #   they can't detect Wine, take the full D2D path instead of the degraded
  #   GDI fallback — which is exactly what this fork wants (it ships the same
  #   default via wine.inf HideWineVersion on newer branch tips).
  #
  # COST: no Hydra cache for a fork — bumping `rev` means a local ~1h wine
  # build plus a yabridge rebuild. The fork rebases onto wine dev releases
  # roughly biweekly; only bump when something needs it. builtins.fetchGit
  # with a full rev is pure-eval-safe and lets nix reuse a previously built
  # source checkout.
  #
  # NOTE: home/packages/media.nix derives gecko/mono MSI versions from this
  # nixpkgs' wine sources.nix (11.14-era) while the fork is 11.16 — close
  # enough in practice; if a prefix ever nags about wrong gecko/mono, that
  # version skew is why.
  #
  # EXIT STRATEGY: if oeksound ships soothe3 on JUCE >= 8.0.13 (asked via
  # wine-fixes/soothe3-d2d/oeksound-email.md), point `yabridge` back at
  # prev.wineWow64Packages.staging and delete all of this.
  wine-d2d1-dcomp = prev.wineWow64Packages.unstable.overrideAttrs (old: {
    pname = "wine-wow64-d2d1-dcomp-hwe-1116-loopguard";
    src = builtins.fetchGit {
      url = "https://github.com/giang17/wine";
      rev = "19062635e50d84edef523f912c397119c2691630";
      ref = "d2d1-dcomp-11.16";
    };
    patches = (old.patches or [ ]) ++ [
      ./patches/hide-wine-exports.patch
      ./patches/dcomp-wndproc-loop-guard.patch
      # wineserver-batch-mutex-abandon.patch (ours, 2026-09-01): with ntsync,
      # wineserver brute-forces NTSYNC_IOC_MUTEX_KILL on EVERY live mutex for
      # EVERY thread exit (abandon_inproc_mutexes). Omnisphere joins ~7000
      # short-lived threads per patch load against ~3000+ mutexes -> ~34s of
      # pegged wineserver = the frozen-REAPER preset loads. Batch dead tids
      # (max 128, safe: ptid reuse needs 256 frees) and flush with one
      # read-owner pass every 250ms. Diagnosis: omni-preset-freeze memory +
      # scratchpad/omni-probe. Candidate for upstream (novel, unfiled).
      ./patches/wineserver-batch-mutex-abandon.patch
    ];
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.autoconf prev.perl prev.flex prev.bison ];
    preConfigure = ''
      ./tools/make_requests || true
      ./tools/make_specfiles || true
      autoreconf -f -i || autoconf || true
    '' + (old.preConfigure or "");
  });
  # ARA2 support (2026-09-05): robbert-vdh/yabridge PR #500 (samuel-asleep:
  # ara2-support, sponsored/tested by NlGHT). Unmerged and unreviewed upstream
  # as of 2026-09-05, but testers confirm Melodyne through REAPER on Wine 11
  # with comping/fixed lanes/audio all working, plus Auto-Align 2 on NixOS.
  # The branch is upstream master b580a9f (our previous pin) + ~12.7k lines of
  # ARA bridging behind meson -Dara=true, so everything else is unchanged.
  # ARA needs the headers-only Celemony ARA_API repo (subprojects/ara.wrap,
  # pinned rev below) plus the branch's packagefiles/ara override of
  # ARAInterface.h, copied in the same way nixpkgs handles the other wraps.
  # Wine-side ARA callbacks are compiled with ARA_CALL=ms_abi (see the branch's
  # meson.build) — that's why this can't be done as a runtime-only shim.
  # ROLLBACK: useAra = false restores the upstream-master pin (rebuild only,
  # no prefix/state changes; ARA state saved in projects is simply ignored).
  useAra = true;
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
    # note above for what switching to the fork trades away). The gecko/mono
    # note from the staging era still applies: they are installed per-prefix
    # via wine-install-addons in home/packages/media.nix, not embedded.
    yabridge = wine-d2d1-dcomp;
  };

  yabridge = prev.yabridge.overrideAttrs (old: {
    version = if useAra then "5.1.2-alpha-ara-a38234b" else "5.1.2-alpha-b580a9f";
    src = if useAra then prev.fetchFromGitHub {
      owner = "samuel-asleep";
      repo = "yabridge";
      rev = "a38234ba3817aaa0a3a9cc46c3cd54b4a350a85d"; # ara2-support, 2026-08-28 (PR #500 head)
      hash = "sha256-19otZmQXMvgfwMnwZPXJYr27bSkWobqS7ZD+PfOM7i0=";
    } else prev.fetchFromGitHub {
      owner = "robbert-vdh";
      repo = "yabridge";
      rev = "b580a9f7fc46509767ca156d4f92872552b9e571"; # master, 2026-08-02
      hash = "sha256-TiKiyE3GZYCX1+vooHdD03fAhNQPAA1IzTfkG++I7TY=";
    };
    postUnpack = (old.postUnpack or "") + prev.lib.optionalString useAra ''
      cp -R --no-preserve=mode,ownership ${ara_api} "$sourceRoot/subprojects/ara"
    '';
    postPatch = (old.postPatch or "") + prev.lib.optionalString useAra ''
      cp subprojects/packagefiles/ara/* subprojects/ara/
    '';
    mesonFlags = (old.mesonFlags or [ ]) ++ prev.lib.optional useAra "-Dara=true";
    # Drop libyabridge-drop-32-bit-support.patch (first in the list): the
    # 32-bit handling it patched was reworked on master and bitbridge is
    # disabled anyway — same recipe as the NixOS report in yabridge#409.
    # yabridge-survive-hostdeath.patch (ours, 2026-09-01): when a Wine plugin
    # host dies mid-process() (e.g. soothe3's PACE fail-fast, c0000409), the
    # asio socket read throws, nothing catches it, and std::terminate kills
    # ALL of REAPER (core-dump verified: asio::read -> __cxa_throw ->
    # terminate inside Vst3PluginProxyImpl::process). The patch catches the
    # exception in the VST3 + CLAP audio paths and mutes just that plugin.
    # Candidate for upstreaming to robbert-vdh/yabridge with the backtrace.
    # yabridge-pooled-mutual-recursion.patch (ours, 2026-09-01): fork() in
    # MutualRecursionHelper spawned a fresh Wine thread + io_context for EVERY
    # mutually recursive call (performEdit = one per parameter). Omnisphere
    # makes thousands of those per preset load; each Wine thread lifecycle
    # costs ~0.7ms serialized through wineserver even after the
    # wineserver-batch-mutex-abandon.patch. Reuse a small pool of sending
    # threads instead. Candidate for upstreaming alongside survive-hostdeath.
    # yabridge-clap-mutual-recursion-state.patch (ours, 2026-09-04): the CLAP
    # bridge ran plugin::Activate/Deactivate and state::Save/Load through
    # main_context_.run_in_context() directly. When the Wine main thread is
    # parked inside send_mutually_recursive_main_thread_message() (e.g.
    # FabFilter Pro-L 2 firing clap_host_latency.changed() from a GUI click on
    # its oversampling menu), the main context's event loop is not running, so
    # those requests never execute; REAPER's main thread is meanwhile blocked
    # in ext_state_save (undo capture) -> three-way deadlock ring, REAPER
    # frozen. The VST3 bridge already routes SetState/GetState through
    # do_mutual_recursion_on_gui_thread() for exactly this reason ("in case
    # this happens during a resize"); this patch gives the four CLAP handlers
    # the same treatment. Root-caused live via headless Xvfb REAPER probe +
    # xdotool GUI clicks + eu-stack of the frozen pair (fab-probe harness).
    # Candidate for upstreaming.
    # survive-hostdeath has an -ara variant: identical hunks, re-contexted
    # against the ARA branch's extra includes in vst3-impls/plugin-proxy.*.
    patches = (prev.lib.drop 1 old.patches) ++ [
      (if useAra then ./patches/yabridge-survive-hostdeath-ara.patch
                 else ./patches/yabridge-survive-hostdeath.patch)
      ./patches/yabridge-pooled-mutual-recursion.patch
      ./patches/yabridge-clap-mutual-recursion-state.patch
      # yabridge-clap-async-void-notifications.patch (ours, 2026-09-04): the
      # other half of the same deadlock. The recursion-state patch only covers
      # requests arriving WHILE the Wine main thread is already parked in a
      # mutually recursive send; when REAPER's Save was queued to the main
      # context BEFORE the plugin's GUI click fired latency.changed(), the
      # main context loop never resumes and the ring re-forms (reproduced:
      # patched host still wedged on click cycle 1). Void host notifications
      # (latency.changed, params.rescan, mark_dirty, ...) don't need their
      # callback to have RUN before we Ack - schedule on the host's main
      # thread without blocking and Ack immediately, like a native async
      # host. Kills the whole ring class on the plugin side.
      ./patches/yabridge-clap-async-void-notifications.patch
      # yabridge-mute-not-takedown.patch (ours, 2026-09-06): generalises
      # survive-hostdeath from process() to EVERY plugin-side call. The 4
      # REAPER core dumps of 2026-09-06 00:11-00:25 were all "Wine host died
      # (another session ran wineserver -k on ~/.wine-ni) -> uncaught
      # std::system_error in setParamNormalized / setChannelContextInfos /
      # Construct -> std::terminate". Now the first failed socket op marks the
      # bridge dead, logs once, and every later call returns kInternalError /
      # a default response; VST2 outputs silence. Also replaces the
      # std::terminate() in the startup watchdog (host exits before the
      # sockets connect, e.g. wineserver protocol mismatch) with aborting the
      # blocking accept, so the module init fails instead of REAPER.
      ./patches/yabridge-mute-not-takedown.patch
      # yabridge-ara-mutual-recursion.patch (ours, 2026-09-06): REAPER froze
      # (main thread parked in AraDocumentControllerProxy::notify_model_updates
      # waiting for Melodyne's Ack, Melodyne waiting for REAPER's model-update
      # callbacks, which yabridge ran on its host-callbacks thread). ARA
      # requires those callbacks synchronously on the calling thread, so the
      # notifyModelUpdates / begin+endEditing / archive store+restore calls
      # now go through send_mutually_recursive_message() and the VST3 host
      # callback dispatcher runs callbacks on the blocked caller when one is
      # waiting. Wine side: the ARA host-callback proxies send mutually
      # recursively too and dc_call() uses do_mutual_recursion_on_gui_thread,
      # so nested REAPER->plugin requests are served while Melodyne sits in a
      # callback (the same ring, seen from Wine). Candidate for PR #500.
      ./patches/yabridge-ara-mutual-recursion.patch
      # yabridge-main-context-nested-loops.patch (ours, 2026-09-08): REAPER
      # froze with its main thread in ARA notifyModelUpdates while Melodyne's
      # Wine GUI thread sat in its own popup/drag tracking loop (SetCapture +
      # PeekMessage + DispatchMessage + Sleep(1), ~22 levels deep). yabridge
      # only executes host->plugin GUI-thread work (run_in_context) from its
      # own asio loop, which a plugin-owned nested Win32 loop never returns
      # to, so every such request starves for as long as the popup/dialog is
      # open. Natively the host's main thread IS that thread and its work is
      # message driven, so it keeps running inside nested loops. The patch
      # adds a message-only window to MainContext; run_in_context/schedule_task
      # post a WM_APP message to it and its wndproc polls the context, so any
      # dispatching loop also runs our queued tasks. Candidate for upstream.
      ./patches/yabridge-main-context-nested-loops.patch
      # yabridge-ara-factory-slot-sharing.patch (ours, 2026-09-10): the fork
      # gives every ARA factory object a createDocumentController trampoline
      # from a static pool of 8, but keys its registry by factoryID: each new
      # Melodyne instance took a fresh slot and overwrote the same entry, so
      # the older slots stayed marked used with nothing behind them and only
      # the newest was ever freed. Twelve Melodyne tracks exhausted the pool
      # ("ARA factory trampoline pool exhausted" in REAPER's log), the factory
      # REAPER got was a stub, and REAPER then created a new ARA document per
      # FX-window open: the editor drew its grid with no notes in it. Now one
      # slot per factoryID, shared by all live factory objects (counted, freed
      # when the last goes), 32 slots, and getFactory() called twice on an
      # instance unregisters the old factory first. Candidate for upstream.
      ./patches/yabridge-ara-factory-slot-sharing.patch
    ];
  });
}
