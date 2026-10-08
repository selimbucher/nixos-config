{ inputs, config, pkgs, lib, hostName, ... }:
{
  imports = 
    # emacs is left out of the build; its module stays for later
    builtins.filter (f: f != ./home/apps/emacs.nix)
      (lib.filesystem.listFilesRecursive ./home)
    ++ [ 
      inputs.kiwi.homeManagerModules.default 
    ];

  home.username = "selim";
  home.homeDirectory = "/home/${config.home.username}";
  home.stateVersion = "25.11";
}