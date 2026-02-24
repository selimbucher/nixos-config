{ inputs, pkgs, osConfig, ... }:

{
  wayland.windowManager.hyprland = {
    enable = true;
    # System package is handled in configuration.nix
    package = null;

    plugins = [
      # inputs.hyprland-plugins.packages.${pkgs.stdenv.hostPlatform.system}.hyprexpo
      # inputs.Hyprspace.packages.${pkgs.stdenv.hostPlatform.system}.Hyprspace
      # THIS FUCKING PLUGIN IN ASS CHEEKS - IT DOESNT WORK
    ];
    

    # Raw configuration for Monitor, HDR, and Color settings
    extraConfig = ''
      source = ~/.config/desktop/hypr.conf
      general {
          col.active_border = $primaryColor
      }
      
      # Monitor Configuration
      monitor = ${osConfig.deviceConfig.monitor}

      # Experimental HDR/OLED settings
      # These specific keys often require raw config because they are experimental
      # monitor = eDP-1, addreserved, 0, 0, 0, 0
      # debug:manual_crash = 0


      submap = switch_sandbox

      # Allow repeating TAB while holding ALT to cycle the menu
      binde = ALT, TAB, exec, desktop-ctl apps open-next

      # Capture the exact release of the Left Alt key using the 'rt' flags
      bindrt = ALT, ALT_L, exec, desktop-ctl apps confirm
      bindrt = ALT, ALT_L, submap, reset

      # Provide a failsafe to abort if you change your mind
      bindr = , escape, exec, desktop-ctl apps close
      bindr = , escape, submap, reset

      bindr = ALT, escape, exec, desktop-ctl apps close
      bindr = ALT, escape, submap, reset

      # Terminate the submap declaration
      submap = reset
    '';

    xwayland.enable = true;
    
    settings = {
      xwayland = {
        force_zero_scaling = true;
      };

      env = [
        "GDK_SCALE,2"
        "XCURSOR_SIZE,32"
        "HYPRCURSOR_SIZE,24"
        "ENABLE_HDR_WSI,1"
      ];

      windowrule = [
        "float 1, match:class .*"        

        "float 1, match:class ^(io\\.missioncenter\\.MissionCenter)$"
        "size 1000 600, match:class ^(io\\.missioncenter\\.MissionCenter)$"
        "float 1, match:class ^(org\\.gnome\\.Calculator)$"
        "float 1, match:class ^(kitty)$"
        "float 1, match:class ^(org.gnome.Nautilus)$"
        "float 1, match:class ^(\\.blueman-manager-wrapped)$"
        "float 1, move monitor_w-window_w-15 monitor_h-window_h-15, match:class ^(it.mijorus.smile)$"
        "float 1, match:class ^(gjs)$"
        
        "tile 1, match:class ^(brave-browser)$"
        "tile 1, match:class ^(code)$"
        "tile 1, match:class ^(obsidian)$"
        
        "immediate 1, match:class ^(steam_app_.*)$"
        "fullscreen 1, match:class ^(steam_app_.*)$"

        "move (cursor_x-(window_w*0.5)) (cursor_y-(window_h*0.5)) match:class ^(kitty)$"
      ];

      
      layerrule = {
        name = "blur-desktop";
        blur = true;
        blur_popups = true;
        ignore_alpha = 0.1;
        "match:namespace" = "^(gtk4-layer-shell|rofi)$";
      };
      

      "$terminal" = "kitty";
      "$fileManager" = "nautilus";
      "$menu" = "~/.config/rofi/toggle.sh";
      "$webBrowser" = "brave";
      "$taskManager" = "missioncenter";
      "$fetchTerminal" = "kitty --class=fastfetch-terminal -e bash -c \"fastfetch; exec bash\"";
      "$lock" = "hyprlock";
      "$mainMod" = "SUPER";

      # Standard startup applications
      exec-once = [
        "swww-daemon"
        "xsettingsd"
        "hyprctl setcursor WhiteSur-cursors 24"
        "waycorner"
        "wl-clip-persist --clipboard regular"   #
        "play --volume=0.45 .config/desktop/startup.mp3" #
      ];

      # Applications to run on every reload
      exec = [
        "desktop"
      ];

      gesture = [
        "3, horizontal, workspace"
        "3, down, dispatcher, hyprexpo:expo, on"
        "3, up, dispatcher, hyprexpo:expo, off"
      ];

      gestures = {
        workspace_swipe_distance = 400;
        
        # INVERT SCROLLING (Touchpad)
        workspace_swipe_invert = true; 

        workspace_swipe_min_speed_to_force = 20; 
        workspace_swipe_cancel_ratio = 0.2;

        # BEHAVIOR
        # Creates a new empty workspace if you swipe past the last one
        workspace_swipe_create_new = true; 
        
        # Continuous swiping (go 1 -> 2 -> 3 in one long drag)
        workspace_swipe_forever = true; 
      };

      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
        resize_on_border = false;
        allow_tearing = false;
        layout = "dwindle";
        "col.inactive_border" = "0xff444444";
      };

      decoration = {
        rounding = 6;
        active_opacity = 1.0;
        inactive_opacity = 1.0;
        
        shadow = {
          enabled = true;
          range = 10;
          render_power = 3;
          color = "0x70000000";
          ignore_window = true;
        };

        blur = {
          enabled = true;
          size = 3;
          passes = 2;
          vibrancy = 0.1696;
          noise = 0.02;
          contrast = 1.4;
          ignore_opacity = true;
          new_optimizations = true;
        };
      };

      animations = {
        enabled = true;
        bezier = [
          "easeOutQuint,0.23,1,0.32,1"
          "easeInOutCubic,0.65,0.05,0.36,1"
          "linear,0,0,1,1"
          "almostLinear,0.5,0.5,0.75,1.0"
          "quick,0.15,0,0.1,1"
        ];
        animation = [
          "global, 1, 10, default"
          "border, 1, 5.39, easeOutQuint"
          "windows, 1, 4.79, easeOutQuint"
          "windowsIn, 1, 4.1, easeOutQuint, popin 87%"
          "windowsOut, 1, 1.49, linear, popin 87%"
          "fadeIn, 1, 1.73, almostLinear"
          "fadeOut, 1, 1.46, almostLinear"
          "fade, 1, 3.03, quick"
          "layers, 1, 3.81, easeOutQuint"
          "layersIn, 1, 4, easeOutQuint, fade"
          "layersOut, 1, 1.5, linear, fade"
          "fadeLayersIn, 1, 1.79, almostLinear"
          "fadeLayersOut, 1, 1.39, almostLinear"
          "workspaces, 1, 6, easeOutQuint, slide"
          "workspacesIn, 1, 5, easeOutQuint, slidefade"
          "workspacesOut, 1, 4, easeInOutCubic, slidefade"
        ];
      };

      dwindle = {
        pseudotile = true;
        preserve_split = true;
        smart_split = true;
      };

      master = {
        new_status = "master";
      };

      misc = {
        force_default_wallpaper = 1;
        disable_hyprland_logo = true;
        vfr = true;
        focus_on_activate = true;
      };

      input = {
        kb_layout = "ch";
        kb_variant = "de";
        follow_mouse = 1;
        sensitivity = 0.25; # Updated
        touchpad = {
          natural_scroll = true;
        };
      };

      device = {
        name = "epic-mouse-v1";
        sensitivity = -0.5;
      };

      bind = [
        "ALT, TAB, exec, desktop-ctl apps open-next"
        "ALT, TAB, submap, switch_sandbox"

        "SUPER, period, exec, smile"
        ", section, togglespecialworkspace, magic"
        "SHIFT, section, movetoworkspace, special:magic"

        ", Print, exec, grim -g \"$(slurp)\" - | wl-copy"
        "CTRL, Print, exec, grim - | wl-copy"
        "$mainMod, Q, exec, $terminal"
        "$mainMod SHIFT, Q, exec, $fetchTerminal"
        "$mainMod, C, killactive,"
        "$mainMod, E, exec, $fileManager"
        "$mainMod, A, togglefloating,"
        "SUPER_L, SUPER_L, exec, $menu"
        "$mainMod, P, pseudo,"
        "$mainMod, Y, togglesplit,"
        "$mainMod, W, exec, $webBrowser"
        "CTRL SHIFT, Escape, exec, $taskManager"
        "$mainMod, L, exec, $lock"
        "$mainMod SHIFT, P, exec, poweroff"
        "$mainMod SHIFT, R, exec, reboot"
        "$mainMod SHIFT, E, exit,"
        "$mainMod, F, fullscreen, 0"
        "$mainMod, N, exec, swaync-client -t"
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
        ",XF86AudioRaiseVolume, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 && wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+ && desktop-ctl show volume"
        ",XF86AudioLowerVolume, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 && wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- && desktop-ctl show volume"
        ",XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle && desktop-ctl show volume"
        ",XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
        ",XF86MonBrightnessUp, exec, brightnessctl -e4 -n10 set 4%+ && desktop-ctl show brightness"
        ",XF86MonBrightnessDown, exec, brightnessctl -e4 -n10 set 4%- && desktop-ctl show brightness"
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
      
      # plugin = { ... };
    };
  };
}
