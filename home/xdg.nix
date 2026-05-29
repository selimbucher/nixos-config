{ inputs, pkgs, ... }:
{
  xdg.enable = true;
  xdg.mime.enable = true;

  xdg.configFile."rofi" = {
    source = inputs.rofi-theme;
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config = {
      common.default = [ "gtk" ];
      hyprland.default = [ "hyprland" "gtk" ];
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
