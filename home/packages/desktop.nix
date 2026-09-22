{ inputs, pkgs, config, ... }:
{
  # kiwi-shell through its module, which builds its Hyprland plugin against
  # the system's Hyprland
  services.kiwi-shell.enable = true;

  home.packages = with pkgs; [
    # selim-icons is installed by home/theme.nix instead, as gtk.iconTheme.package,
    # with the folder-size patch applied. Listing it here as well put two
    # derivations of the same icon theme into the profile and buildEnv refused
    # to merge their icon-theme.cache files.
  ];
}
