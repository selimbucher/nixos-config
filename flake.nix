{
  description = "Selim's Unified NixOS Config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Stable, intentionally un-followed: activitywatch is broken/uncached on
    # unstable (aw-webui CI failure) but prebuilt & cached on stable.
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.05";

    secrets.url = "git+ssh://git@github.com/selimbucher/nixos-secrets";

    kiwi = {
      # url = "path:/home/selim/Documents/Coding/kiwi-shell";
      url = "github:selimbucher/kiwi-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    native-instruments = {
      url = "github:selimbucher/native-instruments";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    qylock = {
      url = "github:Darkkal44/qylock";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    whitesur-src = {
      url = "github:vinceliuice/WhiteSur-icon-theme";
      flake = false;
    };

    selim-icons = {
      url = "github:selimbucher/WhiteSur-steam-icons";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    claude-code-nix = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    claude-desktop-bin = {
      url = "github:patrickjaja/claude-desktop-bin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
    let
      mkHome = hostName: {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.backupFileExtension = "backup";
        home-manager.extraSpecialArgs = { inherit inputs hostName; };
        home-manager.users.selim = import ./home.nix;
      };
    in {
      nixosConfigurations = {

        laptop = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs; hostName = "laptop"; };
          modules = [
            ./hosts/laptop/configuration.nix
            home-manager.nixosModules.home-manager
            (mkHome "laptop")
          ];
        };

        desktop = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs; hostName = "desktop"; };
          modules = [
            ./hosts/desktop/configuration.nix
            home-manager.nixosModules.home-manager
            (mkHome "desktop")
          ];
        };

      };
    };
}
