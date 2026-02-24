{
  description = "Selim's Unified NixOS Config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";    

    desktop = {
      url = "path:/home/selim/Documents/Coding/hyprland-widgets";
      # url = "github:selimbucher/hyprland-widgets";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    whitesur-src = {
      url = "github:vinceliuice/WhiteSur-icon-theme";
      flake = false;
    };
    
    slimmer-icons = {
      url = "github:selimbucher/WhiteSur-steam-icons";
      flake = false;
    };

    rofi-theme = {
      url = "github:selimbucher/rofi-theme";
      flake = false;
    };
    
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland.url = "github:hyprwm/Hyprland/v0.53.1";


    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };
    
    Hyprspace = {
      url = "github:KZDKM/Hyprspace";
      inputs.hyprland.follows = "hyprland";
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
          inputs.hyprland.nixosModules.default

          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            
            # home-manager.sharedModules = [ inputs.desktop.homeManagerModules.default ];
            
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
