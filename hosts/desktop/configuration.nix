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
      { output = "DP-2";     mode = "2560x1440@240"; position = "0x0";    scale = "1.25"; bitdepth = 10; }
      { output = "DP-3";     mode = "2560x1440@240"; position = "2048x0"; scale = "1.25"; bitdepth = 10; }
      { output = "HDMI-A-1"; mode = "3840x2160@60";  position = "4096x0"; scale = "1"; }
    ];
    blur = true;
    extraExecOnce = [
      "steam -silent"
    ];
    scale = 1.25;
    jackBufferSize = 64;
  };
}