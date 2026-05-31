{ inputs, config, pkgs, lib, ... }:
{
  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
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
        echo '$kiwiColorLight = rgba(255, 255, 255, 0.7)' > "$themeFile"
      fi
    '';
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
      settings.StartupWMClass = "REAPER";
    };

    captureage = {
      name = "CaptureAge";
      icon = "captureage";
      exec = "protontricks-launch --appid 813780 ${config.home.homeDirectory}/.steam/steam/steamapps/compatdata/813780/pfx/drive_c/users/steamuser/AppData/Local/Programs/CaptureAge/CaptureAge.exe";
      type = "Application";
      settings."X-Kiwi-TitleMatch" = "^CaptureAge";
    };

    nwg-look = {
      name = "GTK Settings";
      icon = "preferences-desktop-theme";
      exec = "nwg-look";
      type = "Application";
      categories = [ "GTK" "Settings" "DesktopSettings" ];
    };

    en-croissant = {
      name = "En Croissant";
      icon = "en-croissant";
      exec = "en-croissant";
      type = "Application";
      terminal = false;
      comment = "Ultimate Chess Toolkit";
      categories = [ "Game" "BoardGame" ];
      settings.StartupWMClass = "en-croissant";
    };

    "org.gnome.Geary" = {
      name = "Geary";
      genericName = "Email";
      comment = "Send and receive email";
      exec = "geary %U";
      icon = "org.gnome.Geary";
      terminal = false;
      type = "Application";
      categories = [ "GNOME" "GTK" "Network" "Email" ];
      mimeType = [ "x-scheme-handler/mailto" ];
      settings = {
        Keywords = "Mail;E-mail;email;IMAP;GMail;Yahoo;Hotmail;Outlook;";
        StartupNotify = "true";
        StartupWMClass = "geary";
      };
    };

  };
}
