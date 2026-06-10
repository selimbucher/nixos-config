{ inputs, pkgs, osConfig, ... }:

{
  wayland.windowManager.hyprland = {
    enable = true;
    package = null; # System package is handled in common.nix
    configType = "hyprlang";

    plugins = [
      #inputs.hyprland-plugins.packages.${pkgs.stdenv.hostPlatform.system}.hyprexpo
      # inputs.Hyprspace.packages.${pkgs.stdenv.hostPlatform.system}.Hyprspace
      # THIS FUCKING PLUGIN IN ASS CHEEKS - IT DOESNT WORK

      #inputs.hyprland-plugins.packages.${pkgs.stdenv.hostPlatform.system}.hyprbars
    ];
    

    extraConfig = ''
      source = ~/.config/kiwi-shell/hypr.conf
      general {
          col.active_border = $kiwiColorLight
      }

      submap = app_switcher

      # Allow repeating TAB while holding ALT to cycle the menu
      binde = ALT, TAB, exec, kiwictl apps open-next

      # Capture the exact release of the Left Alt key using the 'rt' flags
      bindrt = ALT, ALT_L, exec, kiwictl apps confirm
      bindrt = ALT, ALT_L, submap, reset

      # Provide a failsafe to abort if you change your mind
      bindr = , escape, exec, kiwictl apps close
      bindr = , escape, submap, reset

      bindr = ALT, escape, exec, kiwictl apps close
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
        "GDK_SCALE,${toString osConfig.deviceConfig.scale}"
        "XCURSOR_SIZE,24"
        "HYPRCURSOR_SIZE,24"
        "ENABLE_HDR_WSI,1"
      ];

      monitor = osConfig.deviceConfig.monitor;
      
      windowrule = [
        "center 1, match:title ^(REAPER Query)$"

        "float 1, match:class ^(io\\.missioncenter\\.MissionCenter)$"
        "size 1000 600, match:class ^(io\\.missioncenter\\.MissionCenter)$"
        "float 1, match:class ^(org\\.gnome\\.Calculator)$"
        "float 1, move monitor_w-window_w-15 monitor_h-window_h-15, match:class ^(it.mijorus.smile)$"
        "float 1, match:class ^(gjs)$"
        
        "tile 1, match:class ^(brave-browser)$"
        "tile 1, match:class ^(code)$"
        "tile 1, match:class ^(obsidian)$"
        
        "immediate 1, match:class ^(steam_app_.*)$"
        "fullscreen 1, match:class ^(steam_app_.*)$"
      ];

      /*
      layerrule = {
        name = "blur-kiwi";
        blur = true;
        blur_popups = true;
        ignore_alpha = 0.5;
        "match:namespace" = "^(gtk4-layer-shell|rofi)$";
      };
      */
      

      "$terminal" = "kitty";
      "$fileManager" = "nautilus";
      "$menu" = "~/.config/rofi/toggle.sh";
      "$webBrowser" = "brave";
      "$taskManager" = "missioncenter";
      "$fetchTerminal" = "kitty --class=fastfetch-terminal -e bash -c \"fastfetch; exec bash\"";
      "$lock" = "hyprlock";
      "$mainMod" = "SUPER";
      "$editor" = "code";
      
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
        gaps_in = 1;
        gaps_out = 2;
        border_size = 1;
        resize_on_border = false;
        allow_tearing = false;
        layout = "dwindle";
        "col.inactive_border" = "0x00000000";
      };

      decoration = {
        rounding = 6;
        active_opacity = 1.0;
        inactive_opacity = 1.0;
        
        shadow = {
          enabled = osConfig.deviceConfig.shadow;
          range = 10;
          render_power = 3;
          color = "0x70000000";
        };

        blur = {
          enabled = osConfig.deviceConfig.blur;
          size = 3;
          passes = 2;
          vibrancy = 0.1696;
          noise = 0.02;
          contrast = 1.4;
          ignore_opacity = true;
          new_optimizations = true;
        };
      };

      dwindle = {
        preserve_split = true;
        smart_split = false;
      };

      master = {
        new_status = "master";
      };

      misc = {
        force_default_wallpaper = 1;
        disable_hyprland_logo = true;
        focus_on_activate = true;
      };

      input = {
        kb_layout = "ch";
        kb_variant = "de";
        follow_mouse = 1;
        sensitivity = 0.5;
        touchpad = {
          natural_scroll = true;
        };
      };

      device = {
        name = "epic-mouse-v1";
        sensitivity = -0.5;
      };
      
    };
  };
}
