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

      inputs.hyprland-plugins.packages.${pkgs.stdenv.hostPlatform.system}.hyprbars
    ];
    
    /*
    extraConfig = ''
      source = ~/.config/kiwi-shell/hypr.conf
      general {
          col.active_border = $kiwiColorLight
      }
    '';
    */

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
        "float 1, match:class .*"

        "center 1, match:title ^(REAPER Query)$"

        "size 1000 600, match:class ^(io\\.missioncenter\\.MissionCenter)$"
        "float 1, move monitor_w-window_w-15 monitor_h-window_h-15, match:class ^(it.mijorus.smile)$"

        #"tile 1, match:class ^(brave-browser)$"
        #"tile 1, match:class ^(code)$"
        #"tile 1, match:class ^(obsidian)$"

        "immediate 1, match:class ^(steam_app_.*)$"
        "fullscreen 1, match:class ^(steam_app_.*)$"

        # no title bars on games and shell popups
        "hyprbars:no_bar 1, match:class ^(steam_app_.*)$"
        "hyprbars:no_bar 1, match:class ^(gjs)$"
        "hyprbars:no_bar 1, match:class ^(it.mijorus.smile)$"
      ];

      /*
      layerrule = {
        name = "blur-kiwi";
        blur = true;
        blur_popups = true;
        ignore_alpha = 0.5;
        "match:namespace" = "^(gtk4-layer-shell)$";
      };
      */
      

      "$terminal" = "kitty";
      "$fileManager" = "nautilus";
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
        border_size = 0;
        # small gaps for tiled windows (hyprland defaults are 5/20)
        gaps_in = 1;
        gaps_out = 2;
        # windows-like resizing by dragging window edges/corners
        # (works with border_size = 0 — the grab zone extends past the window edge)
        resize_on_border = true;
        extend_border_grab_area = 12;
        hover_icon_on_border = true;
        /*
        border_size = 1;
        allow_tearing = false;
        layout = "dwindle";
        "col.inactive_border" = "0x00000000";
        */
      };

      # macOS-like title bars (hyprbars plugin)
      plugin = {
        hyprbars = {
          bar_height = 26;
          bar_color = "rgb(2d2d2d)";
          "col.text" = "rgb(e8e8e8)";
          bar_text_size = 10;
          bar_text_font = "Rubik";
          bar_text_align = "center";
          bar_buttons_alignment = "left";
          bar_part_of_window = true;
          bar_precedence_over_border = true;
          bar_padding = 8;
          bar_button_padding = 6;
          # like macOS: plain circles, glyphs only appear on hover
          icon_on_hover = true;
          inactive_button_color = "rgb(4d4d4d)";
          on_double_click = "hyprctl dispatch fullscreen 1";

          # traffic lights (leftmost first): close, minimize, zoom.
          # minimize targets kiwi-shell's special:minimized workspace, so the
          # dock dims the window's dot and can restore it (dock icon click,
          # alt-tab confirm, or any activation of the window)
          # icon font+scale are hardcoded in hyprbars (sans @ 62% of button
          # size), so clarity comes from heavy glyphs and larger buttons
          hyprbars-button = [
            "rgb(ff5f57), 12, ✖, hyprctl dispatch killactive, rgb(7d0f10)"
            "rgb(febc2e), 12, ▬, hyprctl dispatch movetoworkspacesilent special:minimized, rgb(90591d)"
            "rgb(28c840), 12, ✚, hyprctl dispatch fullscreen 1, rgb(0e650e)"
          ];
        };
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
