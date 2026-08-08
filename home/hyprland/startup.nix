{ inputs, lib, pkgs, osConfig, ... }:

let
  # Hyprland still has ambient CAP_SYS_NICE while spawning startup entries,
  # and children inherit it. bwrap refuses to run with unexpected ambient
  # capabilities, which breaks Steam's FHS wrapper (and anything launched
  # through kiwi). Drop ambient caps before spawning.
  dropCaps = map (cmd: "setpriv --ambient-caps -all -- ${cmd}");

  luaStr = lib.generators.toLua { };

  # hyprlang exec-once — runs once per compositor launch. Top-level
  # hl.exec_cmd() would be `exec` semantics (re-run on every config parse), so
  # these have to hang off the start event instead. home-manager only emits
  # this hook itself when systemd.enable is true, which it is not (see
  # hyprland.nix), so there is nothing to collide with.
  execOnce = dropCaps ([
    "awww-daemon"
    "xsettingsd"
    "hyprctl setcursor 'Capitaine Cursors - White' 24"
    "wl-clip-persist --clipboard regular"   #
    "play --volume=0.45 ~/.config/kiwi-shell/startup.mp3" #
    "kiwi"
    "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
  ] ++ osConfig.deviceConfig.extraExecOnce);

  # hyprlang exec — re-runs on every config (re)parse
  execEach = dropCaps ([ ] ++ osConfig.deviceConfig.extraExec);
in
{
  wayland.windowManager.hyprland = {
    settings = {

      on = [
        {
          _args = [
            "hyprland.start"
            (lib.generators.mkLuaInline ''
              function()
              ${lib.concatMapStrings (cmd: "  hl.exec_cmd(${luaStr cmd})\n") execOnce}end
            '')
          ];
        }
      ];

      exec_cmd = execEach;

    };
  };
}
