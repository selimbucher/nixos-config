{ inputs, pkgs, osConfig, ... }:

{
  wayland.windowManager.hyprland.settings = {    

    bind = [
    "CTRL, F12, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
    "$mainMod, mouse_down, workspace, e-1"
    "$mainMod, mouse_up, workspace, e+1"

    "SUPER, period, exec, smile"
    #", section, togglespecialworkspace, magic"
    #"SHIFT, section, movetoworkspace, special:magic"

    ", Print, exec, grim -g \"$(slurp)\" - | wl-copy"
    "CTRL, Print, exec, grim - | wl-copy"
    "$mainMod, Q, exec, $terminal"
    "$mainMod SHIFT, Q, exec, $fetchTerminal"
    "$mainMod, C, killactive,"
    "$mainMod, E, exec, $fileManager"
    "$mainMod, I, exec, kiwi-settings"
    "$mainMod, H, exec, $editor ~/.nixos"
    "$mainMod, A, togglefloating,"
    "$mainMod, P, pseudo,"
    "$mainMod, K, exec, kiwictl quit; kiwi"
    "$mainMod, W, exec, $webBrowser"
    "CTRL SHIFT, Escape, exec, $taskManager"
    "$mainMod, L, exec, $lock"
    "$mainMod, X, exec, hyprpicker -a"
    "$mainMod SHIFT, X, exec, hyprpicker -a -f hsl"

    "$mainMod SHIFT, P, exec, poweroff"
    "$mainMod SHIFT, R, exec, reboot"
    "$mainMod SHIFT, E, exit,"
    "$mainMod, F, fullscreen, 0"
    "$mainMod, left, movefocus, l"
    "$mainMod, right, movefocus, r"
    "$mainMod, up, movefocus, u"
    "$mainMod, down, movefocus, d"
    "$mainMod, 1, workspace, 1"
    "$mainMod, 2, workspace, 2"
    "$mainMod, 3, workspace, 3"
    "$mainMod, 4, workspace, 4"
    "$mainMod, 5, workspace, 5"
    "$mainMod, 6, workspace, 6"
    "$mainMod, 7, workspace, 7"
    "$mainMod, 8, workspace, 8"
    "$mainMod, 9, workspace, 9"
    "$mainMod, 0, workspace, 10"
    "$mainMod SHIFT, 1, movetoworkspace, 1"
    "$mainMod SHIFT, 2, movetoworkspace, 2"
    "$mainMod SHIFT, 3, movetoworkspace, 3"
    "$mainMod SHIFT, 4, movetoworkspace, 4"
    "$mainMod SHIFT, 5, movetoworkspace, 5"
    "$mainMod SHIFT, 6, movetoworkspace, 6"
    "$mainMod SHIFT, 7, movetoworkspace, 7"
    "$mainMod SHIFT, 8, movetoworkspace, 8"
    "$mainMod SHIFT, 9, movetoworkspace, 9"
    "$mainMod SHIFT, 0, movetoworkspace, 10"
    "$mainMod, S, togglespecialworkspace, magic"
    "$mainMod SHIFT, S, movetoworkspace, special:magic"
    ];

    bindel = [
    ",XF86AudioRaiseVolume, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 && wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"
    ",XF86AudioLowerVolume, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 && wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
    ",XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
    ",XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
    ",XF86MonBrightnessUp, exec, brightnessctl -e4 -n10 set 4%+"
    ",XF86MonBrightnessDown, exec, brightnessctl -e4 -n10 set 4%-"
    ];

    bindl = [
    ", XF86AudioNext, exec, playerctl next"
    ", XF86AudioPause, exec, playerctl play-pause"
    ", XF86AudioPlay, exec, playerctl play-pause"
    ", XF86AudioPrev, exec, playerctl previous"
    ];

    bindm = [
    "$mainMod, mouse:272, movewindow"
    "$mainMod, mouse:273, resizewindow"
    ];
      
  };
}
