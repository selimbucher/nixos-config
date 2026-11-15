{ pkgs, ... }:

{
  imports = [
    ../../options.nix
    ./hardware-configuration.nix
    ./bluetooth.nix
    ../../common.nix
  ];
  
  networking.hostName = "desktop";

  # Reach it from the laptop, at home or over the tailnet (common.nix). Key-only.
  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };
  users.users.selim.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEHhJsfSWGuKbAGbElK7JuzeTMqvmIAWtQO2D8JxuCJH selim@laptop"
  ];
  networking.hosts."100.64.0.2" = [ "laptop" ];

  # Woken from off or suspend by the Pi at home (`wake-desktop`, ~/.pi). From
  # off it also needs ErP Ready off and Power On By PCI-E on in the BIOS.
  networking.interfaces.enp10s0.wakeOnLan.enable = true;

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

  # MT7921 Bluetooth + MX Master 3S workarounds live in ./bluetooth.nix.

  deviceConfig = {
    sddmWayland = false;
    wineFork = true;
    monitor = [
      { output = "DP-2";     mode = "2560x1440@240"; position = "0x0";    scale = "1"; bitdepth = 10; }
      { output = "DP-3";     mode = "2560x1440@240"; position = "2560x0"; scale = "1"; bitdepth = 10; }
      { output = "HDMI-A-1"; mode = "3840x2160@60";  position = "5120x0"; scale = "1"; }
    ];
    blur = true;
    # macOS reads as much from the drop shadow as from the corner radius;
    # without it windows sit flat on the wallpaper.
    shadow = true;
    extraExecOnce = [
      "steam -silent"
    ];
    scale = 1.0;
    # 27" at scale 1, an arm's length further away than the laptop's panel:
    # a step up from the macOS sizes
    uiFontSize = 11;
    codeFontSize = 11;
    jackBufferSize = 64;
  };
}