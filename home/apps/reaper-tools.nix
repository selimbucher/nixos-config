{ pkgs, lib, ... }:
let
  src = ../../pkgs/reaper-tools;
  # readFile keeps the scripts as plain, editable shell files; their content is
  # never nix-interpolated. Runtime deps (wineserver-yabridge, pw-jack, reaper)
  # come from PATH and are guaranteed by media.nix.
  reaperRescue = pkgs.writeShellScriptBin "reaper-rescue" (''
    # gdb (host backtraces) and ss (socket peer map) must resolve even under
    # the systemd user service's minimal PATH.
    export PATH=${lib.makeBinPath [ pkgs.gdb pkgs.iproute2 ]}:"$PATH"
  '' + builtins.readFile (src + "/reaper-rescue.sh"));
  reaperCrashwatch = pkgs.writeShellScriptBin "reaper-crashwatch" (''
    # the wedge watchdog invokes reaper-rescue --capture-only
    export PATH=${reaperRescue}/bin:"$PATH"
  '' + builtins.readFile (src + "/reaper-crashwatch.sh"));
  reaperLogged = pkgs.writeShellScriptBin "reaper-logged"
    (builtins.readFile (src + "/reaper-logged.sh"));
  # Runs during home-manager activation, where PATH is minimal.
  reaperAutosaveFix = pkgs.writeShellScriptBin "reaper-autosave-fix" (''
    export PATH=${lib.makeBinPath [ pkgs.gawk pkgs.coreutils pkgs.diffutils ]}:"$PATH"
  '' + builtins.readFile (src + "/reaper-autosave-fix.sh"));
in
{
  home.packages = [
    reaperRescue
    reaperCrashwatch
    reaperLogged
    reaperAutosaveFix
    pkgs.gdb # live backtraces in reaper-rescue + `coredumpctl debug` on stored cores
  ];

  # Auto-collect a diagnostic bundle into ~/reaper-crashlogs/ whenever
  # REAPER, wine or a yabridge host dumps core.
  # Restart=always, not on-failure: systemd counts SIGTERM as a *clean* exit, so
  # on-failure did not restart it. On 2026-08-24 23:56 something TERMed the
  # watcher seconds before REAPER started; it stayed dead all session and the
  # 01:03 freeze went completely uncaptured. A watchdog that can silently stop
  # watching is worse than none.
  systemd.user.services.reaper-crashwatch = {
    Unit.Description = "Auto-collect diagnostics when REAPER, wine or yabridge dumps core";
    Service = {
      ExecStart = "${reaperCrashwatch}/bin/reaper-crashwatch";
      Restart = "always";
      RestartSec = 5;
    };
    Install.WantedBy = [ "default.target" ];
  };

  # Antares plugins (yabridge, ~/.wine-antares) embed a WIBU CodeMeter license
  # client that tries 127.0.0.1:22350 (the CodeMeter Runtime service, which was
  # never successfully installed in the prefix) on EVERY state save and editor
  # open — 3 connection attempts with 2s retry delays = a constant ~6.5s
  # REAPER-UI freeze per save/autosave (diagnosed 2026-08-16 via wine relay +
  # winsock traces). Accepting the TCP connection makes the client's protocol
  # handshake fail instantly and it falls back to its license cache with zero
  # delay — verified: getState went from 6.5s to <1s. Remove this if a real
  # CodeMeter Runtime ever gets installed into the prefix.
  systemd.user.services.codemeter-stub = {
    Unit.Description = "CodeMeter port decoy: fast-fail Antares license pings";
    Service = {
      ExecStart = "${pkgs.socat}/bin/socat TCP-LISTEN:22350,bind=127.0.0.1,fork,reuseaddr /dev/null";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "default.target" ];
  };

  # reaper.ini must stay writable (REAPER rewrites it on every clean exit), so
  # autosave settings are converged on each activation instead of via a
  # read-only home.file. Skips silently while REAPER is running.
  home.activation.reaperAutosaveFix = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${reaperAutosaveFix}/bin/reaper-autosave-fix
  '';
}
