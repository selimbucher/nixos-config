{ inputs, config, pkgs, lib, hostName, ... }:

{
  imports = [
    ./hyprland.nix
    ./hyprlock.nix
    ./kitty.nix
  ];

  home.username = "selim";
  home.homeDirectory = "/home/selim";
  home.stateVersion = "25.11";

  home.packages = with pkgs; [
    swww
    blueman
    sl
    
    inputs.kiwi.packages.${pkgs.stdenv.hostPlatform.system}.default
    inputs.native-instruments.packages.${pkgs.stdenv.hostPlatform.system}.default

    icon-library

    signal-desktop
    vesktop
    gimp
    onlyoffice-desktopeditors
    libreoffice-fresh
    vscode
    nwg-displays
    tree

    #(emacs-pgtk.pkgs.withPackages (epkgs: [ epkgs.doom-themes epkgs.treemacs ]))
    localsend
    rofi
    pavucontrol
    #swaynotificationcenter
    libnotify

    showtime
    decibels
    gnome-sound-recorder
    gnome-calendar
    smile
    gcolor3
    loupe
    foliate
    transmission_4-gtk
    snapshot
    evince
    gnome-calculator
    baobab
    gnome-font-viewer
    gnome-connections
    simple-scan
    gnome-weather
    clairvoyant
    collision
    commit
    gnome-decoder
    dialect
    forge-sparks
    fretboard
    hieroglyphic
    keypunch
    mousai
    file-roller
    (lutris.overrideAttrs (old: rec {
      version = "0.5.22";
      name = "lutris-${version}";
      src = pkgs.fetchFromGitHub {
        owner = "lutris";
        repo = "lutris";
        rev = "v${version}";
        hash = "sha256-4mNknvfJQJEPZjQoNdKLQcW4CI93D6BUDPj8LtD940A=";
      };
    }))

    spotify

    reaper
    yabridge
    yabridgectl
    wineWowPackages.staging
    qpwgraph
    winetricks
    pipewire.jack # for path
    samba         # provides ntlm_auth, Wine needs it
    xdg-utils

    (writeShellScriptBin "reaper-launch" ''
      WINEPREFIX="$HOME/.wine-ni" wineserver -k || true
      exec pw-jack reaper "$@"
    '')

    #glib
    
    
    (whitesur-gtk-theme.override {
      altVariants = [ "normal" ];
    })
    
    #candy-icons

    #vimix-icon-theme
    #papirus-icon-theme
    #numix-icon-theme
    #tela-icon-theme
    #fluent-icon-theme
    reversal-icon-theme
    
    (let
      base = pkgs.whitesur-icon-theme.override {
        alternativeIcons = true;
        boldPanelIcons = true;
      };
    in
      base.overrideAttrs (oldAttrs: {
        # You can set this to a static date or leave it as "latest"
        version = "latest";
        
        # 1. Use the Flake input for the main source
        # This points to the 'whitesur-src' defined in your flake.nix
        src = inputs.whitesur-src;

        # 2. Reference your personal source from inputs
        # We use the variable directly here
        myCustomIcons = inputs.slimmer-icons;

        dontCheckForBrokenSymlinks = true;

        postInstall = (oldAttrs.postInstall or "") + ''
          echo "Overwriting icons with custom versions from Flake input..."
          
          # We use ${inputs.slimmer-icons} to get the path to the downloaded repo
          cp -rf --no-preserve=mode ${inputs.slimmer-icons}/apps/* $out/share/icons/WhiteSur/apps/
          
          if [ -d "${inputs.slimmer-icons}/apps@2x" ]; then
            cp -rf --no-preserve=mode ${inputs.slimmer-icons}/apps@2x/* $out/share/icons/WhiteSur/apps@2x/
          fi
        '';
      }))
    
    fastfetch
    tetris
    obs-studio

    sox
    playerctl
    neovim

    nwg-look

    python3
    julia
    ghc
    duckdb
    dnsutils
    usbutils

    jq

    inkscape
    obsidian
    proton-vpn

    blanket
    
    # jetbrains-mono
    openconnect
    networkmanager-openconnect
  ];

  programs.thunderbird = {
    enable = true;
    profiles."main".isDefault = true;
  };

  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;  # Enable if you have XWayland apps
    name = "Capitaine Cursors - White";
    package = pkgs.capitaine-cursors-themed;
    size = 24;
  };

  home.activation = {
    createDefaultHyprTheme = lib.hm.dag.entryAfter ["writeBoundary"] ''
      themeFile="${config.home.homeDirectory}/.config/kiwi-shell/hypr.conf"
      
      if [ ! -f "$themeFile" ]; then
        echo "Creating default Hyprland theme file..."
        mkdir -p "$(dirname "$themeFile")"
        
        # We write a safe default color so Hyprland doesn't crash
        echo '$kiwiColorLight = rgba(255, 255, 255, 0.7)' > "$themeFile"
      fi
    '';

    setupYabridge = lib.hm.dag.entryAfter ["writeBoundary"] ''
      ${pkgs.yabridgectl}/bin/yabridgectl sync
    '';
  };

  /*
  systemd.user.services.polkit-gnome-authentication-agent-1 = {
    Unit = {
      Description = "polkit-gnome-authentication-agent-1";
      Wants = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 10;
    };
    
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
  */
  
  /*
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "inode/directory" = "org.gnome.Nautilus.desktop";
      "application/pdf" = "evince.desktop";
    };
  };
  */
  
  xdg.configFile."rofi" = {
    source = inputs.rofi-theme;
  };
  
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config = {
      common = {
        default = [ "gtk" ];
      };
      hyprland = {
        default = [ "hyprland" "gtk" ];
      };
    };
  };
  
  programs.bash = {
    enable = true;
  
    # This appends your custom PS1 directly to the .bashrc file
    initExtra = ''
      PS1='❯ '
    '';
  };

  programs.direnv = {
    enable = true;
    enableBashIntegration = true; # Auto-adds the hook to .bashrc
    enableZshIntegration = true;  # Auto-adds the hook to .zshrc
    nix-direnv.enable = true;     # Much faster reloading
  };
  
  xdg.enable = true;
  xdg.mime.enable = true;
  
  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    
    desktop = "${config.home.homeDirectory}/Desktop";
    documents = "${config.home.homeDirectory}/Documents";
    download = "${config.home.homeDirectory}/Downloads";
    music = "${config.home.homeDirectory}/Music";
    pictures = "${config.home.homeDirectory}/Pictures";
    # publicShare = "${config.home.homeDirectory}/Public";
    templates = "${config.home.homeDirectory}/Templates";
    videos = "${config.home.homeDirectory}/Videos";
  };

  home.shellAliases = {
    rebuild = "sudo nixos-rebuild switch --flake /home/selim/.nixos#${hostName}";
    update = "nix flake update --flake /home/selim/.nixos";
  };

  xdg.desktopEntries = {
    obsidian = {
      name = "Obsidian";
      exec = "env OBSIDIAN_USE_WAYLAND=1 obsidian -enable-features=UseOzonePlatform -ozone-platform=wayland %u";
      icon = "obsidian";
      terminal = false;
      categories = [ "Office" ];
      type = "Application";
      comment = "Knowledge base and note-taking application";
      mimeType = [ "x-scheme-handler/obsidian" ];
    };
    
    cockos-reaper = {
      type = "Application";
      name = "Reaper";
      comment = "Reaper";
      exec = "reaper-launch";
      icon = "cockos-reaper";
      terminal = false;
      categories = [ "Audio" "Video" "AudioVideo" "AudioVideoEditing" "Recorder" ];
      mimeType = [
        "application/x-reaper-project"
        "application/x-reaper-project-backup"
        "application/x-reaper-theme"
      ];
      settings = {
        StartupWMClass = "REAPER";
      };
    };
    nwg-look = {
      name = "GTK Settings";
      icon = "preferences-desktop-theme";
      exec = "nwg-look";
      type = "Application";
      categories = [ "GTK" "Settings" "DesktopSettings" ];
    };
    /*
    "io.missioncenter.MissionCenter" = {
      name = "Task Manager";
      icon = "utilities-system-monitor";
      type = "Application";
      terminal = false;
      exec = "missioncenter";
      categories = ["GTK" "System" "Monitor"];
    };
    */
  };


  # Ensure Qt apps (Crystal Dock) follow the system/GTK theme & icons
  home.sessionVariables = {
    QT_QPA_PLATFORMTHEME = "qt6ct";
    LD_LIBRARY_PATH = "${pkgs.yabridge}/lib:$LD_LIBRARY_PATH";
  };


}
