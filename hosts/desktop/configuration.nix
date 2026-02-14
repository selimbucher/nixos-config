{ pkgs, ... }:

{
  imports = [
    ../../options.nix
    ./hardware-configuration.nix  # The hardware scan you just moved
    ../../common.nix             # Your shared settings
  ];
  
  deviceConfig.sddmWayland = false;
  deviceConfig.monitor = "DP-3, 2560x1440@240, 0x0, 1.25, bitdepth, 10";
  networking.hostName = "desktop"; # Unique name for this machine
}