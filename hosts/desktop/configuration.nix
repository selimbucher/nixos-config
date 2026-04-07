{ pkgs, ... }:

{
  imports = [
    ../../options.nix
    ./hardware-configuration.nix
    ../../common.nix
  ];
  
  networking.hostName = "desktop";
  deviceConfig = {
    sddmWayland = false;
    monitor = [
      "DP-2, 2560x1440@240, 0x0, 1.25, bitdepth, 10"
      "DP-3, 2560x1440@240, 2048x0, 1.25, bitdepth, 10"
      ];
    blur = true;
    extraExecOnce = [
      "steam -silent"
    ];
    scale = 1.25;
  };
}