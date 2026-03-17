{ lib, ... }: {
  options.deviceConfig = {
    
    monitor = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Hyprland monitor strings for this device.";
    };

    sddmWayland = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to use Wayland for the SDDM greeter.";
    };

  };
}
