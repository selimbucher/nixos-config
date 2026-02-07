{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix  # The hardware scan you just moved
    ../../common.nix             # Your shared settings
  ];

  networking.hostName = "laptop"; # Unique name for this machine
  
  # You can add laptop-specific settings here if you want
  # e.g., services.thermald.enable = true;
}