{

  description = "My First Flake";

  inputs = {
    # # This is the long form of both of below
    nixpkgs.url = "nixpkgs/nixos-unstable";

    nixpkgs-stable.url = "nixpkgs/nixos-25.05";
    nixpkgs-temp.url = "github:NixOS/nixpkgs/5a917406275ee76a0ccdd9f598a6eed57d7f5cff";

    # Home-manager using the same nixpkgs
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs"; # Follow the same nixpkgs version
    };
    nix-flatpak.url = "github:gmodena/nix-flatpak";
    nixos-conf-editor.url = "github:snowfallorg/nixos-conf-editor";
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    vscode-server.url = "github:nix-community/nixos-vscode-server";
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    #    pst-bin.url = "path:./programs/pst";
    #    tasmotizer.url = "path:./programs/tasmotizer";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    isd.url = "github:kainctl/isd";
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nix-flatpak,
      nixos-wsl,
      vscode-server,
      nix-vscode-extensions,
      nix-index-database,
      nixpkgs-stable,
      nixpkgs-temp,
      sops-nix,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;

        config = {
          allowUnfree = true;
        };

        overlays = [
          nix-vscode-extensions.overlays.default
        ];
      };
      pkgs-stable = import nixpkgs-stable { inherit system; };
      pkgs-temp = import nixpkgs-temp { inherit system; };
      secrets = builtins.fromJSON (builtins.readFile "${self}/secrets/secrets.json");
    in
    {

      nixosConfigurations = {
        razer-nixos = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit
              inputs
              system
              secrets
              ;
          };
          modules = [
            ./hosts/razer-nixos/configuration.nix
            # nix-index-database.nixosModules.nix-index
            # nix-flatpak.nixosModules.nix-flatpak
            sops-nix.nixosModules.sops
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = {
                  inherit inputs pkgs-stable pkgs-temp;
                };
                backupFileExtension = "backup";

                users."cyberfighter".imports = [
                  ./home/cyberfighter/home.nix
                  # ./hosts/razer-nixos/flatpak.nix
                  nix-flatpak.homeManagerModules.nix-flatpak
                ];
              };
            }
          ];
        };

        nixos = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs system;
            inherit secrets;
          };
          modules = [
            ./hosts/work-wsl/configuration.nix
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = {
                  inherit inputs pkgs-stable pkgs-temp;
                };
                backupFileExtension = "backup";
                users."jdguillot".imports = [
                  ./home/jdguillot/home.nix
                ];
              };
            }
          ];
        };

        ryzn-nix-wsl = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs system;
            inherit secrets;
          };
          modules = [
            ./hosts/ryzn-wsl/configuration.nix
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = {
                  inherit inputs pkgs-stable pkgs-temp;
                };
                backupFileExtension = "backup";
                users."cyberfighter".imports = [
                  ./home/cyberfighter/home.nix
                ];
              };
            }
          ];
        };

        nixos-portable = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs system;
            inherit secrets;
          };
          modules = [
            ./hosts/nixos-portable/configuration.nix
            nix-index-database.nixosModules.nix-index
            {
              system.stateVersion = "25.05";
            }
          ];
        };

      };
      # homeConfigurations = {
      #   "jdguillot@nixos" = home-manager.lib.homeManagerConfiguration {
      #     pkgs = nixpkgs.legacyPackages.${system};
      #     extraSpecialArgs = { inherit inputs outputs; };
      #     modules = [ ./home/jdguillot/home.nix ];
      #   };
      # };
    };

}
