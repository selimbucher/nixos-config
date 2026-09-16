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
  # Flip this to "dark" to move the whole desktop over; everything below,
  # including the hyprbars colours in hyprland/hyprland.nix, keys off it.
  variant = "light";

  isLight = variant == "light";
  themeName = if isLight then "WhiteSur-Light" else "WhiteSur-Dark";

  # WhiteSur icon variants are named for the background they sit ON:
  # -dark ships #dedede symbolics (for dark panels), -light ships #363636.
  iconName = if isLight then "WhiteSur-light" else "WhiteSur-dark";

  whitesur = pkgs.callPackage ../pkgs/whitesur-libadwaita.nix {
    colorVariant = variant;
  };

  # hover glyphs shared with hyprbars (see home/hyprland/hyprland.nix)
  glyphs = pkgs.callPackage ../pkgs/titlebutton-glyphs.nix { };

  # Finder-style sidebar icons: outline glyphs in a muted blue. Mixing
  # libadwaita's accent (#3584e4) into the text colour read as cyan (hue 214°),
  # so this is a fixed colour instead: hue 222°, saturation 62%.
  sidebarIconColor = if isLight then "#3c599e" else "#88a1db";

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
  ctlIdle = "#cecece";

  # Shared with hyprbars: size 14, bar_button_padding 8 (4 each side),
  # bar_padding 12 = the headerbar's own 8px box padding + one 4px margin.
  ctlDisc = "14px";
  ctlHalfGap = "4px";

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

  # GTK3 has no -gtk-icon-size and its glyph is 16px, so the disc is a
  # fixed-size radial gradient centred on the button instead (3px margins:
  # 2 × 3 + the 2px the 16px box overhangs the disc = the same 8px gap).
  # Unverified: no GTK3 app with a header bar is installed to check against.
  trafficLightCss3 =
    let
      btn = bar: cls: st: "${bar} button.titlebutton.${cls}${st}${ctlBoost}";
      disc = colour: "radial-gradient(circle closest-side, ${colour} 6.5px, transparent 7px)";
    in
    ''
      ${join (lib.concatMap (cls: map (btn "headerbar" cls) ctlStates) ctlNames)} {
        background-color: transparent;
        background-image: ${disc ctlIdle};
        background-size: ${ctlDisc} ${ctlDisc};
        background-position: center;
        background-repeat: no-repeat;
        min-width: ${ctlDisc};
        min-height: ${ctlDisc};
        padding: 0;
        margin: 0 3px;
        border: none;
        box-shadow: none;
        -gtk-icon-shadow: none;
        transition: none;
      }

      ${lib.concatStringsSep "\n\n" (
        lib.mapAttrsToList (cls: colour: ''
          ${join (map (btn "headerbar:not(:backdrop)" cls) ctlLit)} {
            background-image: ${disc colour};
          }
        '') ctlClasses
      )}

      ${lib.concatStringsSep "\n\n" (
        lib.mapAttrsToList (cls: colour: ''
          ${join (map (btn "headerbar" cls) [ ":hover" ":backdrop:hover" ])} {
            background-image: -gtk-scaled(url("file://${glyphs}/${cls}.png"), url("file://${glyphs}/${cls}@2.png")), ${disc colour};
            background-size: ${ctlDisc} ${ctlDisc}, ${ctlDisc} ${ctlDisc};
          }
        '') ctlClasses
      )}

      ${join (map (cls: "headerbar button.titlebutton.${cls} > image") ctlNames)} {
        min-width: 0;
        min-height: 0;
        padding: 0;
        margin: 0;
        color: transparent;
        background: none;
        -gtk-icon-shadow: none;
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
    iconTheme = {
      name = iconName;
      package = iconTheme;
    };

    # GTK2/GTK3 load the theme by name out of the package.
    theme = {
      name = themeName;
      package = whitesur;
    };

    # GTK3 apps name the same widgets differently; same rules, other nodes.
    gtk3.extraCss = trafficLightCss3;

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
      name = themeName;
      package = null;
    };

    gtk4.extraConfig = {
      gtk-decoration-layout = decorationLayout;
    };

    # This is what actually themes Nautilus & friends, traffic lights included.
    gtk4.extraCss = ''
      @import url("file://${whitesur}/libadwaita/gtk.css");

      ${trafficLightCss}

      /* Finder-style sidebar: outline icons carrying the accent colour.
         WhiteSur ships this for the pre-50 sidebar (row.sidebar-row
         .sidebar-icon); Nautilus 50 rebuilt the row, so it no longer matched.
         :first-child skips the eject button's and the status icons. */
      placessidebar .navigation-sidebar > row > revealer > box > image:first-child {
        color: ${sidebarIconColor};
      }
    '';

    colorScheme = variant;
  };

  # A libadwaita app that is asked to go dark anyway still gets WhiteSur.
  xdg.configFile."gtk-4.0/gtk-dark.css".text = ''
    @import url("file://${whitesur}/libadwaita/gtk-dark.css");
  '';

  # GNOME apps read these from dconf, not from settings.ini, and nwg-look had
  # left contradictory values here. Declaring them keeps the two in step.
  dconf.settings."org/gnome/desktop/interface" = {
    gtk-theme = themeName;
    icon-theme = iconName;
    font-name = "${uiFont.name} ${toString uiFont.size}";
    color-scheme = if isLight then "prefer-light" else "prefer-dark";
  };
  dconf.settings."org/gnome/desktop/wm/preferences" = {
    button-layout = decorationLayout;
  };

  # hyprland/hyprland.nix tints hyprbars off config.gtk.colorScheme (set just
  # above) so the title bars it draws track the GTK header bars automatically.
}
