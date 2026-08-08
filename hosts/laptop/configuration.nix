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

  deviceConfig = {
    monitor = [
      { output = "eDP-1";    mode = "2880x1800@120"; position = "0x0";        scale = "2"; bitdepth = 10; }
      { output = "HDMI-A-1"; mode = "2560x1440@60";  position = "-304x-1152"; scale = "1.25"; }
      { output = "DP-1";     mode = "3840x2160@30";  position = "1440x0";     scale = "2"; }
    ];
    blur = false;
    shadow = true;
    scale = 2.0;
    jackBufferSize = 128;
  };
}