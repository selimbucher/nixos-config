{ inputs, pkgs, config, ... }:
{
  home.packages = with pkgs; [
    inputs.kiwi.packages.${pkgs.stdenv.hostPlatform.system}.default
    inputs.selim-icons.packages.${pkgs.stdenv.hostPlatform.system}.default
    rofi
  ];
}
