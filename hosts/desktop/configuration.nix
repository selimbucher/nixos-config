{ pkgs, ... }:

{
  imports = [
    ../../options.nix
    ./hardware-configuration.nix
    ../../common.nix
  ];
  
  deviceConfig.sddmWayland = false;
  deviceConfig.monitor = ["DP-3, 2560x1440@240, 0x0, 1.25, bitdepth, 10"];
  networking.hostName = "desktop";
  extraExecOnce = [
    "steam -silent"
  ];
}