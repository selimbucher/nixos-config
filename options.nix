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

    extraExec = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional Hyprland exec entries for this device.";
    };

    extraExecOnce = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional Hyprland exec-once entries for this device.";
    };

    blur = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to enable Hyprland window blur.";
    };

    shadow = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to enable Hyprland window shadows.";
    };

    scale = lib.mkOption {
      type = lib.types.float;
      default = 1.0;
      description = "Monitor scale factor for HiDPI scaling (e.g. 2.0 for HiDPI).";
    };

  };
}