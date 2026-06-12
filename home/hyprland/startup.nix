{ inputs, pkgs, osConfig, ... }:

let
  # Hyprland still has ambient CAP_SYS_NICE while spawning startup entries,
  # and children inherit it. bwrap refuses to run with unexpected ambient
  # capabilities, which breaks Steam's FHS wrapper (and anything launched
  # through kiwi). Drop ambient caps before spawning.
  dropCaps = map (cmd: "setpriv --ambient-caps -all -- ${cmd}");
in
{
  wayland.windowManager.hyprland = {
    settings = {

      exec-once = dropCaps ([
        "awww-daemon"
        "xsettingsd"
        "hyprctl setcursor 'Capitaine Cursors - White' 24"
        "wl-clip-persist --clipboard regular"   #
        "play --volume=0.45 ~/.config/kiwi-shell/startup.mp3" #
        "kiwi"
        "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
      ] ++ osConfig.deviceConfig.extraExecOnce);

      exec = dropCaps ([] ++ osConfig.deviceConfig.extraExec);
      
    };
  };
}
