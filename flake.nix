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
  };

  outputs = inputs@{ self, nixpkgs, home-manager, nix-flatpak, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
      };
    in {
      nixosConfigurations = {
        razer-nixos = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs system; };
          modules = [
            ./configuration.nix
            nix-flatpak.nixosModules.nix-flatpak
            home-manager.nixosModules.home-manager
              {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.users.cyberfighter = import ./home.nix;

                # Optionally, use home-manager.extraSpecialArgs to pass
                # arguments to home.nix
            }
          ];
        };
      };
    };

}
