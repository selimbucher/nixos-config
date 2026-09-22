# batlog: samples battery drain, SoC power and per-app CPU/GPU time every 30s
# on battery (5 min on AC) into /var/lib/batlog; `batlog report`, `batlog ab`.
{ pkgs, ... }:

let
  batlog = pkgs.writeScriptBin "batlog"
    (builtins.replaceStrings [ "#!/usr/bin/env python3" ] [ "#!${pkgs.python3}/bin/python3" ]
      (builtins.readFile ../../pkgs/batlog/batlog.py));
in
{
  environment.systemPackages = [ batlog ];

  # package C-state residency (how deep the SoC idles) is read from MSRs
  hardware.cpu.x86.msr.enable = true;

  # root: RAPL energy, MSRs and other processes' DRM fdinfo are root-only
  # (Hyprland's too: it runs with capabilities, so even selim can't read it)
  systemd.services.batlog = {
    description = "Battery usage sampler";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${batlog}/bin/batlog sample";
      StateDirectory = "batlog";
      StateDirectoryMode = "0755";
      Nice = 19;
      IOSchedulingClass = "idle";
      TimerSlackNSec = "1s";
      Restart = "on-failure";
      RestartSec = 30;
    };
  };

  powerManagement.powerDownCommands = "${batlog}/bin/batlog mark sleep";
  powerManagement.resumeCommands = "${batlog}/bin/batlog mark wake";
}
