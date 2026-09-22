{ pkgs, ... }:

{
  imports = [
    ../../options.nix
    ./hardware-configuration.nix
    ../../common.nix
  ];

  networking.hostName = "laptop";

  # --- Corsair MP600 CORE XT boot stalls (real fix: disable VMD in BIOS) ---
  boot.kernelParams = [
    "nvme_core.default_ps_max_latency_us=0" # APST deep sleep it never wakes from
    "nvme_core.io_timeout=10" # dropped irq behind VMD: poll after 10s, not 30s
  ];

  # i915's GSC proxy must bind in initrd or boot waits ~18s for it
  boot.initrd.kernelModules = [ "mei" "mei_me" "mei_gsc" "mei_gsc_proxy" ];

  # Iris Xe clock floor. The GPU's own governor (SLPC) only clocks up under
  # sustained load and holds near its 300 MHz efficient clock for the short
  # per-frame bursts of a compositor, so frames missed their 16.7 ms while
  # the GPU was half idle. The floor applies only while the GPU is awake;
  # asleep (RC6) it draws nothing either way.
  #
  # Measured 2026-09-22 on the panel, blur 6x4: late frames / GPU power, for
  # a small animation, then a translucent window moving over another.
  # Without xray:
  #   default  23-41% 1.7 W    43-48% 2.2 W
  #   750         0%  2.0 W     7-20% 3.5 W
  #   900         0%  2.2 W     0-1%  4.3 W
  # With xray (windows blur the wallpaper; kiwi-shell sets it):
  #   600       0.3%  1.3 W       0%  1.8 W
  #   750         0%  1.0 W       0%  1.9 W   <- lowest clean for both
  # card[0-9], not card*: that would also match the connectors
  # (card1-eDP-1), which have no such attribute.
  services.udev.extraRules = ''
    ACTION=="add|change", SUBSYSTEM=="drm", KERNEL=="card[0-9]", DRIVERS=="i915", ATTR{gt/gt0/rps_min_freq_mhz}="750"
  '';

  deviceConfig = {
    monitor = [
      { output = "eDP-1";    mode = "2880x1800@120"; position = "0x0";        scale = "2"; bitdepth = 10; }
      { output = "HDMI-A-1"; mode = "2560x1440@60";  position = "-304x-1152"; scale = "1.25"; }
      { output = "DP-1";     mode = "3840x2160@30";  position = "1440x0";     scale = "2"; }
    ];
    # WhiteSur renders header bars and sidebars at 96% opacity; without blur
    # behind them that reads as a muddy wallpaper tint rather than vibrancy.
    blur = true;
    shadow = true;
    scale = 2.0;
    jackBufferSize = 128;
    # true = patched wine + yabridge like the desktop (~1h local build per nixpkgs bump)
    wineFork = false;
  };
}