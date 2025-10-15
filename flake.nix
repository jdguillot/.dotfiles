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
      inputs.nixpkgs.follows = "nixpkgs";  # Follow the same nixpkgs version
    };
    nix-flatpak.url = "github:gmodena/nix-flatpak";
    nixos-conf-editor.url = "github:snowfallorg/nixos-conf-editor";
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    vscode-server.url = "github:nix-community/nixos-vscode-server";
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
#    pst-bin.url = "path:./programs/pst";
    kickstart-nvim.url = "git+file:./programs/kickstart-nix.nvim";
#    tasmotizer.url = "path:./programs/tasmotizer";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    isd.url = "github:kainctl/isd";
  };

  outputs = inputs@{ self, nixpkgs, home-manager, nix-flatpak, nixos-wsl, vscode-server, nix-vscode-extensions, nix-index-database, nixpkgs-stable, nixpkgs-temp, kickstart-nvim, sops-nix, ... }:
  
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        
        config = {
          allowUnfree = true;
        };
        
        overlays = [
          nix-vscode-extensions.overlays.default
          kickstart-nvim.overlays.default
        ];
      };
      pkgs-stable = import nixpkgs-stable { inherit system; };
      pkgs-temp = import nixpkgs-temp { inherit system; };
      secrets = builtins.fromJSON (builtins.readFile "${self}/secrets/secrets.json");
    in {

      nixosConfigurations = {
        razer-nixos = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs system pkgs secrets;
          };
          modules = [
            ./hosts/razer-nixos/configuration.nix
            nix-index-database.nixosModules.nix-index
            # nix-flatpak.nixosModules.nix-flatpak
            sops-nix.nixosModules.sops
            home-manager.nixosModules.home-manager
            {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = {
              flake-inputs = inputs;
              inherit pkgs-stable pkgs-temp;
            };
            home-manager.backupFileExtension = "backup";

            home-manager.users."cyberfighter".imports = [
              ./hosts/razer-nixos/home.nix
              ./hosts/razer-nixos/flatpak.nix
              nix-flatpak.homeManagerModules.nix-flatpak
            ];
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
            # {
            #   nixpkgs.overlays = [
            #     kickstart-nvim.overlays.default
            #   ];
            # }
            ./hosts/work-wsl/configuration.nix
            nixos-wsl.nixosModules.default
            nix-index-database.nixosModules.nix-index
            {
              system.stateVersion = "25.05";
              wsl.enable = true;
              wsl.defaultUser = "jdguillot";
              wsl.docker-desktop.enable = true;
            }
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = {
                flake-inputs = inputs;
                inherit pkgs-stable pkgs-temp;
              };
              home-manager.backupFileExtension = "backup";
              # Optionally, use home-manager.extraSpecialArgs to pass
              # arguments to home.nix

              home-manager.users."jdguillot".imports = [
                ./hosts/work-wsl/home.nix
                # ./hosts/work-wsl/flatpak.nix
                # nix-flatpak.homeManagerModules.nix-flatpak
              ];
            }
            vscode-server.nixosModules.default
            ({ config, pkgs, ... }: {
              services.vscode-server.enable = true;
            })
          ];
        };


      };
    };

}
