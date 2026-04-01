{ pkgs, ... }:

{
  imports = [
    ../../options.nix
    ./hardware-configuration.nix  # The hardware scan you just moved
    ../../common.nix             # Your shared settings
  ];

  networking.hostName = "laptop"; # Unique name for this machine
  deviceConfig.monitor = [
    "eDP-1, 2880x1800@120, 0x0, 2, bitdepth, 10"
    "HDMI-A-1, 2560x1440@60, -304x-1152, 1.25"
    "DP-1, 3840x2160@30, 1440x0, 2"
  ];
  deviceConfig.blur = false;
}