{ pkgs, ... }:
{
  home.packages = with pkgs; [
    yabridge
    yabridgectl
    wineWowPackages.staging
    winetricks
    protontricks
  ];
}
