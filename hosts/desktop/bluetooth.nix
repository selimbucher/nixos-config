# MediaTek MT7921 Bluetooth (USB 0e8d:0608, the on-board Wi-Fi/BT combo) and the
# MX Master 3S (BLE, D0:6B:B0:AA:E8:66). Two independent controller problems:
#
# 1. btusb autosuspends it after 2s idle and the firmware then never wakes for
#    the mouse's BLE reconnect advertisements (diagnosed 2026-09-08:
#    power/runtime_status=suspended while the mouse couldn't connect; a direct
#    connect flipped it to active and worked instantly). A udev
#    ATTR{power/control}="on" rule does NOT work: the USB device enumerates in
#    the initrd ~5s before btusb loads, and btusb_probe() then calls
#    usb_enable_autosuspend() which resets control back to "auto" (verified
#    2026-09-09). Disabling it at the driver level is race-free.
#
# 2. With autosuspend off (verified 2026-10-30) the mouse still fails to come
#    back after its idle drop or after a boot: the kernel's *passive* background
#    scan, which is what auto-connects a bonded LE device, never sees it, while
#    an *active* discovery scan catches it within seconds and the kernel then
#    auto-connects it (2026-10-30 22:25, 10-31 12:05, 11-01 12:44 — every time).
#    `bluetoothctl connect`, which also relies on passive scanning for the
#    address, times out in the same state. Boots after a hard crash additionally
#    show `hci0: Device setup in 21xxxxxx usecs` instead of ~190000. Controller
#    firmware bug (accept-list/passive-scan path); not reproducible on demand,
#    so the fix is empirical: keep an LE discovery session open whenever the
#    mouse is disconnected, and let the kernel's auto-connect do the rest.
{ pkgs, ... }:

let
  mousePath = "/org/bluez/hci0/dev_D0_6B_B0_AA_E8_66";
in
{
  boot.extraModprobeConfig = "options btusb enable_autosuspend=0";

  # Problem 2 workaround. Idle (connected): one D-Bus property read every 5s.
  # Disconnected: plain `scan on` (dual-mode, unfiltered) in 25s sessions that
  # end as soon as the mouse is back. Plain discovery is the mode that has
  # connected the mouse every time; an LE-only, address-filtered discovery was
  # tried on 2026-11-01 and did not (test was confounded: the mouse was not
  # being touched), so it stays unproven until btmon shows what differs.
  # Logs only on state changes.
  systemd.user.services.mx-master-reconnect = {
    description = "Keep LE discovery open while the MX Master 3S is disconnected (MT7921 passive-scan workaround)";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      Restart = "always";
      RestartSec = 5;
    };
    path = [ pkgs.bluez pkgs.systemd pkgs.coreutils ];
    script = ''
      dev=${mousePath}
      prop() { busctl get-property org.bluez "$1" "$2" "$3" 2>/dev/null || true; }
      connected() { [ "$(prop "$dev" org.bluez.Device1 Connected)" = "b true" ]; }
      powered()   { [ "$(prop /org/bluez/hci0 org.bluez.Adapter1 Powered)" = "b true" ]; }

      while :; do
        if connected || ! powered; then
          sleep 5
          continue
        fi
        echo "mouse disconnected: starting discovery"
        start=$(date +%s)
        until connected; do
          # bluetoothctl stops discovery when its stdin closes; the subshell
          # closes it as soon as the mouse is connected or after 25s.
          ( printf 'scan on\n'
            for _ in $(seq 25); do
              sleep 1
              connected && break
            done
          ) | bluetoothctl >/dev/null 2>&1 || true
          powered || break
        done
        if connected; then
          echo "mouse connected after $(( $(date +%s) - start ))s; discovery off"
        fi
      done
    '';
  };

  # Evidence for the next misbehaviour: a rolling HCI trace. Hourly files,
  # zstd-compressed (an active mouse is ~18 MB/h raw, ~2 MB/h compressed), 24
  # kept, in /var/log/btmon. Read one with
  #   zstd -d -o /tmp/x.btsnoop /var/log/btmon/<file>.zst && btmon -r /tmp/x.btsnoop
  # Remove this service once the passive-scan failure is understood.
  systemd.services.btmon-ring = {
    description = "Rolling btmon HCI trace for Bluetooth diagnostics";
    wantedBy = [ "multi-user.target" ];
    after = [ "bluetooth.service" ];
    serviceConfig = {
      Restart = "always";
      RestartSec = 10;
      LogsDirectory = "btmon";
      WorkingDirectory = "/var/log/btmon";
    };
    path = [ pkgs.bluez pkgs.zstd pkgs.coreutils pkgs.findutils ];
    script = ''
      while :; do
        f=$(date +%F_%H%M%S).btsnoop
        timeout 1h btmon -w "$f" >/dev/null 2>&1 || true
        zstd -q --rm "$f" || true
        ls -1t ./*.btsnoop.zst 2>/dev/null | tail -n +25 | xargs -r rm -f
      done
    '';
  };
}
