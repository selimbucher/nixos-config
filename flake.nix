{
  description = "Selim's Unified NixOS Config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

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

    whitesur-src = {
      url = "github:vinceliuice/WhiteSur-icon-theme";
      flake = false;
    };

    selim-icons = {
      url = "github:selimbucher/WhiteSur-steam-icons";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    rofi-theme = {
      url = "github:selimbucher/rofi-theme";
      flake = false;
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland.url = "github:hyprwm/Hyprland/v0.55.2";

    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };

    Hyprspace = {
      url = "github:KZDKM/Hyprspace";
      inputs.hyprland.follows = "hyprland";
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
            inputs.hyprland.nixosModules.default
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
