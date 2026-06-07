{ inputs, pkgs, ... }:
{
  xdg.enable = true;
  xdg.mime.enable = true;

  xdg.configFile."rofi" = {
    source = inputs.rofi-theme;
  };

  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-hyprland
    ];
    config = {
      common = {
        default = [ "gtk" ]; # Forces all undefined portal requests to use GTK
        "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
      };
      hyprland = {
        default = [ "gtk" "hyprland" ];
      };
    };
  };

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    setSessionVariables = false;
    desktop   = "$HOME/Desktop";
    documents = "$HOME/Documents";
    download  = "$HOME/Downloads";
    music     = "$HOME/Music";
    pictures  = "$HOME/Pictures";
    templates = "$HOME/Templates";
    videos    = "$HOME/Videos";
  };
}
