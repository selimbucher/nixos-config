# Plug-in Wine

The giang17/wine fork pinned in `source.json`, plus `patches/` applied in file name order.

## Move to a newer fork branch

```sh
cd ~/.nixos
overlays/wine/update.sh                      # newest d2d1-dcomp-* branch
overlays/wine/update.sh d2d1-dcomp-11.23     # or a specific one
```

If it stops at a patch, fix the conflicted files in `~/.cache/wine-update`, then:

```sh
git -C ~/.cache/wine-update add <files>
overlays/wine/update.sh --continue
```

If the new branch makes that patch unnecessary:

```sh
git -C ~/.cache/wine-update am --skip
overlays/wine/update.sh --continue
```

To give up (nothing in `overlays/wine` has changed yet):

```sh
git -C ~/.cache/wine-update am --abort
```

## Build and switch

```sh
git add overlays/wine
nix build .#nixosConfigurations.desktop.pkgs.yabridge --cores 8 -j 1 --no-link   # about 1 h
rb
```

## Change or add a patch

```sh
cd ~/.cache/wine-update            # branch `update` = fork branch + patches/
# edit, then amend the patch's commit or add a new commit
~/.nixos/overlays/wine/update.sh --export
```
