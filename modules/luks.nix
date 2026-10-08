# LUKS2 root (deviceConfig.luksRoot), opened in stage 1 (systemd) by a
# YubiKey touch: keys enrolled with systemd-cryptenroll, plus a recovery key
# on paper that the passphrase prompt takes after the 30 s token wait. The
# laptop's was encrypted in place on 2026-10-08 (cryptsetup reencrypt from
# a live USB, then systemd-cryptenroll for both keys). Swap is
# a file inside the volume (sleep.nix), so a hibernation image is encrypted
# with everything else.
{ config, lib, ... }:

lib.mkIf (config.deviceConfig.luksRoot != null) {
  boot.initrd.luks.devices.root = {
    # the partition, not the LUKS UUID: that one only exists after migration
    device = "/dev/disk/by-partuuid/${config.deviceConfig.luksRoot}";
    crypttabExtraOpts = [ "fido2-device=auto" ];
    allowDiscards = true;    # TRIM reaches the SSD
    bypassWorkqueues = true; # NVMe: no dm-crypt queueing latency
  };
}
