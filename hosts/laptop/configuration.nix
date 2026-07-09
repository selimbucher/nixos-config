{ pkgs, ... }:

{
  imports = [
    ../../options.nix
    ./hardware-configuration.nix
    ../../common.nix
  ];

  networking.hostName = "laptop";

  # --- Boot-time hardware timeout fixes (see `journalctl -b` on this host) ---

  # Corsair MP600 CORE XT (Phison) stalls on NVMe I/O during boot because it
  # enters an APST deep power state it doesn't wake from cleanly, costing ~30s
  # in "nvme nvme0: ... timeout, completion polled" waits. Disabling APST is the
  # standard fix. Tradeoff: slightly higher SSD idle power draw (~0.5-1W).
  boot.kernelParams = [ "nvme_core.default_ps_max_latency_us=0" ];

  # Meteor Lake (Core Ultra 7 155H) iGPU waits ~18s for the i915 GSC proxy to
  # bind, then errors ("GSC proxy component didn't bind"). The mei_gsc_proxy
  # component must be present alongside i915 (loaded in initrd) so it binds in
  # time instead of timing out.
  boot.initrd.kernelModules = [ "mei" "mei_me" "mei_gsc" "mei_gsc_proxy" ];

  deviceConfig = {
    monitor = [
      "eDP-1, 2880x1800@120, 0x0, 2, bitdepth, 10"
      "HDMI-A-1, 2560x1440@60, -304x-1152, 1.25"
      "DP-1, 3840x2160@30, 1440x0, 2"
    ];
    blur = false;
    shadow = true;
    scale = 2.0;
    jackBufferSize = 128;
  };
}