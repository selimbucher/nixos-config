{ inputs, pkgs, config, ... }:
{
  home.packages = with pkgs; [
    inputs.kiwi.packages.${pkgs.stdenv.hostPlatform.system}.default
    # selim-icons is installed by home/theme.nix instead, as gtk.iconTheme.package,
    # with the folder-size patch applied. Listing it here as well put two
    # derivations of the same icon theme into the profile and buildEnv refused
    # to merge their icon-theme.cache files.
  ];
}
