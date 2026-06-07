{ inputs, pkgs, osConfig, ... }:

{
  wayland.windowManager.hyprland = {
    settings = {

      exec-once = [
        "awww-daemon"
        "xsettingsd"
        "hyprctl setcursor 'Capitaine Cursors - White' 24"
        "wl-clip-persist --clipboard regular"   #
        "play --volume=0.45 ~/.config/kiwi-shell/startup.mp3" #
        "kiwi"
        "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
      ] ++ osConfig.deviceConfig.extraExecOnce;

      exec = [] ++ osConfig.deviceConfig.extraExec;
      
    };
  };
}
