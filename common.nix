# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, inputs, ... }:

{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];


  nixpkgs.config.allowUnfree = true;

  boot.loader.systemd-boot.enable = false;
  boot.loader = {
    grub = {
      enable = true;
      splashImage = null;
      forceInstall = false;
      backgroundColor = "#000000";
      device = "nodev";
      efiSupport= true;
      useOSProber = false;
      theme = null;
    };

    timeout = 0;
  };
  boot.loader.efi.canTouchEfiVariables = true; 

  
  services.xserver = {
    enable = true;
    xkb.layout = "ch";  # "ch" is the code for Switzerland
    xkb.variant = "";   # Leave empty for default, or use "fr" for Swiss French
    desktopManager.xterm.enable = false;
  };

  services.displayManager = {
    enable = true;

    sddm = {
      enable = true;
      theme = "where_is_my_sddm_theme"; # Theme defaults to the Qt6 variant
      wayland.enable = config.deviceConfig.sddmWayland;
      enableHidpi = true;

      extraPackages = with pkgs; [
        qt6.qt5compat
        qt6.qtdeclarative
        qt6.qtsvg
      ];
      
    };
  };

  boot.plymouth = {
    enable = true;
    theme = "loader_2";
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



  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.networkmanager.enable = true;
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 53317 51413 ];
    allowedUDPPorts = [ 53317 51413 ];
  };
  networking.firewall.checkReversePath = false;  

  time.timeZone = "Europe/Amsterdam";

  fonts.packages = with pkgs; [
    quicksand
    google-fonts 
    font-awesome
];

  # 2. Set Quicksand as the default
  fonts.fontconfig = {
    enable = true;
    defaultFonts = {
      sansSerif = [ "Quicksand" ];
      monospace = [ "DejaVu Sans Mono" ]; # Keep a good monospace font for terminal
    };
  };  

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


  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Experimental = true;
        FastConnectable = false;
      };
      Policy = {
        AutoEnable = true;
      };
    };
  };  

  services.printing.enable = true;

  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  services.libinput.enable = true;

  # AGS Requirements
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  
  programs.ssh.startAgent = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.selim = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    packages = with pkgs; [
      tree
    ];
    initialPassword = "1234";
  };

  # List packages installed in system profile.
  environment.systemPackages = with pkgs; [
    git
    kitty
    swww
    wl-clipboard
    wl-clip-persist
    nautilus
    brave
    slurp
    grim
    brightnessctl
    mission-center

    where-is-my-sddm-theme
  ];

  services.xserver.excludePackages = [ pkgs.xterm ];

  security.polkit.enable = true;

  programs.steam.enable = true;

  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  # Also add this to fix that portal warning in your logs
  xdg.portal.config.common.default = "*";

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?

}

