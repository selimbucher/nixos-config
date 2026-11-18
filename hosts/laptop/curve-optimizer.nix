# Curve Optimizer: every core of the Ryzen AI 9 HX 370 runs each clock at a
# lower voltage (an undervolt). The firmware has no setting for it; the SMU
# takes it from ryzenadj and keeps it until the chip powers off, so it is set
# at boot and after every wake (hibernation powers the chip off).
# Stress-tested 2026-11-16 (Prime95 per core and all cores, ~/.cache/co-sweep).
{ pkgs, ... }:

let
  # negative: less voltage; one count is a few mV
  counts = -30;
  sleepTargets = [ "suspend.target" "hibernate.target" "hybrid-sleep.target" "suspend-then-hibernate.target" ];
in
{
  systemd.services.curve-optimizer = {
    description = "Ryzen Curve Optimizer offset";
    wantedBy = [ "multi-user.target" ] ++ sleepTargets;
    after = sleepTargets;
    serviceConfig.Type = "oneshot";
    # the SMU takes negative counts as 20-bit two's complement; batlog reads /run/curve-optimizer
    script = ''
      ${pkgs.ryzenadj}/bin/ryzenadj --set-coall=${toString (1048576 + counts)}
      echo ${toString counts} > /run/curve-optimizer
    '';
  };
}
