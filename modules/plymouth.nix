# Boot splash. An encrypted root asks for its passphrase on a macOS-style lock
# screen (pkgs/plymouth/login); the others only ever show the spinner.
{ config, lib, pkgs, inputs, ... }:

let
  login = config.deviceConfig.luksRoot != null;
  # the lock screen's wallpaper, imported by content: a kiwi update alone
  # doesn't rebuild the initrd
  wallpaper = builtins.path {
    name = "plymouth-wallpaper.jpg";
    path = "${inputs.kiwi}/src/kiwi-shell/assets/wallpapers/pawel-czerwinski-ZkzobNDayXo-unsplash.jpg";
  };
  plymouth = "/bin/plymouth"; # boot.initrd.systemd.extraBin.plymouth (plymouth.nix)
in
{
  boot.plymouth = {
    enable = true;
    theme = if login then "login" else "spinner_alt";
    # the login theme places device pixels itself; with Plymouth's HiDPI
    # doubling it would be drawn at half the panel's resolution and enlarged
    extraConfig = "DeviceScale=1";
    # the one font the initrd carries: every Quicksand weight the theme draws
    font = "${pkgs.quicksand}/share/fonts/truetype/Quicksand[wght].ttf";
    themePackages = lib.optional login (pkgs.callPackage ../pkgs/plymouth/login { inherit wallpaper; }) ++ [
      # the script is replaced: the original centres on display 0, which is
      # off-centre everywhere once a monitor of another size is attached
      ((pkgs.adi1090x-plymouth-themes.override {
        selected_themes = [ "spinner_alt" ];
      }).overrideAttrs (o: {
        # the package's installPhase runs no hooks, so append there
        installPhase = o.installPhase + ''
          cp ${../pkgs/plymouth/spinner_alt.script} $out/share/plymouth/themes/spinner_alt/spinner_alt.script
        '';
      }))
    ];
  };

  # The lock screen's clock: Plymouth has no time of its own, so the initrd
  # sends it every minute. As a message, not a status update: Plymouth drops
  # status updates until the splash is up, and the display (amdgpu) appears
  # about 2 s after plymouthd. Messages wait for it.
  boot.initrd.systemd = lib.mkIf login {
    contents."/etc/localtime" = lib.mkIf (config.time.timeZone != null) {
      source = "${pkgs.tzdata}/share/zoneinfo/${config.time.timeZone}";
    };
    services.plymouth-clock = {
      description = "Show the time on the boot splash";
      wantedBy = [ "plymouth-start.service" ];
      after = [ "plymouth-start.service" ];
      unitConfig = {
        DefaultDependencies = false;
        ConditionPathExists = "/run/plymouth/pid";
      };
      serviceConfig.Type = "oneshot";
      # the last minute's message goes, so Plymouth keeps one
      script = ''
        t=$(date +%s)
        clock() { date -d "@$1" '+clock:%H:%M %A, %d %B'; }
        ${plymouth} hide-message --text="$(clock $((t - 60)))"
        ${plymouth} display-message --text="$(clock $t)"
      '';
    };
    timers.plymouth-clock = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*:*:00";
        AccuracySec = "1s";
      };
    };
  };
}
