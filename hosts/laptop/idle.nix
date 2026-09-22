# Idle timeouts, on battery only: dim at 2 min, screen off at 4, suspend at 15.
# Idle inhibitors (video playback, `systemd-inhibit --what=idle <cmd>`) hold
# them off. On AC nothing happens, as before.
{ pkgs, ... }:

let
  brightnessctl = "${pkgs.brightnessctl}/bin/brightnessctl";
  onBattery = ''[ "$(cat /sys/class/power_supply/BAT0/status)" = Discharging ]'';

  # to a third of the current level, remembered for `idle-dim restore`
  idleDim = pkgs.writeShellScript "idle-dim" ''
    state="$XDG_RUNTIME_DIR/idle-dim"
    if [ "''${1:-}" = restore ]; then
      [ -f "$state" ] && ${brightnessctl} -q set "$(cat "$state")" && rm -f "$state"
      exit 0
    fi
    ${onBattery} || exit 0
    cur=$(${brightnessctl} get)
    echo "$cur" > "$state"
    ${brightnessctl} -q set $(( cur > 3 ? cur / 3 : 1 ))
  '';

  # "on"/"off" only: any other action string makes hl.dsp.dpms toggle
  idleScreen = pkgs.writeShellScript "idle-screen" ''
    if [ "$1" = off ]; then ${onBattery} || exit 0; fi
    hyprctl eval "hl.dispatch(hl.dsp.dpms({ action = \"$1\" }))"
  '';

  idleSuspend = pkgs.writeShellScript "idle-suspend" ''
    ${onBattery} && systemctl suspend
  '';
in
{
  environment.systemPackages = [ pkgs.hypridle ];

  # started by Hyprland like the other session daemons: this session never
  # reaches graphical-session.target, which home-manager's unit waits for
  deviceConfig.extraExecOnce = [ "hypridle" ];

  # scripts, not inline commands: hyprlang would read $ and # in them
  home-manager.users.selim.xdg.configFile."hypr/hypridle.conf".text = ''
    general {
      after_sleep_cmd = ${idleScreen} on
    }

    listener {
      timeout = 120
      on-timeout = ${idleDim}
      on-resume = ${idleDim} restore
    }

    listener {
      timeout = 240
      on-timeout = ${idleScreen} off
      on-resume = ${idleScreen} on
    }

    listener {
      timeout = 900
      on-timeout = ${idleSuspend}
    }
  '';
}
