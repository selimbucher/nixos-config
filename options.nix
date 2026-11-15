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

    luksRoot = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "d03d0fa1-9166-410f-9448-d5d2f2caa2f3";
      description = ''
        PARTUUID of a LUKS2 root partition. Stage 1 opens it with a FIDO2
        touch (modules/luks.nix); null means an unencrypted root.
      '';
    };

    yubikey = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        A YubiKey gates every way into the running system: hyprlock, the
        TTY login and the SDDM greeter (modules/yubikey.nix). passwordLogin
        and passwordLock add the password on top; they never replace the key.
      '';
    };

    battery = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        A device on battery: drain logging (modules/batlog.nix), idle
        timeouts (modules/idle.nix) and the lid/hibernate policy
        (modules/sleep.nix).
      '';
    };

    numberpad = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        An ASUS touchpad with the NumberPad LED grid (modules/numberpad.nix):
        SUPER+N lights it and turns taps into digits, on demand only.
      '';
    };

    mouseDpi = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      example = 3000;
      description = ''
        Hardware DPI for an MX Master 4 or 3S, set on every (re)connect
        (modules/logitech.nix). The pointer then runs flat 1:1, the
        touchpad flat at its own speed. null = Hyprland's default
        acceleration at sensitivity 0.5, no solaar.
      '';
    };

    hibernateAfter = lib.mkOption {
      type = lib.types.str;
      default = "30min";
      description = ''
        How long a battery device stays suspended before it hibernates,
        taking RAM and the disk key with it (modules/sleep.nix).
      '';
    };

    passwordLogin = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether the TTY login and the SDDM greeter ask for the password as
        well as the key, and SDDM shows the greeter at boot. Off = autologin:
        the disk unlock already was the key. Needs deviceConfig.yubikey.
      '';
    };

    passwordLock = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether hyprlock asks for the password as well as the key. Off =
        key only: the lock screen waits for a key and its touch, nothing to
        type. Needs deviceConfig.yubikey.
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

    uiFontSize = lib.mkOption {
      type = lib.types.int;
      default = 10;
      description = ''
        The interface font (Inter) in points: GTK, dconf and Emacs's UI
        faces. 10pt is 13.3px, macOS's 13pt system font; GNOME's 11pt is
        14.7px. A desk monitor sits an arm's length further away than a
        laptop's panel and wants a step more.
      '';
    };

    codeFontSize = lib.mkOption {
      type = lib.types.int;
      default = 9;
      description = ''
        The code font in points: kitty, the GTK monospace font, Emacs, and
        the size seeded into VS Code's settings.json (in px, 4/3 of this).
        9pt is 12px, VS Code's size on macOS.
      '';
    };

    wineFork = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Apply overlays/yabridge-wine11.nix: patched yabridge (master + ARA)
        on the patched d2d1-dcomp wine fork, which is also the wine on PATH.
        Uncached: a local ~1h wine + yabridge build on every nixpkgs bump.
        When false, everything is stock and cached: yabridge 5.1.1 on its
        pinned wine 9.21, and wineWow64Packages.staging on PATH.
      '';
    };

  };
}