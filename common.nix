# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ inputs, config, lib, pkgs, ... }:

{
  #imports =
  #  [ # Include the results of the hardware scan.
  #    ./hardware-configuration.nix
  #  ];
  
  nixpkgs.config.allowUnfree = true;
  # Enable flakes and new CLI
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
  # Enable  
  security.polkit.enable = true;
  

  # Use the systemd-boot EFI boot loader.
  # boot.loader.systemd-boot.enable = true;
  # boot.loader.efi.canTouchEfiVariables = true;
  
  boot.plymouth = {
    enable = true;
    theme = "loader_2"; # <--- Put your theme name here
    themePackages = [
      (pkgs.adi1090x-plymouth-themes.override {
        selected_themes = [ "loader_2" ]; # <--- AND here (saves 500MB of space)
      })
    ];
  };

  # 1. Hides the "Stage 1" / "Stage 2" messages
  boot.consoleLogLevel = 0;
  boot.initrd.verbose = false;

  # 2. The critical kernel parameters to hide text
  boot.kernelParams = [
    "quiet"
    "splash"
    "boot.shell_on_fail"
    "loglevel=3"
    "rd.systemd.show_status=false"
    "rd.udev.log_level=3"
    "udev.log_priority=3"
  ];
  
  boot.loader = {
    grub = {
      splashImage = null;
      forceInstall = false;
      backgroundColor = "#000000";
      enable = true;
      device = "nodev";
      efiSupport= true;
      useOSProber = false;
      theme = null;
    };
    timeout = 0;
  };
  boot.loader.efi.canTouchEfiVariables = true; 

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # networking.hostName = "nixOS"; # Define your hostname.
  
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
    ];
    
    config = {
      common = {
        default = [ "gtk" ];
      };
      hyprland = {
        default = [ "hyprland" "gtk" ];
      };
    };
    
  };

  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 53317 51413 47273];
    allowedUDPPorts = [ 53317 51413 47273];
  };
networking.firewall.checkReversePath = false;  

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  
  services.blueman.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Zurich";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "de_CH-latin1";
    # useXkbConfig = true; # use xkb.options in tty.
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  security.rtkit.enable = true;  # This is crucial for PipeWire

  services.pipewire = {
    enable = true;
    pulse.enable = true;
    alsa.enable = true;          # Add ALSA support
    alsa.support32Bit = true;    # Add 32-bit ALSA support
    wireplumber.enable = true;   # Ensure wireplumber is enabled
  };

  services.dbus.enable = true;  
  services.udisks2.enable = true;
  services.libinput.enable = true;
  services.gnome.tinysparql.enable = true;
  services.gnome.localsearch.enable = true;
  services.gvfs.enable = true;  # Virtual filesystem support for Nautilus
  services.upower.enable = true; # Required for AstalBattery
  services.power-profiles-daemon.enable = true;
  
  services.gnome.evolution-data-server.enable = true;
  # Keyring for storing passwords
  services.gnome.gnome-keyring.enable = true;
  
  users.users.selim = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video"]; # Enable ‘sudo’ for the user.
    initialPassword = "changeme";
    packages = with pkgs; [
      tree
    ];
  };
  # Home Manager is configured via the system flake (see /etc/nixos/flake.nix)

  programs.hyprland = {
    enable = true;
    withUWSM = true; # Keep if you use UWSM
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
};

  services.xserver.desktopManager.xterm.enable = false;
  services.xserver.excludePackages = [ pkgs.xterm ];

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  environment.systemPackages = with pkgs; [
    vulkan-hdr-layer-kwin6
    mesa-demos
    overskride 
    kitty
    wget
    git
    swww
    wl-clipboard
    wl-clip-persist
    nautilus
    gvfs
    gtk3
    brave
    slurp      # Select screen regions
    grim       # Take screenshots
    nautilus-python
    powertop

    hyprsunset
    
    hyprlock
    gnome-disk-utility    
    
    killall
    
    gnome-calculator
    fastfetch

    brightnessctl

    rclone
    fuse3

    pulseaudio

    where-is-my-sddm-theme 
    
    mission-center
  ];
  
  fonts = {
    packages = with pkgs; [
      noto-fonts
      noto-fonts-color-emoji
      quicksand
      rubik
      jetbrains-mono
      pkgs.google-fonts
    ];
    
    fontconfig = {
      enable = true;
      defaultFonts = {
        serif = [ "Noto Serif" ];
        sansSerif = [ "Quicksand" ];
        monospace = [ "Noto Sans Mono" ];
        emoji = [ "Noto Color Emoji" ];
      };
    };
  };

services.xserver = {
  enable = true;
  
  xkb = {
    layout = "ch"; # <-- Change this to your main layout (e.g., "de", "fr")
    variant = "de";  # <-- Use this for sub-layouts (e.g., "intl", or leave empty)
  };

};


services.displayManager = {
  enable = true;

  sddm = {
    enable = true;
    theme = "where_is_my_sddm_theme"; # Theme defaults to the Qt6 variant
    wayland.enable = true;
    enableHidpi = true;

    extraPackages = with pkgs; [
      qt6.qt5compat
      qt6.qtdeclarative
      qt6.qtsvg
    ];
    
  };
};


hardware.graphics = {  # or hardware.opengl on older NixOS versions
  enable = true;
  enable32Bit = true;  # Critical for Steam (32-bit support)
};

environment.sessionVariables = {
  NAUTILUS_4_EXTENSION_DIR = "${pkgs.nautilus-python}/lib/nautilus/extensions-4";
};
  
  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.05"; # Did you read the comment?

}
