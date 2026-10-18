# MX Master 4 hardware DPI. The mouse resets to 1000 on every (re)connect, so
# udev starts a oneshot user service on each connect that sets it again.
#   solaar config "MX Master 4" dpi        # read
#   solaar config "MX Master 4" dpi 4000   # try a value live
{ config, lib, pkgs, ... }:

let
  dpi = config.deviceConfig.mouseDpi;
in
lib.mkIf (dpi != null) {
  # solaar CLI + udev rules giving the logged-in user hidraw access
  programs.solaar.enable = true;

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="hidraw", KERNELS=="0005:046D:B042.*", TAG+="systemd", ENV{SYSTEMD_USER_WANTS}+="mx-master-dpi.service"
  '';

  systemd.user.services.mx-master-dpi = {
    description = "Set MX Master 4 DPI";
    serviceConfig.Type = "oneshot";
    # HID++ can lag the hidraw node by a moment after connecting
    script = ''
      for _ in 1 2 3 4 5; do
        ${pkgs.solaar}/bin/solaar config "MX Master 4" dpi ${toString dpi} && exit 0
        sleep 1
      done
      exit 1
    '';
  };
}
