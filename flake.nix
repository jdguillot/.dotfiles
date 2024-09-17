{

  description = "My First Flake";

  inputs = {
    # # This is the long form of both of below
    # nixpkgs = {
    #   url = "github:NixOS/nixpkgs/nixos-24.05";
    # };
    # # This is shorthand for the above
    # nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    # # The below only works for nixpkgs because it
    # # knows where it is from.
    # Pin nixpkgs to the unstable channel
    nixpkgs.url = "nixpkgs/nixos-unstable";

    # Home-manager using the same nixpkgs
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";  # Follow the same nixpkgs version
    };
    nix-flatpak.url = "github:gmodena/nix-flatpak";
    nixos-conf-editor.url = "github:snowfallorg/nixos-conf-editor";
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    vscode-server.url = "github:nix-community/nixos-vscode-server";
  };

  outputs = inputs@{ self, nixpkgs, home-manager, nix-flatpak, nixos-wsl, vscode-server, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
      };
      secrets = builtins.fromJSON (builtins.readFile "${self}/secrets/secrets.json");
      # hm-config = {
        
      # };
    in {
      # # hostname = razer-nixos
      # nixosConfigurations.${hostname} = nixpkgs.lib.nixosSystem {
      #   inherit system;
      #   specialArgs = { inherit inputs system; };
      #   modules = [
      #     flatpaks.nixosModules.nix-flatpak
      #     ./configuration.nix
      #   ];
      # };

      # # hostname = razer-nixos
      
      # nixosConfigurations.${hostname}  = nixpkgs.lib.nixosSystem {
      #   inherit system;
      #   specialArgs = { inherit inputs system; };
      #   modules = [
      #     ./home.nix
      #     home-manager.nixosModules.home-manager
      #     {
      #       home-manager.useGlobalPkgs = true;
      #       home-manager.useUserPackages = true;
      #       home-manager.extraSpecialArgs.flake-inputs = inputs;
      #       home-manager.users."cyberfighter".imports = [
      #         flatpaks.homeManagerModules.nix-flatpak
      #         ./flatpak.nix
      #       ];
      #       # home-manager.users.antani.home.stateVersion = "23.11";
      #     }
      #   ];
      # };

      nixosConfigurations = {
        razer-nixos = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs system;
            inherit secrets;
          };
          modules = [
            ./hosts/razer-nixos/configuration.nix
            # nix-flatpak.nixosModules.nix-flatpak
            home-manager.nixosModules.home-manager
            {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs.flake-inputs = inputs;
            home-manager.backupFileExtension = "backup";
            # Optionally, use home-manager.extraSpecialArgs to pass
            # arguments to home.nix

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
            ./hosts/work-wsl/configuration.nix
            nixos-wsl.nixosModules.default
            {
              system.stateVersion = "24.05";
              wsl.enable = true;
              wsl.defaultUser = "jdguillot";
              wsl.docker-desktop.enable = true;
            }
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs.flake-inputs = inputs;
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
