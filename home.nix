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

    inputs.desktop.packages.${pkgs.stdenv.hostPlatform.system}.default

    icon-library

    signal-desktop
    vesktop
    gimp
    onlyoffice-desktopeditors
    libreoffice-fresh
    vscode    

    #(emacs-pgtk.pkgs.withPackages (epkgs: [ epkgs.doom-themes epkgs.treemacs ]))
    localsend
    rofi
    pavucontrol
    swaynotificationcenter
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

    #glib

    (whitesur-gtk-theme.override {
      altVariants = [ "normal" ];
    })


    
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
    sox
    playerctl

    whitesur-cursors
    nwg-look

    python3
    julia
    ghc

    inkscape
    obsidian
    protonvpn-gui
    
    jetbrains-mono
  ];
  
  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;  # Enable if you have XWayland apps
    name = "WhiteSur-cursors";  # Replace with your desired theme name
    package = pkgs.bibata-cursors;   # Replace with the package for that theme
    size = 24;
  };

  
  services.swaync = {
    enable = true;
    # Optional: customize settings
    settings = {
      positionX = "center";
      positionY = "top";
      timeout = 5;
      timeout-low = 3;
      timeout-critical = 0;
      notification-window-width = 400;
      control-center-width = 500;
      control-center-height = 300;
      fit-to-screen = true;
      keyboard-shortcuts = true;
      image-visibility = "when-available";
      transition-time = 200;
      hide-on-clear = true;
      hide-on-action = true;
      control-center-margin-top = 10;
      control-center-margin-bottom = 10;
      control-center-exclusive-zone= true;
      
      widgets = [
        "title"
        "dnd"
        "notifications"
      ];
    };
    
    style = ''
      * {
        font-family: 'Quicksand';
        border-radius: 12px;
      }

      .notification {
        background: rgba(0, 0, 0, 0.9);
        border-radius: 8px;
        border: 1px solid #232323ff;
        padding: 2px;
      }

      .notification-title {
        margin-bottom: 12px;
      }

      .notification-content {
        padding: 10px;
      }
      
      .control-center {
        background: rgba(0, 0, 0, 0.9);
        transform: translateX(-460px);
      }
      .notification-image, .image {
        margin-right: 12px;
      }
    '';
  };
    

  home.activation = {
    createDefaultHyprTheme = lib.hm.dag.entryAfter ["writeBoundary"] ''
      themeFile="${config.home.homeDirectory}/.config/desktop/hypr.conf"
      
      if [ ! -f "$themeFile" ]; then
        echo "Creating default Hyprland theme file..."
        mkdir -p "$(dirname "$themeFile")"
        
        # We write a safe default color so Hyprland doesn't crash
        echo '$primaryColor = rgba(179,165,231,0.6)' > "$themeFile"
      fi
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
    
    rebuild = {
      name = "NixOS Rebuild";
      terminal = false;
      icon = "system-software-update";
      exec = "kitty --title \"NixOS Rebuild\" --hold sh -c \"sudo nixos-rebuild switch --flake /home/selim/.nixos#${hostName}\"";
    };
    upgrade = {
      name = "Upgrade Packages";
      terminal = false;
      icon = "system-software-update";
      exec = "kitty --title \"Upgrade Flake Packages\" --hold sh -c \"nix flake update --flake /home/selim/.nixos\"";
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
  };


}
