# WhiteSur's GTK4 stylesheet, built the way libadwaita can actually consume it.
#
# nixpkgs' whitesur-gtk-theme installs share/themes/<name>/gtk-4.0/gtk.css, but
# that file is a one-line `@import url("resource:///org/gnome/theme/gtk.css")`
# backed by a gresource that GTK only registers when it loads the theme by name.
# libadwaita apps (Nautilus, Geary, gnome-*) pin themselves to Adwaita and never
# load a named theme, so that resource is never registered and the import is a
# silent no-op. Pointing ~/.config/gtk-4.0/gtk.css at it — which is what nwg-look
# does — therefore themes nothing.
#
# Upstream's real libadwaita path is `install.sh --libadwaita`: it runs the sass
# straight to a ~283 KB plain CSS file and drops it next to assets/ and
# windows-assets/ (the traffic-light PNGs). The CSS references those with
# *relative* urls, so the whole directory has to stay together — hence a
# derivation that captures the directory rather than a single file.
{
  lib,
  whitesur-gtk-theme,
  # the libadwaita bundle carries both appearances either way (gtk.css,
  # gtk-dark.css); this picks which one gtk.css is
  colorVariant ? "light", # light | dark
  opacityVariant ? "normal", # normal (96% headerbars/sidebars) | solid
  themeVariant ? "default", # accent colour
  nautilusStyle ? "stable", # BigSur-style full-height Finder sidebar
}:

let
  palette = import ./desktop-palette.nix;
in
(whitesur-gtk-theme.override {
  colorVariants = [ "light" "dark" ];
  opacityVariants = [ opacityVariant ];
  themeVariants = [ themeVariant ];
  inherit nautilusStyle;
}).overrideAttrs
  (old: {
    pname = "whitesur-libadwaita";

    installPhase = ''
      runHook preInstall

      # install.sh writes the libadwaita bundle to $HOME/.config/gtk-4.0 and the
      # named themes to --dest; we want both, from one sass run.
      export HOME="$TMPDIR/home"
      mkdir -p "$HOME"

      ./install.sh --libadwaita \
        --color ${colorVariant} \
        --opacity ${opacityVariant} \
        --theme ${themeVariant} \
        --nautilus ${nautilusStyle} \
        --dest "$TMPDIR/themes"

      # the GTK3 themes for the other appearance too, so the desktop can switch
      # between them at runtime without a rebuild
      ./install.sh \
        --color ${if colorVariant == "light" then "dark" else "light"} \
        --opacity ${opacityVariant} \
        --theme ${themeVariant} \
        --nautilus ${nautilusStyle} \
        --dest "$TMPDIR/themes"

      # -L: gtk.css is a symlink to gtk-Light.css inside the build tree
      mkdir -p $out/libadwaita $out/share/themes
      cp -rL "$HOME/.config/gtk-4.0/." $out/libadwaita/
      cp -rL "$TMPDIR/themes/." $out/share/themes/

      # The unfocused traffic-light grey per appearance, as a named colour the
      # user GTK3 CSS draws with (home/theme.nix). GTK3 CSS has no media
      # queries, but it re-resolves named colours when the theme switches.
      for css in $out/share/themes/WhiteSur-{Light,Dark}*/gtk-3.0/gtk{,-dark}.css; do
        [ -f "$css" ] || continue
        case $css in
          */WhiteSur-Dark*) idle=${palette.dark.controlIdle} ;;
          *) idle=${palette.light.controlIdle} ;;
        esac
        printf '\n@define-color traffic_light_idle #%s;\n' "$idle" >> "$css"
      done

      runHook postInstall
    '';
  })
