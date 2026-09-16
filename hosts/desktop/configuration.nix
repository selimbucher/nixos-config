{ pkgs, ... }:

{
  imports = [
    ../../options.nix
    ./hardware-configuration.nix
    ../../common.nix
  ];
  
  networking.hostName = "desktop";

  # Allow same-user ptrace (classic behavior). Yama's default of 1 blocks
  # gdb from attaching to running processes, which reaper-rescue and the
  # crashwatch wedge watchdog need for live backtraces of Wine plugin hosts.
  boot.kernel.sysctl."kernel.yama.ptrace_scope" = 0;

  # In-kernel NT synchronization primitives for Wine. Without this the
  # yabridge plugin hosts fall back to wineserver RPC for every sync op in
  # the audio path — traced 2026-08-16 to 100-500ms process() stalls (REAPER
  # audio thread blocked in rt_mutex_schedule waiting on livefx workers stuck
  # in bridged plugins; rotated across AD2/SWAM/Pro-Q4 hosts, i.e. systemic).
  # wine-staging 11.14 uses /dev/ntsync automatically when it exists.
  boot.kernelModules = [ "ntsync" ];
  services.udev.extraRules = ''
    KERNEL=="ntsync", MODE="0666"

    # t.racks DSP 4x4 Mini Pro (monitor crossover/EQ box). Configured from
    # Linux via WebHID (github.com/GlassOnTin/opendsp-4x4 in Chromium) —
    # Chromium can only open the hidraw node if the seated user owns it,
    # which is what uaccess grants.
    KERNEL=="hidraw*", ATTRS{idVendor}=="0168", ATTRS{idProduct}=="0821", TAG+="uaccess"
  '';

  # MediaTek MT7921 Bluetooth (USB 0e8d:0608, the on-board Wi-Fi/BT combo).
  # btusb autosuspends it after 2s idle and the firmware then never wakes for
  # the MX Master 3S's BLE reconnect advertisements, so the mouse "randomly"
  # fails to connect until something pokes the controller (reboot, or a
  # host-initiated `bluetoothctl connect`). Diagnosed 2026-09-08:
  # power/runtime_status=suspended while the mouse couldn't connect; a direct
  # connect flipped it to active and worked instantly.
  # A udev ATTR{power/control}="on" rule does NOT work here: the USB device
  # enumerates in the initrd ~5s before btusb loads, and btusb_probe() then
  # calls usb_enable_autosuspend() which resets control back to "auto"
  # (verified 2026-09-09). Disabling it at the driver level is race-free.
  boot.extraModprobeConfig = "options btusb enable_autosuspend=0";

  deviceConfig = {
    sddmWayland = false;
    monitor = [
      { output = "DP-2";     mode = "2560x1440@240"; position = "0x0";    scale = "1.25"; bitdepth = 10; }
      { output = "DP-3";     mode = "2560x1440@240"; position = "2048x0"; scale = "1.25"; bitdepth = 10; }
      { output = "HDMI-A-1"; mode = "3840x2160@60";  position = "4096x0"; scale = "1"; }
    ];
    blur = true;
    # macOS reads as much from the drop shadow as from the corner radius;
    # without it windows sit flat on the wallpaper.
    shadow = true;
    extraExecOnce = [
      "steam -silent"
    ];
    scale = 1.25;
    jackBufferSize = 64;
  };
}