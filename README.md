# nixos-config

Unified NixOS + home-manager config for `laptop` and `desktop`.

## Installing on a new machine

The flake has one private input, `secrets` (`git+ssh://github.com/selimbucher/nixos-secrets`),
which a fresh machine can't fetch before an SSH key is set up. Install with the
empty stand-in in `secrets-stub/` instead, then switch to the real input later.

From the NixOS installer, after partitioning and mounting at `/mnt`:

```sh
nixos-generate-config --root /mnt --show-hardware-config > /tmp/hw.nix
# compare against hosts/<host>/hardware-configuration.nix and update the repo if needed

nixos-install --flake 'github:selimbucher/nixos-config#laptop' \
  --override-input secrets 'github:selimbucher/nixos-config?dir=secrets-stub'
```

After first boot:

```sh
# put ~/.ssh/id_ed25519 in place and add it to GitHub, then
git clone git@github.com:selimbucher/nixos-config ~/Documents/Code/nixos-config
cd ~/Documents/Code/nixos-config
sudo nixos-rebuild switch --flake .#laptop
```

The plain rebuild fetches `nixos-secrets` from the lock file, which enables the
`~/Drive` WebDAV mount, the `hetzner` SSH alias, and Thunderbird sender logos.
Until then those three things are inert; everything else works.

Replace `laptop` with `desktop` for the other host.
