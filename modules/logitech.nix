# MX Master hardware DPI. The mice reset to 1000 on every (re)connect, so
# udev starts a oneshot user service on each connect that sets it again.
#   solaar config "MX Master 4" dpi        # read
#   solaar config "MX Master 4" dpi 4000   # try a value live
{ config, lib, pkgs, ... }:

let
  dpi = config.deviceConfig.mouseDpi;
  # Bluetooth product ID -> solaar device name
  mice = {
    B042 = "MX Master 4";
    B034 = "MX Master 3S";
  };
in
lib.mkIf (dpi != null) {
  # solaar CLI + udev rules giving the logged-in user hidraw access
  programs.solaar.enable = true;

  services.udev.extraRules = lib.concatStrings (lib.mapAttrsToList (pid: _: ''
    ACTION=="add", SUBSYSTEM=="hidraw", KERNELS=="0005:046D:${pid}.*", TAG+="systemd", ENV{SYSTEMD_USER_WANTS}+="mx-master-dpi-${lib.toLower pid}.service"
  '') mice);

  systemd.user.services = lib.mapAttrs' (pid: name:
    lib.nameValuePair "mx-master-dpi-${lib.toLower pid}" {
      description = "Set ${name} DPI";
      serviceConfig.Type = "oneshot";
      # HID++ can lag the hidraw node by a moment after connecting
      script = ''
        for _ in 1 2 3 4 5; do
          ${pkgs.solaar}/bin/solaar config "${name}" dpi ${toString dpi} && exit 0
          sleep 1
        done
        exit 1
      '';
    }) mice;
}
