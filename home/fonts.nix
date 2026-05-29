{ pkgs, ... }:
{
  home.packages = with pkgs; [
    google-fonts
    font-awesome
  ];

  fonts.fontconfig = {
    enable = true;
    defaultFonts = {
      sansSerif = [ "Quicksand" ];
      monospace = [ "DejaVu Sans Mono" ];
    };
  };
}
