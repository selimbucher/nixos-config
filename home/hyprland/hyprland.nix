{ inputs, lib, pkgs, config, osConfig, ... }:

let
  # Track home/theme.nix rather than hard-coding a colour here, so the bars
  # hyprbars draws on undecorated windows match the header bars GTK draws on
  # decorated ones.
  isLight = config.gtk.colorScheme == "light";

  # hover glyphs, shared with the GTK header bars (home/theme.nix)
  glyphs = pkgs.callPackage ../../pkgs/titlebutton-glyphs.nix { };

  barColor = if isLight then "rgb(f6f6f6)" else "rgb(2e2e32)";
  lightBarText = "rgb(4d4d4d)";
  darkBarText = "rgb(e8e8e8)";
  barTextColor = if isLight then lightBarText else darkBarText;
  barInactiveButton = if isLight then "rgb(cecece)" else "rgb(4d4d4d)";
  kittyBg = "rgb(${lib.removePrefix "#" config.programs.kitty.settings.background})";

  # A macOS window is a hairline plus a large, soft, low-opacity shadow —
  # the shadow is what reads as "border", not the 1px itself.
  borderActive = if isLight then "rgba(00000026)" else "rgba(ffffff1f)";
  borderInactive = if isLight then "rgba(00000014)" else "rgba(ffffff0f)";

  # hyprbars has no way to detect client-side decorations (Hyprland exposes no
  # CSD/SSD field to window rules -- checked `hyprctl clients -j`), so it has to
  # be a list. The list is inverted on purpose: hyprbars' updateRules() reads
  # `hyprbars:no_bar` as one overwritable prop, so a catch-all followed by
  # exceptions works, and the *default* is "no bar". That way a newly installed
  # GTK/Electron app never shows two rows of window controls -- worst case it
  # loses the hyprbars bar and keeps its own, which is the harmless direction.
  #
  # Listed here: apps with no decorations of their own, which need hyprbars.
  # `bar`/`title` tint that app's bar to its own background. Hyprland rounds
  # all four corners of every surface (its rounding shader mirrors the pixel
  # into one quadrant; there is no per-corner setting in 0.56) and hyprbars
  # only paints behind the top two, so under a light bar a dark app shows a
  # light cut-out at each top corner. A bar in the app's own colour is what
  # makes that vanish — and it is what macOS Terminal does with a dark profile.
  ssdApps = [
    { class = "^(kitty)$"; bar = kittyBg; title = darkBarText; }
    { class = "^(fastfetch-terminal)$"; bar = kittyBg; title = darkBarText; }
    # Reapertips dark theme: col_main_bg / col_toolbar_text
    { class = "^(REAPER)$"; bar = "rgb(323232)"; title = "rgb(c2c6ce)"; }
    { class = "^(.*\\\\.exe)$"; } # wine (Native Access, installers, ...) — varies per app
    { class = "^(org\\\\.kde\\\\..*)$"; } # Qt/KDE apps use server-side decorations here
    { class = "^(pavucontrol)$"; }
  ];

  ssdRule =
    { class, bar ? null, title ? null }:
    "        hl.window_rule({ match = { class = \"${class}\" }, [\"hyprbars:no_bar\"] = false"
    + lib.optionalString (bar != null) ", [\"hyprbars:bar_color\"] = \"${bar}\""
    + lib.optionalString (title != null) ", [\"hyprbars:title_color\"] = \"${title}\""
    + " })";
in
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
      # Patched to draw an SVG as a button icon, to show only the hovered
      # button's glyph, and to light that button up in an unfocused window too;
      # see pkgs/hyprbars-svg-icons.patch.
      (pkgs.hyprlandPlugins.hyprbars.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ../../pkgs/hyprbars-svg-icons.patch ];
      }))
      # Makes the CSD minimize button work; see the header of the package for
      # why Hyprland drops the request on its own.
      (pkgs.callPackage ../../pkgs/hyprland-csd-minimize.nix {
        inherit (pkgs.hyprlandPlugins) mkHyprlandPlugin;
      })
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
      layer_rule = [
        # sudo-askpass pill (rofi, see common.nix): dim the rest of the
        # screen behind it, hyprlock-style
        {
          match.namespace = "^(rofi)$";
          dim_around = true;
        }
      ] ++ lib.optionals osConfig.deviceConfig.blur [
        {
          match.namespace = "^(gtk4-layer-shell)$";
          blur = true;
          blur_popups = true;
          ignore_alpha = 0.2;
        }
        {
          match.namespace = "^(rofi)$";
          blur = true;
          ignore_alpha = 0.1;
        }
      ];

      # -------------------------------------------------------------- config
      config = {
        xwayland.force_zero_scaling = true;

        general = {
          # A single hairline, the way macOS separates a window from what is
          # behind it. The heavy lifting is done by the shadow below; anything
          # thicker than 1px stops reading as macOS immediately.
          border_size = 1;
          col = {
            active_border = borderActive;
            inactive_border = borderInactive;
          };
          # small gaps for tiled windows (hyprland defaults are 5/20)
          gaps_in = 1;
          gaps_out = 2;
          # windows-like resizing by dragging window edges/corners
          resize_on_border = true;
          extend_border_grab_area = 12;
          hover_icon_on_border = true;
          allow_tearing = true;      # makes your existing `immediate = true` rule actually work
        };

        decoration = {
          # Big Sur and later sit around 10-12px; 14 to taste. rounding_power shapes the
          # arc: 2.0 is a plain circular quarter-arc, higher values flatten it
          # into a squircle. Apple's own corner is a squircle, but it reads as
          # "slightly square" here, so keep the circular arc.
          rounding = 14;
          rounding_power = 2.0;
          active_opacity = 1.0;
          inactive_opacity = 1.0;

          # macOS drops a wide, very soft, offset shadow rather than a tight
          # dark halo: large range, low render_power, low alpha, pushed down.
          # Inactive windows keep a much fainter one.
          shadow = {
            enabled = osConfig.deviceConfig.shadow;
            range = 40;
            render_power = 2;
            offset = "0 12";
            color = "rgba(00000055)";
            color_inactive = "rgba(00000022)";
          };

          blur = {
            enabled = osConfig.deviceConfig.blur;
            # size 3 / passes 2 was imperceptible behind the shell's 55-86%-opaque
            # dark panels — this is a proper macOS-style frost
            size = 6;
            passes = 3;
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
          vrr = 2;                   # fullscreen-only — avoids OLED desktop flicker/brightness shifts
        };

        input = {
          kb_layout = "ch";
          kb_variant = "de";
          follow_mouse = 1;
          sensitivity = 0.5;
          touchpad = {
            natural_scroll = true;
            disable_while_typing = false;
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
              -- 28px is the macOS title bar height; the traffic lights are
              -- 12px circles inset from the left edge with 8px between them.
              bar_height                 = 28,
              bar_color                  = "${barColor}",
              col                        = { text = "${barTextColor}" },
              bar_text_size              = 11,
              -- same family as the GTK header bars (see home/theme.nix)
              bar_text_font              = "Inter",
              bar_text_align             = "center",
              bar_buttons_alignment      = "left",
              bar_part_of_window         = true,
              bar_precedence_over_border = true,
              bar_padding                = 12,
              bar_button_padding         = 8,
              -- plain circles; the hovered one shows its glyph (patched)
              icon_on_hover              = true,
              inactive_button_color      = "${barInactiveButton}",
              on_double_click            = "hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = \"maximized\" })'",
            },
          },
        })

        -- traffic lights (leftmost first): close, minimize, zoom.
        -- minimize targets kiwi-shell's special:minimized workspace, so the
        -- dock dims the window's dot and can restore it (dock icon click,
        -- alt-tab confirm, or any activation of the window)
        -- icons are the SVGs the GTK header bars use (home/theme.nix), so
        -- both kinds of title bar show identical glyphs; fg_color is required
        -- by add_button but unused for an SVG icon
        hl.plugin.hyprbars.add_button({
          bg_color = "rgb(fe6254)", fg_color = "rgb(7d0f10)", size = 14, icon = "${glyphs}/close.svg",
          action = "hyprctl dispatch 'hl.dsp.window.close()'",
        })
        hl.plugin.hyprbars.add_button({
          bg_color = "rgb(fdc92d)", fg_color = "rgb(90591d)", size = 14, icon = "${glyphs}/minimize.svg",
          action = "hyprctl dispatch 'hl.dsp.window.move({ workspace = \"special:minimized\", follow = false })'",
        })
        hl.plugin.hyprbars.add_button({
          bg_color = "rgb(28d33f)", fg_color = "rgb(0e650e)", size = 14, icon = "${glyphs}/maximize.svg",
          action = "hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = \"maximized\" })'",
        })

        -- One bar per window: no bar by default, re-enabled only for the
        -- undecorated apps in ssdApps. Order matters -- the catch-all has to
        -- come first so the per-class rules can overwrite it.
        hl.window_rule({ match = { class = ".*" }, ["hyprbars:no_bar"] = true })
${lib.concatMapStringsSep "\n" ssdRule ssdApps}
      end

      -- csd-minimize needs no config here: its default command is patched in
      -- pkgs/hyprland-csd-minimize.nix to target special:minimized, the same
      -- place the hyprbars minimize button above sends windows.
    '';
  };

  # Polkit authentication agent — Hyprland ships none, so without this every
  # polkit-gated GUI action (GNOME Disks, GParted, virt-manager, ...) fails
  # with an authentication error instead of showing a password dialog.
  # Runs as a user service bound to graphical-session.target.
  services.hyprpolkitagent.enable = true;
}
