{ pkgs, lib, ... }:
let
  src = ../../pkgs/reaper-tools;
  # readFile keeps the scripts as plain, editable shell files; their content is
  # never nix-interpolated. Runtime deps (wineserver-yabridge, pw-jack, reaper)
  # come from PATH and are guaranteed by media.nix.
  reaperRescue = pkgs.writeShellScriptBin "reaper-rescue"
    (builtins.readFile (src + "/reaper-rescue.sh"));
  reaperCrashwatch = pkgs.writeShellScriptBin "reaper-crashwatch"
    (builtins.readFile (src + "/reaper-crashwatch.sh"));
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
  systemd.user.services.reaper-crashwatch = {
    Unit.Description = "Auto-collect diagnostics when REAPER, wine or yabridge dumps core";
    Service = {
      ExecStart = "${reaperCrashwatch}/bin/reaper-crashwatch";
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
