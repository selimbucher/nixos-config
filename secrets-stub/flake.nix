# Stand-in for the private nixos-secrets flake, for installing on a machine
# that has no GitHub SSH key yet. Same attribute names, empty values: the
# drive mount and mail logos simply do nothing until the real input is used.
#
#   nixos-install --flake 'github:selimbucher/nixos-config#laptop' \
#     --override-input secrets 'github:selimbucher/nixos-config?dir=secrets-stub'
#
# After first boot, put the SSH key in place and run a plain
# `nixos-rebuild switch --flake .#laptop` to pick up the real values.
{
  description = "Empty stand-in for nixos-secrets";
  outputs = { self }: {
    hetznerIp = "";
    driveWebdavPass = "";
    mailLogosToken = "";
  };
}
