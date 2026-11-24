{ inputs, config, pkgs, lib, ... }:
let
  photoshopExe = "${config.home.homeDirectory}/.wine-cc/drive_c/Program Files/Adobe/Adobe Photoshop 2027/Photoshop.exe";
  photoshop = pkgs.writeShellScript "photoshop" ''
    export WINEPREFIX="$HOME/.wine-cc"
    args=()
    for f in "$@"; do args+=("$(winepath -w "$f")"); done
    exec wine "${photoshopExe}" "''${args[@]}"
  '';
in
{
  home.pointerCursor = {
    enable = true;
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

    # Icon group 1000 is Photoshop's application icon.
    photoshopIcon = lib.hm.dag.entryAfter ["writeBoundary"] ''
      exe="${photoshopExe}"
      icon="${config.home.homeDirectory}/.local/share/icons/hicolor/256x256/apps/photoshop.png"
      if [ -f "$exe" ] && [ ! -f "$icon" ]; then
        tmp=$(mktemp -d)
        ${pkgs.icoutils}/bin/wrestool -x -t 14 -n 1000 "$exe" -o "$tmp/photoshop.ico"
        mkdir -p "$(dirname "$icon")"
        ${pkgs.icoutils}/bin/icotool -x -w 256 -o "$icon" "$tmp/photoshop.ico" 2>/dev/null
        rm -rf "$tmp"
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
      exec = "reaper-logged";
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

    photoshop = {
      name = "Adobe Photoshop 2027";
      genericName = "Image Editor";
      icon = "photoshop";
      exec = "${photoshop} %F";
      type = "Application";
      terminal = false;
      categories = [ "Graphics" "2DGraphics" "RasterGraphics" ];
      settings.StartupWMClass = "photoshop.exe";
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
