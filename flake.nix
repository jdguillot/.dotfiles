{

  description = "My First Flake";

  inputs = {
    # # This is the long form of both of below
    nixpkgs.url = "nixpkgs/nixos-unstable";

    nixpkgs-stable.url = "nixpkgs/nixos-25.05";

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
      # secrets = builtins.fromJSON (builtins.readFile "${self}/secrets/secrets.json");
    in
    {

      nixosConfigurations = {
        razer-nixos = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit
              inputs
              system
              ;
          };
          modules = [
            ./hosts/razer-nixos/configuration.nix
            sops-nix.nixosModules.sops
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = { inherit inputs pkgs-stable system; };
                users.cyberfighter = import ./home/cyberfighter/home.nix;
                sharedModules = [ nix-flatpak.homeManagerModules.nix-flatpak ];
              };
            }
          ];
        };

        work-nix-wsl = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs system;
          };
          modules = [
            ./hosts/work-wsl/configuration.nix
            sops-nix.nixosModules.sops
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = { inherit inputs pkgs-stable system; };
                users.jdguillot = import ./home/jdguillot/home.nix;
              };
            }
          ];
        };

        ryzn-nix-wsl = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs system;
          };
          modules = [
            ./hosts/ryzn-wsl/configuration.nix
            sops-nix.nixosModules.sops
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = { inherit inputs pkgs-stable system; };
                users.cyberfighter = import ./home/cyberfighter/home.nix;
              };
            }
          ];
        };

        sys-galp-nix = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit
              inputs
              system
              ;
          };
          modules = [
            ./hosts/sys-galp-nix/configuration.nix
            sops-nix.nixosModules.sops
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = { inherit inputs pkgs-stable system; };
                users.cyberfighter = import ./home/cyberfighter/home.nix;
                sharedModules = [ nix-flatpak.homeManagerModules.nix-flatpak ];
              };
            }
          ];
        };

        nixos-portable = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs system;
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

      homeConfigurations = {
        "cyberfighter@razer-nixos" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          extraSpecialArgs = {
            inherit inputs pkgs-stable system;
          };
          modules = [
            ./home/cyberfighter/home.nix
            nix-flatpak.homeManagerModules.nix-flatpak
          ];
        };

        "jdguillot@work-nix-wsl" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          extraSpecialArgs = {
            inherit inputs pkgs-stable system;
          };
          modules = [
            ./home/jdguillot/home.nix
          ];
        };

        "cyberfighter@ryzn-nix-wsl" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          extraSpecialArgs = {
            inherit inputs pkgs-stable system;
          };
          modules = [
            ./home/cyberfighter/home.nix
          ];
        };

        "cyberfighter@sys-galp-nix" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          extraSpecialArgs = {
            inherit inputs pkgs-stable system;
          };
          modules = [
            ./home/cyberfighter/home.nix
            nix-flatpak.homeManagerModules.nix-flatpak
          ];
        };
      };
    };

}
