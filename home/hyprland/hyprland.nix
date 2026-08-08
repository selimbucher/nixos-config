{ inputs, lib, pkgs, osConfig, ... }:

{
  wayland.windowManager.hyprland = {
    enable = true;
    package = null; # System package is handled in common.nix
    configType = "lua";

    # MUST stay false while common.nix sets programs.hyprland.withUWSM = true.
    # home-manager's systemd integration injects a start hook that runs
    #   systemctl --user stop hyprland-session.target && systemctl --user start ...
    # and hyprland-session.target has PropagatesStopTo=graphical-session.target.
    # Under uwsm that "stop" cascades and kills the session that is starting:
    #   stop hyprland-session.target
    #     -> stops graphical-session.target        (PropagatesStopTo)
    #     -> stops wayland-session@hyprland.target (BindsTo=graphical-session.target)
    #     -> stops wayland-wm@hyprland.service     (BindsTo=wayland-session@)
    # i.e. Hyprland kills its own compositor ~1s after init => SDDM login bounces.
    # uwsm does the dbus/activation-env finalize itself, so this adds nothing.
    #
    # Side effect worth knowing: with this false, home-manager emits no
    # hl.on("hyprland.start", ...) block of its own, so startup.nix owns it.
    systemd.enable = false;

    plugins = [
      # From nixpkgs so the plugin is always built against pkgs.hyprland —
      # never mix in the hyprland flake or its plugins repo (ABI mismatch).
      # In lua mode home-manager emits hl.plugin.load() instead of the old
      # exec-once hyprctl load; see the extraConfig guard below for why that
      # still does not make the plugin available within this same pass.
      pkgs.hyprlandPlugins.hyprbars
    ];

    xwayland.enable = true;

    settings = {
      # ---------------------------------------------------------------- vars
      # were $variables in hyprlang; `_var` emits `local <name> = ...` at the
      # top of hyprland.lua, ahead of every hl.* call, so binds.nix can use them
      terminal = { _var = "kitty"; };
      fileManager = { _var = "nautilus"; };
      webBrowser = { _var = "brave"; };
      taskManager = { _var = "missioncenter"; };
      fetchTerminal = { _var = ''kitty --class=fastfetch-terminal -e bash -c "fastfetch; exec bash"''; };
      lock = { _var = "hyprlock"; };
      editor = { _var = "code"; };

      # ----------------------------------------------------------------- env
      env = [
        { _args = [ "GDK_SCALE" (toString osConfig.deviceConfig.scale) ]; }
        { _args = [ "XCURSOR_SIZE" "24" ]; }
        { _args = [ "HYPRCURSOR_SIZE" "24" ]; }
        { _args = [ "ENABLE_HDR_WSI" "1" ]; }
      ];

      # ------------------------------------------------------------ monitors
      monitor = osConfig.deviceConfig.monitor;

      # ------------------------------------------------------------- devices
      device = {
        name = "epic-mouse-v1";
        sensitivity = -0.5;
      };

      # ------------------------------------------------------------ gestures
      # NOTE: the two hyprexpo gestures that used to live here are gone.
      # hl.gesture() has no `dispatcher` action (only the built-in names or a
      # lua callback), and hyprexpo was never in `plugins` anyway — they were
      # dead config under hyprlang too.
      gesture = [
        { fingers = 3; direction = "horizontal"; action = "workspace"; }
      ];

      # -------------------------------------------------------- window rules
      # (the hyprbars:no_bar rules live in extraConfig, see the guard there)
      window_rule = [
        { match.class = ".*"; float = true; }

        { match.title = "^(REAPER Query)$"; center = true; }

        {
          match.class = "^(io\\.missioncenter\\.MissionCenter)$";
          size = "1000 600";
        }

        {
          match.class = "^(it.mijorus.smile)$";
          float = true;
          move = "monitor_w-window_w-15 monitor_h-window_h-15";
        }

        {
          match.class = "^(steam_app_.*)$";
          immediate = true;
          fullscreen = true;
        }
      ];

      # --------------------------------------------------------- layer rules
      # kiwi-shell (bar + dock) blur, gated on deviceConfig.blur. Disabling
      # decoration.blur only stops window blur — layer surfaces keep blurring
      # unless the rule itself is omitted, so drop it entirely when blur is off.
      layer_rule = lib.optionals osConfig.deviceConfig.blur [
        {
          match.namespace = "^(gtk4-layer-shell)$";
          blur = true;
          blur_popups = true;
          ignore_alpha = 0.2;
        }
      ];

      # -------------------------------------------------------------- config
      config = {
        xwayland.force_zero_scaling = true;

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
            # size 3 / passes 2 was imperceptible behind the shell's 55-86%-opaque
            # dark panels — this is a proper macOS-style frost
            size = 2;
            passes = 2;
            vibrancy = 0.1696;
            noise = 0.01;
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
      };
    };

    # ------------------------------------------------------ hyprbars (plugin)
    # home-manager emits hl.plugin.load() at the top of hyprland.lua, but that
    # call only *registers* the path — Hyprland dlopen()s plugins after the
    # whole chunk has run and then reloads the config. So on the very first
    # pass hl.plugin.hyprbars is still nil and plugin:hyprbars:* config keys
    # do not exist yet; touching them unguarded aborts the rest of the file.
    # Everything that needs the plugin therefore sits behind this guard, which
    # also means a failed plugin load degrades to "no title bars" instead of
    # "no window rules".
    #
    # Note the button actions: under the lua config `hyprctl dispatch X` is a
    # wrapper for hl.dispatch(X), so the old `hyprctl dispatch killactive`
    # spelling is a lua error. They pass real lua expressions, single-quoted
    # so the shell keeps the inner double quotes.
    extraConfig = ''
      if hl.plugin.hyprbars then
        -- macOS-like title bars. Plugin values register as
        -- "plugin:hyprbars:<name>", which lua addresses as
        -- plugin.hyprbars.<name> (':' -> '.', '-' -> '_').
        hl.config({
          plugin = {
            hyprbars = {
              bar_height                 = 26,
              bar_color                  = "rgb(2d2d2d)",
              col                        = { text = "rgb(e8e8e8)" },
              bar_text_size              = 10,
              bar_text_font              = "Rubik",
              bar_text_align             = "center",
              bar_buttons_alignment      = "left",
              bar_part_of_window         = true,
              bar_precedence_over_border = true,
              bar_padding                = 8,
              bar_button_padding         = 6,
              -- like macOS: plain circles, glyphs only appear on hover
              icon_on_hover              = true,
              inactive_button_color      = "rgb(4d4d4d)",
              on_double_click            = "hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = \"maximized\" })'",
            },
          },
        })

        -- traffic lights (leftmost first): close, minimize, zoom.
        -- minimize targets kiwi-shell's special:minimized workspace, so the
        -- dock dims the window's dot and can restore it (dock icon click,
        -- alt-tab confirm, or any activation of the window)
        -- icon font+scale are hardcoded in hyprbars (sans @ 62% of button
        -- size), so clarity comes from heavy glyphs and larger buttons
        hl.plugin.hyprbars.add_button({
          bg_color = "rgb(ff5f57)", fg_color = "rgb(7d0f10)", size = 12, icon = "✖",
          action = "hyprctl dispatch 'hl.dsp.window.close()'",
        })
        hl.plugin.hyprbars.add_button({
          bg_color = "rgb(febc2e)", fg_color = "rgb(90591d)", size = 12, icon = "▬",
          action = "hyprctl dispatch 'hl.dsp.window.move({ workspace = \"special:minimized\", follow = false })'",
        })
        hl.plugin.hyprbars.add_button({
          bg_color = "rgb(28c840)", fg_color = "rgb(0e650e)", size = 12, icon = "✚",
          action = "hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = \"maximized\" })'",
        })

        -- no title bars on games and shell popups
        hl.window_rule({ match = { class = "^(steam_app_.*)$" },     ["hyprbars:no_bar"] = true })
        hl.window_rule({ match = { class = "^(gjs)$" },              ["hyprbars:no_bar"] = true })
        hl.window_rule({ match = { class = "^(it.mijorus.smile)$" }, ["hyprbars:no_bar"] = true })
      end
    '';
  };
}
