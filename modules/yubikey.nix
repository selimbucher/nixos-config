# deviceConfig.yubikey: the key is required on every way into the running
# system: hyprlock, the TTY login and the SDDM greeter (after a logout or a
# crashed session). The password can only be added on top, never used alone:
#   passwordLock  = hyprlock asks for the password as well
#   passwordLogin = the TTY asks for the password as well, and SDDM shows
#                   the greeter at boot instead of autologin. The greeter
#                   itself takes the password alone: it is never the first
#                   gate (boot = the disk touch just happened; after a logout
#                   = someone already inside the session), so a key there
#                   would be the same touch twice
# A password alone would add nothing while the disk unlocks with the same
# key: a reboot with the key in hand is the way in regardless. With both
# keys lost, boot the live USB and open the disk with the recovery key.
# sudo keeps the password: it runs inside an already unlocked session.
#
# Each stack is: [pam_unix requisite] -> wait-for-fido -> pam_u2f required.
# hyprlock runs pam_authenticate in a loop from the moment it starts, and
# pam_u2f fails instantly when no key is present, which left the field in a
# permanent fail state (transparent dots). The pam_exec shim ahead of it
# blocks until a FIDO token shows up, event-driven through udev, so the
# loop parks there instead. Without a password hyprlock has no input field,
# only a "Touch your key" label (home/apps/hyprlock.nix).
# The password goes before the key so a wrong one fails without a touch.
# Everything is "required", so the usual trailing deny is off.
#
# Still password-only on the laptop: ssh from the home LAN (its
# configuration.nix), on purpose for rsync; not reachable from a stolen
# laptop's lid.
# Keys are enrolled per user into ~/.config/Yubico/u2f_keys, both on one line
# so either unlocks. Not in this repo: a key handle identifies the key.
#   nix shell nixpkgs#pam_u2f -c pamu2fcfg -u selim >  ~/.config/Yubico/u2f_keys  # first key plugged in, touch it
#   nix shell nixpkgs#pam_u2f -c pamu2fcfg -n       >> ~/.config/Yubico/u2f_keys  # swap to the spare, touch it
# origin/appid default to pam://<hostname>, so a key enrolled here is not
# enrolled on the desktop.
#
# Without a password at login the keyring cannot auto-unlock: give it an
# empty password in Seahorse, or expect one unlock dialog per session.
{ config, lib, pkgs, ... }:

let
  cfg = config.deviceConfig;
  udevadm = "${pkgs.systemd}/bin/udevadm";
  grep = "${pkgs.gnugrep}/bin/grep";
  u2fOrder = name: config.security.pam.services.${name}.rules.auth.u2f.order;
  keyPolicy = name: withPassword: {
    u2f = { enable = true; control = "required"; };
    unixAuth = withPassword;
    rules.auth = {
      deny.enable = false;
      wait-for-fido = {
        order = u2fOrder name - 10;
        control = "required";
        modulePath = "${pkgs.pam}/lib/security/pam_exec.so";
        args = [ "quiet" "${waitForKey}" ];
      };
      unix = lib.mkIf withPassword {
        order = lib.mkForce (u2fOrder name - 20);
        control = lib.mkForce "requisite";
      };
    };
  };
  # exits 0 once a FIDO token is present; the monitor starts before the
  # first check so a key plugged in between the two is not missed
  waitForKey = pkgs.writeShellScript "pam-wait-for-fido" ''
    present() {
      for d in /dev/hidraw*; do
        ${udevadm} info -q property "$d" 2>/dev/null | ${grep} -qx ID_FIDO_TOKEN=1 && return 0
      done
      return 1
    }
    coproc MON { exec ${udevadm} monitor -u -s hidraw -p; }
    trap 'kill "$MON_PID" 2>/dev/null' EXIT
    present && exit 0
    while read -r -u "''${MON[0]}" line; do
      [ "$line" = ID_FIDO_TOKEN=1 ] && exit 0
    done
    exit 1
  '';
in
lib.mkMerge [
  {
    assertions = [{
      assertion = cfg.yubikey || (cfg.passwordLogin && cfg.passwordLock);
      message = "deviceConfig.passwordLogin/passwordLock = false need deviceConfig.yubikey";
    }];
  }
  (lib.mkIf cfg.yubikey {
  security.pam.services = {
    hyprlock = keyPolicy "hyprlock" cfg.passwordLock;
    login = keyPolicy "login" cfg.passwordLogin;
    # the greeter's stack is "substack login"; with a password it swaps that
    # for the password alone (plus the keyring unlock the login stack had)
    sddm = lib.mkIf cfg.passwordLogin {
      rules.auth = {
        login.enable = false;
        unix = {
          order = 10100;
          control = "required";
          modulePath = "${pkgs.pam}/lib/security/pam_unix.so";
          args = [ "likeauth" "try_first_pass" ];
        };
        gnome_keyring = {
          order = 10200;
          control = "optional";
          modulePath = "${pkgs.gnome-keyring}/lib/security/pam_gnome_keyring.so";
        };
      };
    };
  };

  services.displayManager = {
    autoLogin = { enable = !cfg.passwordLogin; user = "selim"; };
    defaultSession = "hyprland-uwsm";
  };
  })
]
