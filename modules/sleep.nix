# Sleep policy for battery devices: suspend first, hibernate after
# deviceConfig.hibernateAfter (30 min) closed. A short lid
# close wakes in a second; a laptop that stays closed powers off with its
# RAM, and the disk key with it, gone. Measured 2026-10-08: suspend drains
# 0.25 W (3 % overnight, 18 % over a weekend), hibernate nothing; waking
# from hibernate is ~14 s of machine time plus the disk unlock.
#
# The hibernation image lives in a swap file inside the LUKS root, so it is
# encrypted like everything else and one unlock in the initrd (key touch or
# passphrase) covers both the disk and the resume. No resume= on the cmdline:
# systemd-sleep records the image location in the HibernateLocation EFI
# variable and the initrd's hibernate-resume generator reads it back.
{ config, lib, pkgs, ... }:

let
  cfg = config.deviceConfig;
  # The disk unlock asks for what hyprlock asks for: the passphrase (no key;
  # a cold boot logs straight in after it, luks.nix) or the touch when
  # hyprlock takes the key alone. With key plus passwordLock the password is
  # still owed, so hyprlock stays after a hibernation.
  diskUnlockOpensLock = cfg.luksRoot != null && !(cfg.yubikey && cfg.passwordLock);
  # EFI variables under our own vendor GUID: the only storage both the
  # initrd and the restored system can reach
  efivar = name: "/sys/firmware/efi/efivars/${name}-874aab16-baa8-4233-9efc-aacec1de8051";
  challenge = efivar "UnlockChallenge";
  response = efivar "UnlockResponse";
  challengeCopy = "/run/hibernate-unlock-challenge";
in
lib.mkIf cfg.battery (lib.mkMerge [
{
  # At least the RAM (30.6 GiB): systemd refuses to hibernate once active
  # anonymous memory exceeds the free swap. dd-created (or resized) at boot.
  swapDevices = [ { device = "/swapfile"; size = 32 * 1024; } ];

  # The image is compressed to write fewer bytes. The kernel default, lzo, was
  # the limit on the Framework: 412 MB/s of RAM in, 150 MB/s out, while the
  # encrypted SSD takes ~300 MB/s even on battery in power-saver (2026-11-17).
  # lz4 is built into the kernel and the image header names the algorithm,
  # so the resume reads either.
  boot.kernelParams = [ "hibernate.compressor=lz4" ];

  # upower's default, hybrid-sleep, keeps the RAM image alive on the last few
  # percent; any wake (a USB-C power event) then discards the disk image
  services.upower.criticalPowerAction = "Hibernate";

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend-then-hibernate";
    HandleLidSwitchExternalPower = "suspend-then-hibernate";
    # After any wake logind ignores the lid for this long, then re-checks it.
    # The Zenbook's lid sensor reports a brief "open" while closing, which
    # aborts the suspend 2-3 s in (lid = wake source); with the default 30 s
    # the closed laptop then sat awake for half a minute. 3 s: it retries.
    HoldoffTimeoutSec = "3s";
  };
  systemd.sleep.settings.Sleep = {
    HibernateDelaySec = cfg.hibernateAfter;
    # Power off like a shutdown once the image is written. In platform mode
    # (ACPI S4) a wake event in that last step (power button, lid, charger)
    # rolls the hibernation back, and amdgpu's restore without a power cycle
    # loses buffers: every GPU client crashed, hyprlock included (kernel 7.2,
    # 2026-11-17). Here nothing can cancel it after the image is written.
    HibernateMode = "shutdown";
  };
}

# After a hibernation the disk unlock opens the hyprlock left from before
# sleep: one prompt, not two. Handshake:
#   pre-hibernate  a fresh random challenge goes into an EFI variable and /run
#                  (RAM, so it is part of the image)
#   initrd         once the disk is open, the challenge is copied to the
#                  response variable; the resume waits for this
#   post-hibernate response = the copy in /run -> SIGUSR1 to hyprlock
# A hibernation that failed or that the kernel rolled back (a wake event
# during the image write) never went through the initrd, so there is no
# response and hyprlock stays. Any broken step does the same: the worst case
# is the second prompt, never an open session. Writing the variables needs
# root; from outside, only by booting the laptop, which loses the RAM.
# Plain suspend resumes keep the lock screen.
(lib.mkIf diskUnlockOpensLock {
  boot.initrd.systemd.services."systemd-cryptsetup@root".serviceConfig.ExecStartPost = [
    "-/bin/sh -c 'test -e ${challenge} && /bin/cat ${challenge} > ${response}'"
  ];
  boot.initrd.systemd.services.systemd-hibernate-resume = {
    overrideStrategy = "asDropin";
    after = [ "systemd-cryptsetup@root.service" ];
  };

  # hyprlock's key wait (pam-wait-for-fido, its child) is told too: hyprlock
  # only exits once that returns, and a hyprlock left running kept the next
  # lid close from locking (hypridle starts none while one runs).
  # Variables under a non-standard GUID are created immutable (efivarfs).
  environment.etc."systemd/system-sleep/hyprlock-after-hibernate".source =
    pkgs.writeShellScript "hyprlock-after-hibernate" ''
      export PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.diffutils pkgs.e2fsprogs pkgs.procps pkgs.systemd ]}
      [ "$SYSTEMD_SLEEP_ACTION" = hibernate ] || exit 0

      clear() {
        for v in ${challenge} ${response}; do
          [ -e "$v" ] && chattr -i "$v" && rm "$v"
        done
        rm -f ${challengeCopy}
      }

      case $1 in
        pre)
          clear
          id=$(systemd-id128 new) || exit 0
          umask 077
          printf '\007\000\000\000%s' "$id" > ${challengeCopy}
          cat ${challengeCopy} > ${challenge}
          ;;
        post)
          if cmp -s ${challengeCopy} ${response} \
            && locks=$(pgrep -d, -x hyprlock); then
            pkill -x -USR1 hyprlock
            pkill -USR1 -P "$locks"
          fi
          clear
          ;;
      esac
      exit 0
    '';
})
])
