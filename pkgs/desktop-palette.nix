# Colours of the desktop chrome in each appearance, shared by the GTK CSS, the
# hyprbars config and the theme follower (home/theme.nix). Hex without '#', so
# CSS (#rrggbb) and Hyprland (rgb()/rgba()) can both use them.
#
# The appearance itself is picked at runtime: org.gnome.desktop.interface
# color-scheme (kiwi-shell's theme tab sets it), and everything follows.
{
  light = {
    gtkTheme = "WhiteSur-Light";
    # WhiteSur names icon variants for the background they sit on
    iconTheme = "WhiteSur-light";
    headerbar = "f6f6f6";
    title = "4d4d4d";
    # unfocused traffic lights: WhiteSur's titlebutton-*-backdrop assets
    controlIdle = "cecece";
    borderActive = "00000026";
    borderInactive = "00000014";
    sidebarIcon = "0a64e1";
  };
  dark = {
    gtkTheme = "WhiteSur-Dark";
    iconTheme = "WhiteSur-dark";
    # WhiteSur-Dark's libadwaita header bar, rendered and sampled
    headerbar = "2e2e32";
    title = "e8e8e8";
    controlIdle = "5d5d5d";
    borderActive = "ffffff1f";
    borderInactive = "ffffff0f";
    sidebarIcon = "3d8bff";
  };
}
