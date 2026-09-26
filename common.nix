# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, inputs, ... }:

{
  imports = [ inputs.qylock.nixosModules.default ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
  nix.optimise.automatic = true; # dedupe the store via hardlinks

  nixpkgs.overlays = [
    (final: prev: {
      pkgsi686Linux = prev.pkgsi686Linux.extend (final': prev': {
        openldap = prev'.openldap.overrideAttrs (_: { doCheck = false; });
      });
    })
    inputs.claude-code-nix.overlays.default
    # Nautilus with larger icons at its smallest zoom steps and without Recent
    # and Starred (pkgs/nautilus.nix); an overlay rather than a systemPackages
    # override so the D-Bus-activated copy is the same one.
    (final: prev: {
      nautilus = final.callPackage ./pkgs/nautilus.nix { inherit (prev) nautilus; };
    })
    # Brave with its GTK theme and custom frame pinned (pkgs/brave.nix)
    (final: prev: {
      brave = final.callPackage ./pkgs/brave.nix { inherit (prev) brave; };
    })
  ] ++ lib.optional config.deviceConfig.wineFork
    (import ./overlays/yabridge-wine11.nix { inherit inputs; });

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.permittedInsecurePackages = [
    "pnpm-10.29.2"
  ];

  programs.nix-ld.enable = true;

  # Plain systemd-boot, invisible (timeout 0; hold Space for the generation
  # menu). Boots standalone via the EFI/BOOT fallback on a fresh machine; if
  # rEFInd is installed on the ESP it detects systemd-boot and acts as the
  # visible menu in front (add `dont_scan_dirs EFI/nixos` to refind.conf so it
  # doesn't also list the raw kernels).
  boot.loader.timeout = 0;
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 5; # keep the ESP from filling up
    # bootctl over varlink (systemd 261 / nixpkgs 26.11) is no longer
    # graceful-by-default on update, so the rEFInd-owned EFI/BOOT fallback
    # ("no version info found" -> ESRCH) hard-fails the switch without this.
    graceful = true;
  };
  # Never reorder EFI boot entries (rEFInd must stay first where it exists).
  boot.loader.efi.canTouchEfiVariables = false;

  services.xserver = {
    enable = true;
    xkb.layout = "ch";
    xkb.variant = "";
    desktopManager.xterm.enable = false;
  };

  services.displayManager = {
    enable = true;
    sddm = {
      enable = true;
      wayland.enable = config.deviceConfig.sddmWayland;
      # weston never shows the cursor (i915 cursor-plane issue); kwin does
      wayland.compositor = "kwin";
      enableHidpi = true;
      # greeter cursor; without an explicit theme SDDM shows none
      settings.Theme = {
        CursorTheme = "Capitaine Cursors - White";
        CursorSize = 24;
      };
      extraPackages = with pkgs; [
        qt6.qt5compat
        qt6.qtdeclarative
        qt6.qtsvg
      ];
    };
  };

  programs.qylock = {
    enable = true;
    theme = "last-of-us";
    quickshell.enable = false;
  };

  # xcursor's default search path (/usr/share/icons) doesn't exist on NixOS
  systemd.services.display-manager.environment = {
    XCURSOR_PATH = "/run/current-system/sw/share/icons";
    XCURSOR_THEME = "Capitaine Cursors - White";
    XCURSOR_SIZE = "24";
  };

  boot.plymouth = {
    enable = true;
    theme = "spinner_alt";
    themePackages = [
      (pkgs.adi1090x-plymouth-themes.override {
        selected_themes = [ "spinner_alt" ];
      })
    ];
  };

  boot.consoleLogLevel = 0;
  boot.initrd.verbose = false;
  boot.kernelParams = [
    "quiet"
    "splash"
    "boot.shell_on_fail"
    "loglevel=3"
    "rd.systemd.show_status=false"
    "rd.udev.log_level=3"
    "udev.log_priority=3"
  ];

  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.networkmanager.enable = true;
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 53317 51413 ];
    allowedUDPPorts = [ 53317 51413 ];
  };
  networking.firewall.checkReversePath = false;
  networking.networkmanager.plugins = [ pkgs.networkmanager-openconnect ];

  time.timeZone = "Europe/Amsterdam";

  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "de_CH-latin1";
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Experimental = true;
        FastConnectable = false;
        # AirPods (and other Apple devices) periodically re-key their
        # Just-Works pairing; the default "never" makes bluez refuse the
        # re-pair and silently drop the bond (device flips to Paired: no).
        JustWorksRepairing = "always";
      };
      Policy.AutoEnable = true;
    };
  };

  services.printing.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
    jack.enable = true;
  };

  services.pipewire.extraConfig.pipewire."92-low-latency" = {
    "context.properties" = {
      "default.clock.rate" = 48000;
      "default.clock.quantum" = config.deviceConfig.jackBufferSize;
      "default.clock.min-quantum" = config.deviceConfig.jackBufferSize;
      # max-quantum IS the pin: default.clock.force-quantum is NOT a config
      # property (runtime metadata only — pipewire silently ignores it here;
      # verified 2026-08-17 when vesktop's 512-sample request dragged the
      # graph to 256 and brought the M4 follower-resync dropouts back).
      # min = max = jackBufferSize means no client request can move it.
      "default.clock.max-quantum" = config.deviceConfig.jackBufferSize;
    };
  };

  security.rtkit.enable = true;
  security.pam.loginLimits = [
    { domain = "@audio"; item = "memlock"; type = "-"; value = "unlimited"; }
    { domain = "@audio"; item = "rtprio";  type = "-"; value = "99"; }
    { domain = "@audio"; item = "nice";    type = "-"; value = "-20"; }
  ];

  services.flatpak.enable = true;
  services.libinput.enable = true;

  virtualisation.docker = {
    enable = true;
    enableOnBoot = false; # starts on first use; restart=always containers won't autostart
  };
  # rootless containers for distro packaging work (rpmbuild/debuild chroots);
  # no dockerCompat — real docker above owns the `docker` command
  virtualisation.podman.enable = true;

  # don't block boot ~4.5s waiting for the network
  systemd.services.NetworkManager-wait-online.enable = false;

  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  services.gvfs.enable = true;

  services.gnome.evolution-data-server.enable = true;
  services.gnome.gnome-keyring.enable = true;
  programs.dconf.enable = true;
  programs.gnome-disks.enable = true;

  users.users.selim = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" "networkmanager" "video" "audio" ];
    packages = with pkgs; [ tree ];
    initialPassword = "1234";
    shell = pkgs.zsh;
  };

  programs.zsh.enable = true;

  # kiwi-settings looks up kiwi-shell's included wallpapers through the XDG
  # data dirs, and nothing links /share/kiwi-shell into the profile by default
  environment.pathsToLink = [ "/share/kiwi-shell" ];

  environment.systemPackages = with pkgs; [
    git
    kitty
    wl-clipboard
    wl-clip-persist
    nautilus
    slurp
    grim
    brightnessctl
    mission-center
    capitaine-cursors-themed # cursor theme for the SDDM greeter
    gvfs
    nautilus
    brave
    gnupg
  ];

  services.xserver.excludePackages = [ pkgs.xterm ];

  security.polkit.enable = true;

  # GUI password prompt for terminal-less sudo (agent shells, scripts): sudo
  # automatically falls back to the askpass helper from sudo.conf when it has
  # no TTY to prompt on. Styled after the hyprlock input pill (dimaround layer
  # rule lives in home/hyprland/hyprland.nix).
  environment.etc."sudo.conf".text =
    let
      theme = pkgs.writeText "sudo-askpass.rasi" ''
        * {
          font: "Quicksand Medium 15";
          background-color: transparent;
          text-color: rgba(255, 255, 255, 100%);
        }
        window {
          transparency: "real";
          location: center;
          anchor: center;
          width: 20%;
          border-radius: 100px;
          background-color: rgba(255, 255, 255, 14%);
          padding: 16px 28px;
        }
        mainbox { children: [ "inputbar" ]; }
        inputbar {
          children: [ "entry" ];
          background-color: transparent;
        }
        entry {
          background-color: transparent;
          placeholder: "Enter Password";
          placeholder-color: rgba(255, 255, 255, 55%);
          blink: true;
        }
        listview { enabled: false; }
        message { enabled: false; }
        mode-switcher { enabled: false; }
      '';
      askpass = pkgs.writeShellScript "sudo-askpass" ''
        # runs as the invoking user; agent/cron shells often lack the Wayland
        # session env, so recover it from the runtime dir
        export XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
        if [ -z "''${WAYLAND_DISPLAY:-}" ]; then
          for s in "$XDG_RUNTIME_DIR"/wayland-*; do
            [ -S "$s" ] || continue
            WAYLAND_DISPLAY="''${s##*/}"
            break
          done
          export WAYLAND_DISPLAY
        fi
        exec ${pkgs.rofi}/bin/rofi -dmenu -password -p "" -theme ${theme} < /dev/null
      '';
    in
    "Path askpass ${askpass}\n";

  programs.steam.enable = true;

  programs.gamemode.enable = true;

  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  system.stateVersion = "25.11";
}
