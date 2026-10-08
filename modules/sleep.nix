# Sleep policy for battery devices: suspend first, hibernate after
# deviceConfig.hibernateAfter (30 min) closed. A short lid
# close wakes in a second; a laptop that stays closed powers off with its
# RAM, and the disk key with it, gone. Measured 2026-10-08: suspend drains
# 0.25 W (3 % overnight, 18 % over a weekend), hibernate nothing; waking
# from hibernate is ~14 s of machine time plus the key touch.
#
# The hibernation image lives in a swap file inside the LUKS root, so it is
# encrypted like everything else and one key touch in the initrd covers both
# the disk and the resume. No resume= on the cmdline: systemd-sleep records
# the image location in the HibernateLocation EFI variable and the initrd's
# hibernate-resume generator reads it back.
{ config, lib, pkgs, ... }:

lib.mkIf config.deviceConfig.battery {
  # dd-created on first activation (~20 s), 16 GiB for 15 GiB of RAM
  swapDevices = [ { device = "/swapfile"; size = 16 * 1024; } ];

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend-then-hibernate";
    HandleLidSwitchExternalPower = "suspend-then-hibernate";
    # After any wake logind ignores the lid for this long, then re-checks it.
    # The Zenbook's lid sensor reports a brief "open" while closing, which
    # aborts the suspend 2-3 s in (lid = wake source); with the default 30 s
    # the closed laptop then sat awake for half a minute. 3 s: it retries.
    HoldoffTimeoutSec = "3s";
  };
  systemd.sleep.settings.Sleep.HibernateDelaySec = config.deviceConfig.hibernateAfter;

  # After a real hibernation the key touch at the boot prompt was the gate,
  # so the hyprlock left from before sleep opens by itself: one touch, not
  # two. Plain suspend resumes keep the lock screen (nothing was touched).
  # With passwordLock the password is still owed, so hyprlock stays (and
  # asks for its own touch again: the one redundant touch left).
  environment.etc."systemd/system-sleep/hyprlock-after-hibernate" = lib.mkIf (!config.deviceConfig.passwordLock) { source =
    pkgs.writeShellScript "hyprlock-after-hibernate" ''
      if [ "$1" = post ] && [ "$SYSTEMD_SLEEP_ACTION" = hibernate ]; then
        ${pkgs.procps}/bin/pkill -x -USR1 hyprlock
      fi
      exit 0
    ''; };
}
