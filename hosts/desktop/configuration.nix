{ pkgs, ... }:

{
  imports = [
    ../../options.nix
    ./hardware-configuration.nix
    ../../common.nix
  ];
  
  networking.hostName = "desktop";

  deviceConfig = {
    monitor = [
      "DP-2, 2560x1440@240, 0x0, 1.25, bitdepth, 10"
      "DP-3, 2560x1440@240, 2048x0, 1.25, bitdepth, 10"
      "HDMI-A-1, 3840x2160@60, 4096x0, 1"
      ];
    blur = true;
    extraExecOnce = [
      "steam -silent"
    ];
    scale = 1.25;
    jackBufferSize = 64;
  };
}