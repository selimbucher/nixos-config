{ lib, ... }: {
  options.deviceConfig = {
    
    monitor = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
      default = [];
      example = [{
        output = "DP-2";
        mode = "2560x1440@240";
        position = "0x0";
        scale = "1.25";
        bitdepth = 10;
      }];
      description = ''
        Hyprland monitor specs for this device. One attrset per monitor,
        passed straight to hl.monitor() in the lua config — `output` is
        required, mode/position/scale are strings (they accept keywords
        like "preferred"/"auto" as well as literal values).
      '';
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

    jackBufferSize = lib.mkOption {
      type = lib.types.int;
      default = 128;
      description = "Buffer size for Jack.";
    };

  };
}