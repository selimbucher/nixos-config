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
  ];

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.permittedInsecurePackages = [
    "pnpm-10.29.2"
  ];

  programs.nix-ld.enable = true;

  # rEFInd (on the ESP) chainloads systemd-boot; timeout 0 = invisible.
  boot.loader.timeout = 0;
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 5; # keep the ESP from filling up
  };
  # false: bootctl must not put itself ahead of rEFInd in the boot order
  boot.loader.efi.canTouchEfiVariables = false;

  # Per-machine ESP fixups so a fresh device needs no manual bootloader work:
  # bootctl silently skips installing the loader binary when a foreign EFI/BOOT
  # fallback exists, and rEFInd would list the raw kernels in EFI/nixos as
  # (initrd-less, panicking) boot entries.
  boot.loader.systemd-boot.extraInstallCommands = ''
    esp="${config.boot.loader.efi.efiSysMountPoint}"
    ${pkgs.coreutils}/bin/mkdir -p "$esp/EFI/systemd"
    ${pkgs.coreutils}/bin/cp \
      ${config.systemd.package}/lib/systemd/boot/efi/systemd-bootx64.efi \
      "$esp/EFI/systemd/systemd-bootx64.efi"
    conf="$esp/EFI/refind/refind.conf"
    if [ -f "$conf" ]; then
      if ${pkgs.gnugrep}/bin/grep -q '^dont_scan_dirs' "$conf"; then
        ${pkgs.gnused}/bin/sed -i \
          '/^dont_scan_dirs/{/EFI\/nixos/!s|$|,EFI/nixos|}' "$conf"
      else
        echo 'dont_scan_dirs EFI/nixos' >> "$conf"
      fi
    fi
  '';

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
      "default.clock.min-quantum" = 64;
      "default.clock.max-quantum" = 256;
      "default.clock.force-quantum" = config.deviceConfig.jackBufferSize;
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
  ];

  services.xserver.excludePackages = [ pkgs.xterm ];

  security.polkit.enable = true;

  programs.steam.enable = true;

  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  system.stateVersion = "25.11";
}
