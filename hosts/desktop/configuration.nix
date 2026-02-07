{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix  # The hardware scan you just moved
    ../../common.nix             # Your shared settings
  ];

  networking.hostName = "desktop"; # Unique name for this machine
}