# LUKS2 root (deviceConfig.luksRoot), opened in stage 1 (systemd) by a
# YubiKey touch: keys enrolled with systemd-cryptenroll, plus a recovery key
# on paper that the passphrase prompt takes once the key wait has elapsed.
# The laptop's was encrypted in place on 2026-10-08 (cryptsetup reencrypt
# from a live USB, then systemd-cryptenroll for both keys). Swap is a file
# inside the volume (sleep.nix), so a hibernation image is encrypted with
# everything else.
{ config, lib, ... }:

let
  keyWait = "2min"; # then the recovery-key prompt appears
  prompt = "Insert security key to unlock";
  plymouth = "/bin/plymouth"; # boot.initrd.systemd.extraBin.plymouth (plymouth.nix)
in
lib.mkIf (config.deviceConfig.luksRoot != null) {
  boot.initrd.luks.devices.root = {
    # the partition, not the LUKS UUID: that one only exists after migration
    device = "/dev/disk/by-partuuid/${config.deviceConfig.luksRoot}";
    crypttabExtraOpts = [
      "fido2-device=auto"
      "token-timeout=${keyWait}"
    ];
    allowDiscards = true;    # TRIM reaches the SSD
    bypassWorkqueues = true; # NVMe: no dm-crypt queueing latency
  };

  # systemd-cryptsetup only *logs* "please plug in your token", which Plymouth
  # hides, so the splash showed a bare spinner until the key wait ran out and
  # the passphrase prompt appeared. Draw the prompt ourselves (spinner_alt has a
  # message slot at the top of the screen, but no hide handler: blank it after).
  # A failed unlock (3 wrong passphrases, or Enter pressed while the key was
  # plugged in late) restarts the wait instead of ending in emergency mode.
  boot.initrd.systemd.services."systemd-cryptsetup@root" = {
    overrideStrategy = "asDropin";
    after = [ "plymouth-start.service" ];
    startLimitIntervalSec = 0; # retry forever
    serviceConfig = {
      ExecStartPre = "-${plymouth} display-message --text=\"${prompt}\"";
      ExecStartPost = "-${plymouth} display-message --text=\" \"";
      Restart = "on-failure";
      RestartSec = 1;
    };
  };

  # The root filesystem's device job would give up after 90 s (DefaultDeviceTimeoutSec)
  # and drop to emergency mode while we are still waiting for the key.
  fileSystems."/".options = [ "x-systemd.device-timeout=0" ];
}
