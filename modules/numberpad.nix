# NumberPad: the LED digit grid in the touchpad of ASUS Zenbooks. The pad's
# firmware only draws it; on Windows the ASUS driver lights it over I2C and
# turns touches into digits itself, and the kernel knows nothing of either.
# asus-numberpad-driver is the userspace port of that: hidraw/I2C for the
# backlight, an evdev grab of the touchpad and uinput for the keys. Our
# ASUE140D 04F3:31B9 is the maintainer's own pad, so the up5401ea layout is
# measured on exactly this hardware.
#
# On demand, never resident: the daemon has three threads that wake every
# 0.5-1 s (numlock LED, inactivity, touchpad state), which is fine for the
# minutes the numpad is lit and not fine 24/7 on battery. So the unit is not
# wanted by the session; SUPER+N starts it (numpad lit) or stops it (numpad
# off), and when the driver itself turns the numpad off (top-right corner,
# or 2 min without a touch) a path unit sees it write enabled = 0 to its
# config and stops the daemon too. Nothing runs while the numpad is dark.
#
# Tapping the top-left corner sends XF86Calculator, bound to gnome-calculator.
{ config, lib, pkgs, inputs, ... }:

let
  conf = "/home/selim/.config/asus-numberpad-driver/numberpad_dev";

  # the driver persists its last state in `enabled`, so set it before each
  # start: the numpad lights up with the daemon instead of waiting for a
  # corner press. `enabled *=`: the module's first-run file has no spaces,
  # the driver's rewrites do.
  toggle = pkgs.writeShellScriptBin "numberpad" ''
    if systemctl --user is-active -q asus-numberpad-driver \
        && grep -q '^enabled *= *1' ${conf} 2>/dev/null; then
      systemctl --user stop asus-numberpad-driver
    else
      [ -f ${conf} ] && sed -i 's/^enabled *=.*/enabled = 1/' ${conf}
      systemctl --user reset-failed asus-numberpad-driver 2>/dev/null
      systemctl --user start asus-numberpad-driver
    fi
  '';

  inherit (lib.generators) mkLuaInline;
  bind = keys: cmd: { _args = [ keys (mkLuaInline "hl.dsp.exec_cmd(${builtins.toJSON cmd})") ]; };
in
lib.mkIf config.deviceConfig.numberpad {
  nixpkgs.overlays = [ inputs.asus-numberpad-driver.overlays.default ];

  hardware.asus-numberpad-driver = {
    enable = true;
    layout = "up5401ea";
    wayland = true;
    waylandDisplay = "wayland-1";
    # written once, on first start; the driver rewrites it afterwards
    defaultConfig.main = {
      enabled = 1;
      # 0 = grab the whole pad while lit: digits only, no pointer. The default
      # (3) keeps the pointer and tries to switch tap-to-click off through
      # gsettings/xinput, neither of which reaches Hyprland.
      enabled_touchpad_pointer = 0;
      # the xinput poll behind this never works on Wayland anyway
      touchpad_disables_numpad = 0;
    };
  };
  # i2c, input, uinput: the groups the driver needs on the device nodes
  users.users.selim.extraGroups = [ "i2c" "input" "uinput" ];

  environment.systemPackages = [ toggle ];

  systemd.user.services.asus-numberpad-driver = {
    wantedBy = lib.mkForce [ ];
    # on demand: a failed start is reported, not retried five times a second,
    # and its traceback goes to the journal instead of /dev/null
    serviceConfig.Restart = lib.mkForce "no";
    serviceConfig.StandardError = lib.mkForce "journal";
  };

  # inotify on the driver's config: it writes enabled = 0 when it turns the
  # numpad off, and the daemon has nothing left to do then
  systemd.user.paths.numberpad-off = {
    wantedBy = [ "default.target" ];
    pathConfig.PathChanged = conf;
  };
  systemd.user.services.numberpad-off = {
    serviceConfig.Type = "oneshot";
    script = ''
      if systemctl --user is-active -q asus-numberpad-driver \
          && grep -q '^enabled *= *0' ${conf}; then
        systemctl --user stop asus-numberpad-driver
      fi
    '';
  };

  home-manager.users.selim.wayland.windowManager.hyprland.settings.bind = [
    (bind "SUPER + N" "numberpad")
    (bind "XF86Calculator" "gnome-calculator")
  ];
}
