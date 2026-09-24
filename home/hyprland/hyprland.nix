{ inputs, lib, pkgs, config, osConfig, ... }:

let
  # hover glyphs, shared with the GTK header bars (home/theme.nix)
  glyphs = pkgs.callPackage ../../pkgs/titlebutton-glyphs.nix { };

  # Bar and border colours come from the palette the GTK header bars use, so
  # the bars hyprbars draws on undecorated windows match the header bars GTK
  # draws on decorated ones. Which half applies is read from
  # org.gnome.desktop.interface color-scheme when the config loads; theme-follow
  # (home/theme.nix) re-applies them live when it changes.
  palette = import ../../pkgs/desktop-palette.nix;
  # A macOS window is a hairline plus a large, soft, low-opacity shadow; the
  # shadow is what reads as "border", not the 1px itself.
  hyprColours = p: lib.concatStringsSep ", " [
    ''bar = "rgb(${p.headerbar})"''
    ''title = "rgb(${p.title})"''
    ''control_idle = "rgb(${p.controlIdle})"''
    ''border_active = "rgba(${p.borderActive})"''
    ''border_inactive = "rgba(${p.borderInactive})"''
  ];

  darkBarText = "rgb(${palette.dark.title})";
  kittyBg = "rgb(${lib.removePrefix "#" config.programs.kitty.settings.background})";

  # Which windows get a hyprbars bar is decided by the window itself, in the
  # patched plugin (pkgs/hyprbars-svg-icons.patch): a bar exactly when the
  # client asks the compositor to decorate it (xdg-decoration server-side, or
  # X11 without the no-borders hint). GTK/libadwaita apps and Chromium/Electron
  # apps drawing their own frame ask for nothing or for client-side, so they
  # never get a second row of buttons; kitty, Qt, wine, Obsidian's "native
  # frame" or Brave's "system title bar" ask for server-side and get one. No
  # app list. A `hyprbars:no_bar` window rule still overrides it either way.
  #
  # What remains per app is colour: Hyprland rounds all four corners of every
  # surface (the rounding shader mirrors into one quadrant; 0.56 has no
  # per-corner setting) and hyprbars only paints behind the top two, so under a
  # light bar a dark app shows a light cut-out at each top corner. Tinting the
  # bar to the app's own background hides that, as macOS Terminal does.
  barColours = [
    { class = "^(kitty)$"; bar = kittyBg; title = darkBarText; }
    { class = "^(fastfetch-terminal)$"; bar = kittyBg; title = darkBarText; }
    # Reapertips dark theme: col_main_bg / col_toolbar_text
    { class = "^(REAPER)$"; bar = "rgb(323232)"; title = "rgb(c2c6ce)"; }
  ];

  barColourRule =
    { class, bar, title }:
    "        hl.window_rule({ match = { class = \"${class}\" }, [\"hyprbars:bar_color\"] = \"${bar}\", [\"hyprbars:title_color\"] = \"${title}\" })";
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
      # Floating windows open where the app's window was last left; see
      # pkgs/hyprland-window-memory/main.cpp. After hyprbars: it places windows
      # by their title bar, which hyprbars adds as they open.
      (pkgs.callPackage ../../pkgs/hyprland-window-memory {
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
      appearance = {
        _var = lib.generators.mkLuaInline ''
          (function()
            local light = { ${hyprColours palette.light} }
            local dark = { ${hyprColours palette.dark} }
            local p = io.popen("${pkgs.dconf}/bin/dconf read /org/gnome/desktop/interface/color-scheme 2>/dev/null")
            local scheme = p and p:read("a") or ""
            if p then p:close() end
            return scheme:find("prefer-dark", 1, true) and dark or light
          end)()'';
      };

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
            active_border = lib.generators.mkLuaInline "appearance.border_active";
            inactive_border = lib.generators.mkLuaInline "appearance.border_inactive";
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
            offset = "0 7";
            color = "rgba(00000055)";
            color_inactive = "rgba(00000022)";
          };

          # The blur itself (size, passes, vibrancy, contrast, noise, xray) is
          # kiwi-shell's: it sets it for its glass at start and after every
          # reload (kiwi_blur, widgets/services/theme.ts). Only whether windows
          # blur at all stays here.
          blur = {
            enabled = osConfig.deviceConfig.blur;
            ignore_opacity = true;
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
          # VRR only for fullscreen games (content type game). Off on the desktop
          # (OLED flicker/brightness shifts) and for other fullscreen windows:
          # every VRR switch re-syncs the eDP panel, a ~1s blank screen.
          vrr = 3;
        };

        # Click to focus, and the pointer stays where it is, as on macOS and
        # Windows: picking a window from the dock or the switcher doesn't
        # yank the pointer into it. The pointer's window still gets scrolling
        # and hover; the keyboard moves only with a click.
        cursor.no_warps = true;

        input = {
          kb_layout = "ch";
          kb_variant = "de";
          follow_mouse = 2;
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
              bar_color                  = appearance.bar,
              col                        = { text = appearance.title },
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
              inactive_button_color      = appearance.control_idle,
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

        -- per-app bar colours; whether a window has a bar at all is up to
        -- the window (see barColours in the let block)
${lib.concatMapStringsSep "\n" barColourRule barColours}
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
