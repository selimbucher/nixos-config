{
  description = "Selim's Unified NixOS Config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    
    whitesur-src = {
      url = "github:vinceliuice/WhiteSur-icon-theme";
      flake = false;
    };
    
    slimmer-icons = {
      url = "github:SlimmerCH/Slimmer-icon-theme";
      flake = false;
    };
    
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland.url = "github:hyprwm/Hyprland";
    
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };
    
    ags = {
      url = "github:aylur/ags";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs: {
    nixosConfigurations = {
      

      laptop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        # Pass inputs AND hostname to all modules
        specialArgs = { 
          inherit inputs; 
          hostName = "laptop"; 
        };
        modules = [
          ./hosts/laptop/configuration.nix
          
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            
            # Pass inputs and hostname to home-manager
            home-manager.extraSpecialArgs = { 
              inherit inputs; 
              hostName = "laptop"; 
            };
            
            home-manager.users.selim = import ./home.nix;
          }
        ];
      };


      desktop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        # Pass inputs AND hostname to all modules
        specialArgs = { 
          inherit inputs; 
          hostName = "desktop"; 
        };
        modules = [
          ./hosts/desktop/configuration.nix
          
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            
            # Pass inputs and hostname to home-manager
            home-manager.extraSpecialArgs = { 
              inherit inputs; 
              hostName = "desktop"; 
            };
            
            home-manager.users.selim = import ./home.nix;
          }
        ];
      };

    };
  };
}