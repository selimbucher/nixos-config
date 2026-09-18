# Single source of truth for the desktop's look.
#
# Before this file there were three of them, all disagreeing: a hand-written
# ~/.config/gtk-3.0/settings.ini (WhiteSur-Light), a dconf tree written by
# nwg-look (gtk-theme WhiteSur-Light, color-scheme prefer-dark, icons
# WhiteSur-dark), and a ~/.config/gtk-4.0/gtk.css symlink into a store path that
# no longer existed. None of it was in the flake, and the theme package was not
# installed at all — every GTK app was silently falling back to stock Adwaita.
{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:
let
  # Light and dark are switched at runtime, not here: kiwi-shell's theme tab
  # (or anything else) sets org.gnome.desktop.interface color-scheme, GTK4 and
  # libadwaita follow it through @media in gtk.css, and theme-follow (below)
  # moves the GTK3 theme, icon theme, X11 settings and Hyprland colours along.
  palette = import ../pkgs/desktop-palette.nix;
  inherit (palette) light dark;

  whitesur = pkgs.callPackage ../pkgs/whitesur-libadwaita.nix { };

  # hover glyphs shared with hyprbars (see home/hyprland/hyprland.nix)
  glyphs = pkgs.callPackage ../pkgs/titlebutton-glyphs.nix { };
  # the same glyphs inline, for pages that may not load file:// (Obsidian)
  glyphDataUri =
    name:
    "data:image/svg+xml,"
    + lib.replaceStrings [ "#" "\"" "<" ">" " " ] [ "%23" "'" "%3C" "%3E" "%20" ]
      (import ../pkgs/titlebutton-glyphs-svg.nix).${name};

  # Finder-style sidebar icons: outline glyphs in Finder's blue, per appearance
  # (palette.sidebarIcon). Mixing libadwaita's accent (#3584e4) into the text
  # colour read as cyan, so they are fixed colours instead.

  # selim-icons is our WhiteSur-icon-theme fork; patch sizes and gaps on top.
  iconTheme = (inputs.selim-icons.packages.${pkgs.stdenv.hostPlatform.system}.default).overrideAttrs (old: {
    # WhiteSur keeps two sets of artwork for folders and files: flat glyphs in
    # fixed 16/22/24px directories (places/, mimes/) and the full-colour icons
    # in */scalable, which only answer from 24-32px up. Nautilus's list view
    # asks for ~20px, so it got the glyphs — outline Desktop, flat file icons —
    # while the grid showed the colour ones. Delete every small icon that also
    # exists as a scalable one (icons that exist only small are kept) and let
    # scalable answer at any size, so each file looks the same in both views.
    # App, status and tray icons are left alone.
    #
    # The sidebar asks for folder-*-symbolic. WhiteSur has no symbolic Downloads,
    # Music, Public or Templates icon, so GTK fell back to the full-colour
    # folder there. Fill the gaps with WhiteSur's own nearest symbolics; the
    # Downloads one is the arrow-in-circle Finder uses.
    postInstall = (old.postInstall or "") + ''
      removed=$TMPDIR/removed-icons
      for theme in $out/share/icons/WhiteSur*; do
        [ -d "$theme" ] || continue
        for ctx in places mimes; do
          for scale in "" "@2x"; do
            scalable="$theme/$ctx$scale/scalable"
            [ -d "$scalable" ] || continue
            for size in 16 22 24; do
              dir="$theme/$ctx$scale/$size"
              [ -d "$dir" ] || continue
              for icon in "$dir"/*; do
                name=''${icon##*/}
                if [ -e "$scalable/$name" ] || [ -L "$scalable/$name" ]; then
                  rel=''${icon#$out/}
                  mkdir -p "$removed/''${rel%/*}"
                  mv "$icon" "$removed/$rel"
                fi
              done
            done
          done
        done
        sed -i -E '/^\[(places|mimes)(@2x)?\/scalable\]/,/^\[/ s/^MinSize=.*/MinSize=8/' \
          "$theme/index.theme"
      done

      # Some icons elsewhere are symlinks into the removed files (the trash
      # and desktop symbolics among them). Turn each such link into a copy of
      # what it pointed at, rather than putting the small file back.
      find $out/share/icons -xtype l | while IFS= read -r link; do
        cur=$link
        for _ in $(seq 20); do
          [ -L "$cur" ] || break
          target=$(readlink "$cur")
          case $target in /*) ;; *) target=''${cur%/*}/$target ;; esac
          target=$(realpath -ms "$target")
          [ -e "$target" ] || [ -L "$target" ] || target=$removed/''${target#$out/}
          cur=$target
        done
        if [ -f "$cur" ] && [ ! -L "$cur" ]; then
          cp --remove-destination "$cur" "$link"
        fi
      done

      for theme in $out/share/icons/WhiteSur*; do
        [ -d "$theme" ] || continue

        # Finder's sidebar trash is the same outline whether full or not
        for scale in "" "@2x"; do
          dir="$theme/places$scale/symbolic"
          [ -e "$dir/user-trash-symbolic.svg" ] || continue
          cp --remove-destination -L "$dir/user-trash-symbolic.svg" "$dir/user-trash-full-symbolic.svg"
        done

        for pair in folder-download:browser-download folder-music:music-note \
                    folder-templates:dialog-templates folder-publicshare:share; do
          want=''${pair%%:*}-symbolic.svg
          have=''${pair#*:}-symbolic.svg
          for scale in "" "@2x"; do
            dest="$theme/places$scale/symbolic"
            [ -d "$dest" ] && [ ! -e "$dest/$want" ] || continue
            # upstream ships some of these as dangling symlinks
            rm -f "$dest/$want"
            src=$(find -L "$theme" -path "*$scale/symbolic/$have" -print -quit)
            [ -n "$src" ] && cp -L "$src" "$dest/$want"
          done
        done
      done
    '';
    # Runs after upstream's postFixup has pruned symlinks left dangling above,
    # so the cache is rebuilt against the final tree.
    postFixup = (old.postFixup or "") + ''
      for theme in $out/share/icons/WhiteSur*; do
        [ -d "$theme" ] || continue
        gtk-update-icon-cache -f -t "$theme"
      done
    '';
  });

  # WhiteSur draws its window controls as 16px PNGs: a 14px disc with a 1px
  # rim, spaced ~4px apart. hyprbars draws a flat disc of `size` with exactly
  # `bar_button_padding` between discs, and add_button takes no border field —
  # so a rim is not expressible there. Rather than have the two families differ,
  # drop the PNGs and draw flat circles at hyprbars' geometry: 14px discs, 8px
  # gaps. Colours are WhiteSur's own, sampled from the assets.
  #
  # WhiteSur qualifies its own rules by button class, state and window state
  # (`.maximized headerbar windowcontrols button.maximize:backdrop:hover` sits
  # at (0,4,3)), so a plain `windowcontrols > button` loses every contest and
  # the theme's 16px PNG, min-width:16px and padding:4px 1px survive. Rather
  # than mirror each prefix the theme uses, every selector here carries three
  # `:not()` guards on classes a window control never has: same elements
  # matched, three more class points, later in the cascade — it wins against
  # anything the theme ships.
  ctlBoost = ":not(.suggested-action):not(.destructive-action):not(.flat)";
  ctlStates = [ "" ":hover" ":active" ":focus" ":backdrop" ":backdrop:hover" ];
  ctlLit = [ "" ":hover" ":active" ":focus" ];
  ctlClasses = {
    close = "#fe6254";
    minimize = "#fdc92d";
    maximize = "#28d33f";
  };
  ctlNames = lib.attrNames ctlClasses;
  # the unfocused grey differs per appearance; see ctlIdleRule and the
  # traffic_light_idle colour the GTK3 themes define
  ctlIdle = "#${light.controlIdle}";

  # Shared with hyprbars: size 14, bar_button_padding 8 (4 each side),
  # bar_padding 12 = the headerbar's own 8px box padding + one 4px margin.
  ctlDisc = "14px";
  ctlHalfGap = "4px";
  # hyprbars bar_padding: first disc's left edge from the window edge
  ctlInset = 12;
  # room between the last disc and the app's own first control (Brave's first
  # tab, Obsidian's sidebar toggle)
  ctlTrailingGap = 12;

  join = lib.concatStringsSep ",\n";

  # GTK4/libadwaita. GTK creates the control button with valign=fill, so it is
  # as tall as the header bar's content box (26px here) whatever its min-height
  # says; only its centred `image` child can be made exactly 14px, through
  # -gtk-icon-size. So, as libadwaita itself does, the disc is painted on the
  # image and the button is left transparent (it stays the click target).
  trafficLightCss =
    let
      btn = cls: st: "headerbar windowcontrols button.${cls}${st}${ctlBoost}";
      img = bar: cls: st: "${bar} windowcontrols button.${cls}${st}${ctlBoost} > image";
    in
    ''
      ${join (lib.concatMap (cls: map (btn cls) ctlStates) ctlNames)} {
        background: none;
        min-width: ${ctlDisc};
        min-height: ${ctlDisc};
        padding: 0;
        margin: 0 ${ctlHalfGap};
        border: none;
        box-shadow: none;
        transition: none;
      }

      ${join (lib.concatMap (cls: map (img "headerbar" cls) ctlStates) ctlNames)} {
        -gtk-icon-size: ${ctlDisc};
        min-width: ${ctlDisc};
        min-height: ${ctlDisc};
        padding: 0;
        margin: 0;
        border: none;
        border-radius: 9999px;
        box-shadow: none;
        -gtk-icon-shadow: none;
        color: transparent;
        background-image: none;
        background-color: ${ctlIdle};
        transition: none;
      }

      /* dark: only the unfocused grey changes. Before the lit and hover rules,
         which have to keep winning over it. */
      @media (prefers-color-scheme: dark) {
        ${join (lib.concatMap (cls: map (img "headerbar" cls) ctlStates) ctlNames)} {
          background-color: #${dark.controlIdle};
        }
      }

      ${lib.concatStringsSep "\n\n" (
        lib.mapAttrsToList (cls: colour: ''
          ${join (map (img "headerbar:not(:backdrop)" cls) ctlLit)} {
            background-color: ${colour};
          }
        '') ctlClasses
      )}

      /* Hover shows that button's glyph, and its colour even in an unfocused
         window. Only the hovered button: :hover is set on that one alone. */
      ${lib.concatStringsSep "\n\n" (
        lib.mapAttrsToList (cls: colour: ''
          ${join (map (img "headerbar" cls) [ ":hover" ":backdrop:hover" ])} {
            background-color: ${colour};
            background-image: -gtk-scaled(url("file://${glyphs}/${cls}.png"), url("file://${glyphs}/${cls}@2.png"));
            background-size: ${ctlDisc} ${ctlDisc};
            background-position: center;
            background-repeat: no-repeat;
          }
        '') ctlClasses
      )}

      /* the theme pads and spaces the container too; the buttons' own margins
         carry the 8px gap, and 8px box padding + 4px margin = 12px inset */
      headerbar windowcontrols.start:not(.empty),
      headerbar windowcontrols.end:not(.empty) {
        border-spacing: 0;
        padding: 0;
        margin-left: 0;
      }
    '';

  # GTK3 (gnome-disks via libhandy, Thunderbird, Chromium's GTK frame) has no
  # -gtk-icon-size, so the disc is a radial gradient on the button itself and
  # the geometry is set through GTK3's box model, measured with a probe:
  #   header bar padding 8 + title-button box padding 10, box spacing 6 (a
  #   widget property, not CSS), button = CSS margins + its 16px icon.
  # A 16px icon with -1px margins takes 14px; 1px button margins make each
  # button 16 wide, + 6 spacing = the 22px pitch; box padding 3 puts the first
  # disc centre at 8 + 3 + 8 = 19px, as in hyprbars and libadwaita.
  # Every stop fades to the disc colour at zero alpha: GTK3 interpolates
  # unpremultiplied, so fading to `transparent` (black) left a dark rim.
  # The unfocused grey is @traffic_light_idle, which WhiteSur-Light and
  # WhiteSur-Dark each define (pkgs/whitesur-libadwaita.nix): GTK3 CSS has no
  # media queries, but switching the theme re-resolves the colour.
  trafficLightCss3 =
    let
      btn = bar: cls: st: "${bar} button.titlebutton.${cls}${st}${ctlBoost}";
      disc = colour: "radial-gradient(circle closest-side, ${colour} 6.5px, alpha(${colour}, 0) 7px)";
      glyph = cls: ''-gtk-scaled(url("file://${glyphs}/${cls}.png"), url("file://${glyphs}/${cls}@2.png"))'';
    in
    ''
      ${join (lib.concatMap (cls: map (btn "headerbar" cls) ctlStates) ctlNames)} {
        background-color: transparent;
        background-image: ${disc "@traffic_light_idle"};
        background-size: ${ctlDisc} ${ctlDisc};
        background-position: center;
        background-repeat: no-repeat;
        min-width: ${ctlDisc};
        min-height: ${ctlDisc};
        padding: 0;
        margin: 0 1px;
        border: none;
        box-shadow: none;
        -gtk-icon-shadow: none;
        transition: none;
      }

      ${lib.concatStringsSep "\n\n" (
        lib.mapAttrsToList (cls: colour: ''
          ${join (map (st: btn "headerbar" cls "${st}:not(:backdrop)") ctlLit)} {
            background-image: ${disc colour};
          }
        '') ctlClasses
      )}

      /* Focus is read from the button's own :backdrop, not the header bar's:
         GTK sets it on both, but Chromium's frame sets it on the button only.
         Both rules set background-image, so the hover glyph needs the lit
         rule's specificity too, and to come after it. */
      ${lib.concatStringsSep "\n\n" (
        lib.mapAttrsToList (cls: colour: ''
          ${join [ (btn "headerbar" cls ":hover:not(:backdrop)") (btn "headerbar" cls ":backdrop:hover") ]} {
            background-image: ${glyph cls}, ${disc colour};
            background-size: ${ctlDisc} ${ctlDisc}, ${ctlDisc} ${ctlDisc};
          }
        '') ctlClasses
      )}

      ${join (map (cls: "headerbar button.titlebutton.${cls} > image") ctlNames)} {
        min-width: 0;
        min-height: 0;
        padding: 0;
        margin: -1px;
        color: transparent;
        background: none;
        -gtk-icon-shadow: none;
      }

      headerbar > box.left {
        padding-left: 3px;
      }

      /* Chromium (Brave with Appearance -> Theme -> GTK) renders the rules
         above into its tab strip, through its own style path:
           window.background.csd > headerbar.header-bar.titlebar >
           windowcontrols > button.titlebutton.* > image
         Only that path has .header-bar and a windowcontrols node, so these
         reach Chromium alone. From its source (ui/gtk/nav_button_provider_gtk,
         browser_frame_view_layout_linux_native, opaque_browser_frame_view;
         checked against 152.0.7977.83, Brave 1.94) and measured:
         - the first button starts at the header bar's left padding + its own
           left margin;
         - between buttons: right margin + a fixed 6px + next left margin;
         - the tab strip is kept clear of the buttons by the *minimize*
           button's right margin (whatever the order); the first tab then
           overlaps that edge by 5px (measured: margins 20/40 put the tab 15/35
           past the last disc), and never starts closer than 3px.
         So the tab gap goes on minimize's right margin, and the button after
         it pulls back by the same amount to keep the 22px pitch. */
      window.background.csd > headerbar.header-bar.titlebar {
        padding-left: ${toString (ctlInset - 1)}px;
      }

      /* Chromium resolves -gtk-scaled() to the 1x glyph even when it renders
         the button at 2x, so the glyph came out soft; name the 2x file. */
      ${lib.concatStringsSep "\n\n" (
        lib.mapAttrsToList (cls: colour: ''
          ${join [ "headerbar.header-bar.titlebar windowcontrols ${btn "" cls ":hover:not(:backdrop)"}" "headerbar.header-bar.titlebar windowcontrols ${btn "" cls ":backdrop:hover"}" ]} {
            background-image: url("file://${glyphs}/${cls}@2.png"), ${disc colour};
            background-size: ${ctlDisc} ${ctlDisc}, ${ctlDisc} ${ctlDisc};
          }
        '') ctlClasses
      )}

      headerbar.header-bar.titlebar windowcontrols button.titlebutton.minimize${ctlBoost} {
        margin-right: ${toString (ctlTrailingGap + 5)}px;
      }

      headerbar.header-bar.titlebar windowcontrols button.titlebutton.maximize${ctlBoost} {
        margin-left: ${toString (2 - (ctlTrailingGap + 5))}px;
      }
    '';

  # Apps that draw their own window buttons get the same traffic lights through
  # their own styling hooks. Geometry as everywhere else: 14px discs, 8px gaps,
  # first disc 12px in, 12px before the app's own controls; grey when the
  # window is unfocused; the hovered disc lights up with its glyph.
  ctlPx = n: "${toString n}px";

  # Thunderbird, with its title bar hidden (user.js below) so it draws the
  # buttons itself; Gecko orders them by gtk-decoration-layout.
  thunderbirdProfile = config.thunderbird.profile;
  thunderbirdButtons = {
    close = ".titlebar-close";
    minimize = ".titlebar-min";
    maximize = ":is(.titlebar-max, .titlebar-restore)";
  };
  thunderbirdChrome = ''
    /* generated by home/theme.nix */
    .titlebar-buttonbox {
      align-items: center !important;
      gap: 8px !important;
      padding-inline: ${ctlPx ctlInset} !important;
    }
    .titlebar-button {
      appearance: none !important;
      padding: 0 !important;
      margin: 0 !important;
      width: ${ctlDisc} !important;
      height: ${ctlDisc} !important;
      min-width: ${ctlDisc} !important;
      min-height: ${ctlDisc} !important;
      border: none !important;
      border-radius: 50% !important;
      background: ${ctlIdle} no-repeat center / ${ctlDisc} ${ctlDisc} !important;
    }
    @media (prefers-color-scheme: dark) {
      .titlebar-button {
        background-color: #${dark.controlIdle} !important;
      }
    }
    .titlebar-button > .toolbarbutton-icon {
      display: none !important;
    }
    ${lib.concatStrings (
      lib.mapAttrsToList (cls: sel: ''
        :root:not(:-moz-window-inactive) ${sel}, ${sel}:hover {
          background-color: ${ctlClasses.${cls}} !important;
        }
        ${sel}:hover {
          background-image: url("file://${glyphs}/${cls}.svg") !important;
        }
      '') thunderbirdButtons
    )}
  '';

  # Obsidian, with its default hidden frame: its buttons move to the top left
  # and Obsidian's own macOS hook (--frame-left-space, the no-drag strip it
  # reserves) makes room. Its top-left ribbon corner is a drag region by
  # default, which swallowed hover and clicks on the first two discs.
  obsidianVault = "Documents/Obsidian/Personal";
  obsidianButtons = {
    close = ".mod-close";
    minimize = ".mod-minimize";
    maximize = ".mod-maximize";
  };
  obsidianSnippet =
    let
      frame = "body.mod-linux.is-hidden-frameless";
      box = "${frame} .titlebar-button-container.mod-right";
    in
    ''
      /* generated by home/theme.nix */
      ${frame} {
        --frame-right-space: 0px;
        --frame-left-space: ${ctlPx (ctlInset + 3 * 14 + 2 * 8 + ctlTrailingGap)};
      }
      ${frame} .sidebar-toggle-button.mod-left {
        left: var(--frame-left-space);
      }
      ${frame} .workspace-ribbon.mod-left::before {
        -webkit-app-region: no-drag;
      }
      ${box} {
        left: 0;
        right: auto;
        height: var(--header-height);
        padding-inline-start: ${ctlPx ctlInset};
        gap: 8px;
        display: flex;
        align-items: center;
      }
      ${box} .titlebar-button {
        width: ${ctlDisc};
        height: ${ctlDisc};
        min-width: ${ctlDisc};
        padding: 0;
        margin: 0;
        border-radius: 50%;
        background: ${ctlIdle} no-repeat center / ${ctlDisc} ${ctlDisc};
      }
      body.theme-dark${lib.removePrefix "body" box} .titlebar-button {
        background-color: #${dark.controlIdle};
      }
      ${box} .titlebar-button > svg {
        display: none;
      }
      ${box} .titlebar-button.mod-close {
        order: -1;
      }
      ${lib.concatStrings (
        lib.mapAttrsToList (cls: sel: ''
          body.is-focused${lib.removePrefix "body" box} .titlebar-button${sel}, ${box} .titlebar-button${sel}:hover {
            background-color: ${ctlClasses.${cls}};
          }
          ${box} .titlebar-button${sel}:hover {
            background-image: url("${glyphDataUri cls}");
          }
        '') obsidianButtons
      )}
    '';

  # theme-follow: keeps everything that cannot read the colour scheme itself in
  # step with it. Started once per Hyprland session (hyprland/startup.nix);
  # applies the current appearance, then again on every change.
  xsettingsConf = p: ''
    Net/ThemeName "${p.gtkTheme}"
    Net/IconThemeName "${p.iconTheme}"
    Gtk/CursorThemeName "Capitaine Cursors - White"
    Net/EnableEventSounds 1
    EnableInputFeedbackSounds 0
    Xft/Antialias 1
    Xft/Hinting 1
    Xft/HintStyle "hintslight"
    Xft/RGBA "rgb"
  '';
  applyAppearance = mode: p: ''
    ${mode})
      want_gtk="'${p.gtkTheme}'"
      want_icons="'${p.iconTheme}'"
      xsettings=${pkgs.writeText "xsettingsd-${mode}.conf" (xsettingsConf p)}
      ;;
  '';
  themeFollow = pkgs.writeShellApplication {
    name = "theme-follow";
    runtimeInputs = [ pkgs.dconf pkgs.procps pkgs.coreutils ];
    text = ''
      key=/org/gnome/desktop/interface

      apply() {
        mode=light
        [ "$(dconf read "$key/color-scheme")" = "'prefer-dark'" ] && mode=dark
        case $mode in
        ${applyAppearance "dark" dark}
        ${applyAppearance "light" light}
        esac

        # GTK3 and icons on Wayland, from dconf
        [ "$(dconf read "$key/gtk-theme")" = "$want_gtk" ] || dconf write "$key/gtk-theme" "$want_gtk"
        [ "$(dconf read "$key/icon-theme")" = "$want_icons" ] || dconf write "$key/icon-theme" "$want_icons"

        # X11 apps, through xsettingsd
        conf=''${XDG_CONFIG_HOME:-$HOME/.config}/xsettingsd/xsettingsd.conf
        mkdir -p "$(dirname "$conf")"
        cat "$xsettings" > "$conf"
        pkill -HUP -x xsettingsd || true
        echo "theme-follow: $mode"
      }

      apply
      # dconf watch prints the key's path, then its new value, then a blank line
      dconf watch "$key/color-scheme" | while IFS= read -r line; do
        case $line in
        "" | /*) ;;
        *)
          apply
          # Title bars and window borders: hyprland.lua reads the scheme when
          # it loads. A reload rather than setting the colours directly,
          # because hyprbars only re-renders title text on a reload.
          if [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
            hyprctl reload >/dev/null || true
          fi
          ;;
        esac
      done
    '';
  };

  # WhiteSur draws switches as a vertical gradient with an inset shadow (and
  # animates a second gradient when toggled); macOS switches are one flat
  # color. Grey when off or in an unfocused window, the accent when on.
  flatSwitchCss = { fg, accent }: ''
    switch,
    switch:disabled {
      background-image: none;
      background-color: alpha(${fg}, 0.15);
      box-shadow: none;
    }
    switch:disabled {
      background-color: alpha(${fg}, 0.08);
    }
    switch:checked {
      animation: none;
      background-image: none;
      background-color: ${accent};
      box-shadow: none;
    }
    switch:checked:disabled {
      background-image: none;
      background-color: alpha(${accent}, 0.5);
    }
    switch:checked:backdrop {
      background-image: none;
      background-color: alpha(${fg}, 0.35);
    }
  '';

  # Nautilus with Finder's proportions, on top of WhiteSur: 13px names, grey
  # secondary text, a path without its grey field, list selection in the
  # accent colour, a grey status bar. Sidebar and list contents are patched in
  # pkgs/nautilus.nix.
  nautilusCss = ''
    .nautilus-window {
      --files-label: rgba(0, 0, 0, 0.85);
      --files-secondary: rgba(0, 0, 0, 0.5);
      --files-tertiary: rgba(0, 0, 0, 0.25);
      --files-separator: rgba(0, 0, 0, 0.1);
      --files-plate: rgba(0, 0, 0, 0.07);
      --files-accent: #0a64e1;
      --files-selected: rgba(0, 0, 0, 0.1);
      --files-sidebar-selected: rgba(0, 0, 0, 0.09);
      --files-bar: rgba(246, 246, 247, 0.95);
    }
    @media (prefers-color-scheme: dark) {
      .nautilus-window {
        --files-label: rgba(255, 255, 255, 0.86);
        --files-secondary: rgba(255, 255, 255, 0.55);
        --files-tertiary: rgba(255, 255, 255, 0.28);
        --files-separator: rgba(255, 255, 255, 0.1);
        --files-plate: rgba(255, 255, 255, 0.1);
        --files-accent: #0a5ad2;
        --files-selected: rgba(255, 255, 255, 0.14);
        --files-sidebar-selected: rgba(255, 255, 255, 0.11);
        --files-bar: rgba(44, 44, 47, 0.95);
      }
    }

    /* Sidebar: 28px rows and 13px names, without the "Files" title. */
    .nautilus-window .sidebar-pane headerbar windowtitle {
      opacity: 0;
    }
    .nautilus-window placessidebar .navigation-sidebar {
      padding: 0 10px 10px;
    }
    .nautilus-window placessidebar .navigation-sidebar > row {
      min-height: 28px;
      padding: 0 8px;
      border-radius: 6px;
    }
    .nautilus-window placessidebar .navigation-sidebar > row + row {
      margin-top: 0;
    }
    .nautilus-window placessidebar .navigation-sidebar > separator {
      margin: 6px 0;
    }
    .nautilus-window placessidebar .navigation-sidebar > row label {
      font-size: 13px;
    }
    .nautilus-window placessidebar .navigation-sidebar > row:selected {
      background-color: var(--files-sidebar-selected);
    }

    /* Path: no grey field; parent folders grey, the open one in the label
       colour, quiet separators. Nautilus sets the names bold itself (Pango
       attributes), which CSS can't undo. */
    .nautilus-window .nautilus-pathbar {
      background: none;
      box-shadow: none;
    }
    .nautilus-window .nautilus-path-button {
      margin: 0;
      padding: 0 5px;
      border-radius: 6px;
    }
    .nautilus-window .nautilus-path-button label {
      font-size: 13px;
    }
    .nautilus-window .nautilus-path-button:not(.current-dir) label,
    .nautilus-window .nautilus-path-button:not(.current-dir) image {
      color: var(--files-secondary);
      opacity: 1;
    }
    .nautilus-window .nautilus-path-button.current-dir label {
      color: var(--files-label);
    }
    .nautilus-window .nautilus-pathbar box > label {
      color: var(--files-tertiary);
      opacity: 1;
      margin: 0 1px;
    }

    /* List: 13px names in Finder's row height, over WhiteSur's stripes;
       sizes and dates grey; small column titles. */
    .nautilus-window .nautilus-list-view columnview > listview {
      border-spacing: 0;
      padding-top: 2px;
    }
    .nautilus-window .nautilus-list-view columnview > listview > row {
      border-radius: 6px;
    }
    .nautilus-window .nautilus-list-view columnview > listview > row > cell > widget#NautilusViewCell {
      padding-top: 2px;
      padding-bottom: 2px;
    }
    .nautilus-window .nautilus-list-view columnview > listview > row label {
      font-size: 13px;
    }
    .nautilus-window .nautilus-list-view columnview > listview > row > cell:not(:first-child) label {
      color: var(--files-secondary);
    }
    .nautilus-window .nautilus-list-view columnview > header > button {
      padding-top: 3px;
      padding-bottom: 3px;
      box-shadow: none;
    }
    .nautilus-window .nautilus-list-view columnview > header > button label {
      font-size: 11px;
      font-weight: 600;
      color: var(--files-secondary);
    }

    /* Selection in the accent colour while the window has focus, grey
       otherwise. Nautilus pins its views' accent to grey (#959595). */
    .nautilus-window .nautilus-list-view columnview > listview.view > row.activatable:selected,
    .nautilus-window .nautilus-list-view columnview > listview.view > row.activatable:selected:hover {
      background-color: var(--files-accent);
      background-image: none;
    }
    .nautilus-window .nautilus-list-view columnview > listview.view > row.activatable:selected label,
    .nautilus-window .nautilus-list-view columnview > listview > row:selected > cell:not(:first-child) label {
      color: #ffffff;
    }
    .nautilus-window .nautilus-list-view columnview > listview.view > row.activatable:selected:backdrop {
      background-color: var(--files-selected);
    }
    .nautilus-window .nautilus-list-view columnview > listview.view > row.activatable:selected:backdrop label,
    .nautilus-window .nautilus-list-view columnview > listview > row:selected:backdrop > cell:not(:first-child) label {
      color: var(--files-label);
    }

    /* Grid: 12px names; the selection stays WhiteSur's. */
    .nautilus-window .nautilus-grid-view gridview > child label {
      font-size: 12px;
    }

    /* The "selected" bar: grey instead of the accent. */
    .nautilus-window .floating-bar {
      margin: 8px;
      padding: 0 4px;
      border-radius: 7px;
      background-color: var(--files-bar);
      color: var(--files-secondary);
      box-shadow: 0 0 0 1px var(--files-separator), 0 2px 8px rgba(0, 0, 0, 0.08);
    }
    .nautilus-window .floating-bar label {
      font-size: 12px;
    }
  '';

  # macOS order, on the left. GTK3, GTK4/libadwaita and Chromium/Electron all
  # read this one setting; the trailing colon means "nothing on the right".
  decorationLayout = "close,minimize,maximize:";

  # Inter is the closest thing to SF Pro that is already in the font set.
  # NB: the old setting was "Adwaita Sans", which is not installed here at all —
  # fontconfig had been quietly resolving it to Noto Sans.
  uiFont = {
    name = "Inter";
    size = 11;
  };
in
{
  gtk = {
    enable = true;
    font = uiFont;
    # settings.ini fallbacks only: on Wayland GTK reads the live names from
    # org.gnome.desktop.interface, which theme-follow keeps in step
    iconTheme = {
      name = light.iconTheme;
      package = iconTheme;
    };

    # GTK2/GTK3 load the theme by name out of the package (both appearances).
    theme = {
      name = light.gtkTheme;
      package = whitesur;
    };

    # GTK3 apps name the same widgets differently; same rules, other nodes.
    gtk3.extraCss = trafficLightCss3 + flatSwitchCss {
      fg = "@theme_fg_color";
      accent = "@theme_selected_bg_color";
    };

    gtk3.extraConfig = {
      gtk-decoration-layout = decorationLayout;
      gtk-xft-antialias = 1;
      gtk-xft-hinting = 1;
      gtk-xft-hintstyle = "hintslight";
      gtk-xft-rgba = "rgb";
    };

    # package = null on purpose: home-manager would otherwise write an
    # `@import` of the theme's gresource stub into gtk.css, which resolves to
    # nothing in a libadwaita process (see pkgs/whitesur-libadwaita.nix). The
    # name still goes into settings.ini for plain (non-Adwaita) GTK4 apps.
    gtk4.theme = {
      name = light.gtkTheme;
      package = null;
    };

    gtk4.extraConfig = {
      gtk-decoration-layout = decorationLayout;
    };

    # This is what actually themes Nautilus & friends, traffic lights included.
    # GTK applies @import inside a matching @media only, and re-parses the file
    # when the colour scheme changes, so both appearances live in one gtk.css.
    gtk4.extraCss = ''
      @media (prefers-color-scheme: light) {
        @import url("file://${whitesur}/libadwaita/gtk.css");
      }
      @media (prefers-color-scheme: dark) {
        @import url("file://${whitesur}/libadwaita/gtk-dark.css");
      }

      ${trafficLightCss}

      ${flatSwitchCss { fg = "@window_fg_color"; accent = "@accent_bg_color"; }}

      /* Finder-style sidebar: outline icons carrying the accent colour.
         WhiteSur ships this for the pre-50 sidebar (row.sidebar-row
         .sidebar-icon); Nautilus 50 rebuilt the row, so it no longer matched.
         :first-child skips the eject button's and the status icons. */
      placessidebar .navigation-sidebar > row > revealer > box > image:first-child {
        color: #${light.sidebarIcon};
      }
      @media (prefers-color-scheme: dark) {
        placessidebar .navigation-sidebar > row > revealer > box > image:first-child {
          color: #${dark.sidebarIcon};
        }
      }

      ${nautilusCss}
    '';
    # no gtk.colorScheme: it pins gtk-interface-color-scheme in settings.ini
  };

  # GNOME apps read these from dconf. color-scheme, gtk-theme and icon-theme are
  # deliberately not declared: they change at runtime, and declaring them
  # would reset the desktop to one appearance on every rebuild.
  dconf.settings."org/gnome/desktop/interface" = {
    font-name = "${uiFont.name} ${toString uiFont.size}";
  };

  home.packages = [ themeFollow ];
  home.file.".thunderbird/${thunderbirdProfile}/chrome/userChrome.css".text = thunderbirdChrome;
  home.file.".thunderbird/${thunderbirdProfile}/user.js".text = ''
    // generated by home/theme.nix
    user_pref("mail.tabs.drawInTitlebar", true);
    user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
  '';

  home.file."${obsidianVault}/.obsidian/snippets/traffic-lights.css".text = obsidianSnippet;
  # Obsidian keeps enabled snippets next to its other appearance settings, so
  # add ours to that list rather than owning the file.
  home.activation.obsidianTrafficLights = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    f="$HOME/${obsidianVault}/.obsidian/appearance.json"
    if [ -f "$f" ] && ! ${pkgs.jq}/bin/jq -e '(.enabledCssSnippets // []) | index("traffic-lights")' "$f" >/dev/null; then
      tmp=$(mktemp)
      ${pkgs.jq}/bin/jq '.enabledCssSnippets = ((.enabledCssSnippets // []) + ["traffic-lights"])' "$f" > "$tmp"
      run mv "$tmp" "$f"
    fi
  '';

  dconf.settings."org/gnome/desktop/wm/preferences" = {
    button-layout = decorationLayout;
  };

  # hyprland/hyprland.nix picks the hyprbars and border colours from the same
  # palette at config load; theme-follow updates them live.
}
