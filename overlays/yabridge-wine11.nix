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
    # note above for what switching to the fork trades away).
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
      # 2026-09-10: the poke is a one-shot 10 ms timer, not a posted message.
      # Posted messages outrank WM_PAINT/WM_TIMER, and Melodyne's audio
      # threads submit a task per block (~1500/s), so during playback its
      # editor never got a paint or timer message and looked frozen.
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
      # yabridge-ara-head-tail-any-thread.patch (ours, 2026-09-10): the fork
      # runs every ARA document-controller call REAPER makes on the plugin's
      # GUI thread. ARA exempts getPlaybackRegionHeadAndTailTime(), "callable
      # from any audio rendering thread", and REAPER asks it once per block
      # per item from its render threads. Hopping those onto the GUI thread
      # tied the audio path to that thread (the 09-08 wedge: media thread
      # parked on it while Melodyne sat in a popup loop) and flooded it with
      # work (the 09-10 frozen editor). Answer it on the receiving thread.
      ./patches/yabridge-ara-head-tail-any-thread.patch
      # yabridge-pid-running-deleted-exe.patch (ours, 2026-10-03): the Wine
      # hosts' watchdog asks pid_running(REAPER) every 5s, implemented as
      # fs::canonical("/proc/<pid>/exe"). nix-optimise.service replaced
      # REAPER's binary with a hard link mid-session (19:11:33), the link
      # became ".reaper-wrapped (deleted)", canonical() failed, and every
      # host declared REAPER dead and exited ("The native plugin host seems
      # to have died" x3 while REAPER was alive: Addictive Drums 2, Lounge
      # Lizard EP-4, Kontakt 8). Read the link instead of resolving it: still
      # fails for zombies, succeeds for a live process with a replaced exe.
      # Candidate for upstreaming.
      ./patches/yabridge-pid-running-deleted-exe.patch
      # yabridge-bounded-host-terminate.patch (ours, 2026-10-18): unloading a
      # plugin closes the host's sockets, sends it SIGINT and then waitpid()s
      # with no timeout. Wine turns the SIGINT into a Ctrl-C event whose
      # default handler kills all other threads and then runs every
      # DLL_PROCESS_DETACH; Guitar Rig 7 sleeps in its detach waiting for one
      # of its (now dead) threads, so the host never exits, the unloading
      # thread blocks forever, and the host lingers with its memory (the
      # leaked Kontakt 8 host found hours after REAPER quit). Reproduced in
      # 2 of 3 Guitar Rig unloads. SIGKILL after 2s; clean exits take <0.1s.
      ./patches/yabridge-bounded-host-terminate.patch
      # yabridge-process-bus-bounds.patch (ours, 2026-10-18): REAPER crashed
      # (SIGSEGV in YaProcessData::repopulate) after Lounge Lizard EP-4's host
      # died: the host death was caught in a non-process call, so process()
      # kept running, and REAPER passed 4 input busses where the shared
      # buffers knew of none, so num_input_channels() indexed past the end.
      # process() now also stops on the bridge-wide lost-host flag, a bus
      # without offsets counts as zero channels, and CLAP copies only the
      # clamped channel count (it copied the host's count, which overruns
      # when a host passes more channels than the plugin has).
      ./patches/yabridge-process-bus-bounds.patch
      # yabridge-ara-host-refs-before-send.patch (ours, 2026-10-23): the
      # document-controller proxy recorded an audio source's (region
      # sequence's, modification's, playback region's) host ref only after
      # the Add* message returned, but Auto-Tune Pro 10.3.1 creates its ARA
      # audio reader synchronously inside createAudioSource(). The host-side
      # CreateAudioReader handler then found no source, answered reader 0,
      # and every readAudioSamples(reader=0) failed: the plugin's analysis
      # thread zero-filled and retried forever (one core at 100%, no audio
      # from any playback renderer), its editor thread sat in a Sleep(50)
      # loop waiting for that analysis, and REAPER's main thread wedged in
      # notifyModelUpdates behind it (2026-09-27 23:41 and 2026-10-23 20:10
      # wedges, 19:28 host crash). Record the refs before sending.
      ./patches/yabridge-ara-host-refs-before-send.patch
      # yabridge-ara-chunked-audio-reads.patch (ours, 2026-10-23): the Wine
      # side clamped readAudioSamples() to the 65536-frame shared buffer and
      # still returned true, so a plugin reading larger blocks (Auto-Tune
      # reads 173600 frames at once) got the first 65536 frames and stale
      # memory for the rest. Transfer big reads in several round trips.
      ./patches/yabridge-ara-chunked-audio-reads.patch
    ];
  });
}
