{ inputs, config, pkgs, lib, hostName, ... }:
{
  imports = 
    lib.filesystem.listFilesRecursive ./home
    ++ [ 
      inputs.kiwi.homeManagerModules.default 
    ];

  home.username = "selim";
  home.homeDirectory = "/home/${config.home.username}";
  home.stateVersion = "25.11";
}