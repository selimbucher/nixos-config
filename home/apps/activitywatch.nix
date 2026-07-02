{ pkgs, inputs, ... }:
let
  # From stable: unstable's activitywatch/aw-webui is broken & uncached (see flake).
  stable = inputs.nixpkgs-stable.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  home.packages = [ stable.activitywatch stable.awatcher ];

  # Local data store (REST API on :5600).
  systemd.user.services.aw-server = {
    Unit.Description = "ActivityWatch server";
    Service.ExecStart = "${stable.activitywatch}/bin/aw-server";
    Install.WantedBy = [ "default.target" ];
  };

  # Window + AFK watcher with Wayland/Hyprland support (replaces the X11 watchers).
  systemd.user.services.awatcher = {
    Unit = {
      Description = "ActivityWatch awatcher (Wayland window + AFK)";
      After = [ "aw-server.service" ];
    };
    Service.ExecStart = "${stable.awatcher}/bin/awatcher";
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # Push today's usage to the life-system box every 30 min.
  # Token in ~/.config/life-system/ingest-token (600); script in the life-system repo.
  systemd.user.services.life-aw-export = {
    Unit = { Description = "Export ActivityWatch to life-system"; After = [ "aw-server.service" ]; };
    Service = {
      Type = "oneshot";
      Environment = [ "LIFE_INGEST_SECRET=%h/.config/life-system/ingest-token" ];
      ExecStart = "${pkgs.python3}/bin/python3 %h/life-system/runtime/activitywatch_export.py";
    };
  };
  systemd.user.timers.life-aw-export = {
    Unit.Description = "Periodic ActivityWatch export";
    Timer = { OnBootSec = "5m"; OnUnitActiveSec = "30m"; Persistent = true; };
    Install.WantedBy = [ "timers.target" ];
  };
}
