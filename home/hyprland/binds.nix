{ inputs, lib, pkgs, osConfig, ... }:

let
  inherit (lib.generators) mkLuaInline;

  mainMod = "SUPER";

  # hl.bind(<keys>, <dispatcher>[, <opts>]).
  # `keys` is a plain string (rendered as a lua string literal), `dispatcher`
  # is raw lua — a call into hl.dsp.* that returns an HL.Dispatcher.
  bind = keys: dispatcher: { _args = [ keys (mkLuaInline dispatcher) ]; };
  bindOpts = opts: keys: dispatcher: { _args = [ keys (mkLuaInline dispatcher) opts ]; };

  # hyprlang bind flag suffixes, as hl.bind option tables
  locked = bindOpts { locked = true; };                     # bindl
  lockedRepeat = bindOpts { locked = true; repeating = true; }; # bindel
  mouse = bindOpts { mouse = true; };                       # bindm

  exec = cmd: "hl.dsp.exec_cmd(${cmd})";
  # shell command as a lua literal; `var` forms reference the locals declared
  # in hyprland.nix (terminal, editor, ...)
  sh = cmd: exec (builtins.toJSON cmd);
  var = name: exec name;

  # SUPER+1..0 -> workspace 1..10, SUPER+SHIFT+1..0 -> move window there
  workspaceBinds = lib.concatMap (i:
    let
      key = toString (lib.mod i 10); # 10 lives on the 0 key
      ws = toString i;
    in [
      (bind "${mainMod} + ${key}" ''hl.dsp.focus({ workspace = "${ws}" })'')
      (bind "${mainMod} + SHIFT + ${key}" ''hl.dsp.window.move({ workspace = "${ws}" })'')
    ]) (lib.range 1 10);
in
{
  # Unlike hyprlang there is no bind/bindl/bindel/bindm split — every bind is
  # hl.bind() and the flags move into the trailing options table.
  wayland.windowManager.hyprland.settings.bind = [
    (bind "CTRL + F12" (sh "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"))
    (bind "${mainMod} + mouse_down" ''hl.dsp.focus({ workspace = "e-1" })'')
    (bind "${mainMod} + mouse_up" ''hl.dsp.focus({ workspace = "e+1" })'')

    (bind "SUPER + period" (sh "smile"))

    (bind "Print" (sh ''grim -g "$(slurp)" - | wl-copy''))
    (bind "CTRL + Print" (sh "grim - | wl-copy"))
    (bind "${mainMod} + Q" (var "terminal"))
    (bind "${mainMod} + SHIFT + Q" (var "fetchTerminal"))
    (bind "${mainMod} + C" "hl.dsp.window.close()")
    (bind "${mainMod} + E" (var "fileManager"))
    (bind "${mainMod} + I" (sh "kiwi-settings"))
    (bind "${mainMod} + H" ''hl.dsp.exec_cmd(editor .. " ~/.nixos")'')
    (bind "${mainMod} + A" ''hl.dsp.window.float({ action = "toggle" })'')
    (bind "${mainMod} + P" "hl.dsp.window.pseudo()")
    (bind "${mainMod} + K" (sh "kiwictl quit; kiwi"))
    (bind "${mainMod} + W" (var "webBrowser"))
    (bind "CTRL + SHIFT + Escape" (var "taskManager"))
    (bind "${mainMod} + L" (var "lock"))
    (bind "${mainMod} + X" (sh "hyprpicker -a"))
    (bind "${mainMod} + SHIFT + X" (sh "hyprpicker -a -f hsl"))

    (bind "${mainMod} + SHIFT + P" (sh "poweroff"))
    (bind "${mainMod} + SHIFT + R" (sh "reboot"))
    (bind "${mainMod} + SHIFT + E" "hl.dsp.exit()")
    (bind "${mainMod} + F" ''hl.dsp.window.fullscreen({ mode = "fullscreen" })'')

    (bind "${mainMod} + left" ''hl.dsp.focus({ direction = "left" })'')
    (bind "${mainMod} + right" ''hl.dsp.focus({ direction = "right" })'')
    (bind "${mainMod} + up" ''hl.dsp.focus({ direction = "up" })'')
    (bind "${mainMod} + down" ''hl.dsp.focus({ direction = "down" })'')
  ]
  ++ workspaceBinds
  ++ [
    (bind "${mainMod} + S" ''hl.dsp.workspace.toggle_special("magic")'')
    (bind "${mainMod} + SHIFT + S" ''hl.dsp.window.move({ workspace = "special:magic" })'')

    # bindel — volume/brightness, held down, works on the lock screen
    (lockedRepeat "XF86AudioRaiseVolume" (sh "wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 && wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"))
    (lockedRepeat "XF86AudioLowerVolume" (sh "wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 && wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"))
    (lockedRepeat "XF86AudioMute" (sh "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
    (lockedRepeat "XF86AudioMicMute" (sh "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"))
    (lockedRepeat "XF86MonBrightnessUp" (sh "brightnessctl -e4 -n10 set 4%+"))
    (lockedRepeat "XF86MonBrightnessDown" (sh "brightnessctl -e4 -n10 set 4%-"))

    # bindl — media keys, work on the lock screen
    (locked "XF86AudioNext" (sh "playerctl next"))
    (locked "XF86AudioPause" (sh "playerctl play-pause"))
    (locked "XF86AudioPlay" (sh "playerctl play-pause"))
    (locked "XF86AudioPrev" (sh "playerctl previous"))

    # bindm — drag to move / resize
    (mouse "${mainMod} + mouse:272" "hl.dsp.window.drag()")
    (mouse "${mainMod} + mouse:273" "hl.dsp.window.resize()")
  ];
}
