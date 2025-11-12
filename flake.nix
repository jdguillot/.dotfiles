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
      nixpkgs,
      home-manager,
      nix-flatpak,
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
        config.allowUnfree = true;
        overlays = [ nix-vscode-extensions.overlays.default ];
      };
      pkgs-stable = import nixpkgs-stable { inherit system; };

      # Import centralized host metadata
      hostConfigs = import ./hosts/default.nix;

      # Helper function to create NixOS system configuration
      mkNixosSystem =
        hostname: hostMeta:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs system;
            inherit (hostMeta) profile;
            hostProfile = hostMeta.profile;
            inherit hostMeta;
          };
          modules = [
            ./hosts/${hostname}/configuration.nix
            sops-nix.nixosModules.sops
          ];
        };

      # Helper function to create home-manager configuration
      mkHomeConfig =
        hostname: hostMeta:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          extraSpecialArgs = {
            inherit inputs system;
            inherit (hostMeta) profile;
            inherit pkgs-stable;
            hostProfile = hostMeta.profile;
            inherit hostMeta;
          };
          modules = [
            ./home/${hostMeta.system.username}/home.nix
            nix-flatpak.homeManagerModules.nix-flatpak
          ]
          # ++ (if hostname == "razer-nixos" || hostname == "sys-galp-nix" then [ ] else [ ])
          ;
        };
    in
    {
      nixosConfigurations = {
        razer-nixos = mkNixosSystem "razer-nixos" hostConfigs.razer-nixos;
        work-nix-wsl = mkNixosSystem "work-wsl" hostConfigs.work-nix-wsl;
        ryzn-nix-wsl = mkNixosSystem "ryzn-wsl" hostConfigs.ryzn-nix-wsl;
        sys-galp-nix = mkNixosSystem "sys-galp-nix" hostConfigs.sys-galp-nix;

        nixos-portable = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs system;
            hostProfile = hostConfigs.nixos-portable.profile;
            hostMeta = hostConfigs.nixos-portable;
          };
          modules = [
            ./hosts/nixos-portable/configuration.nix
            nix-index-database.nixosModules.nix-index
          ];
        };
      };

      homeConfigurations = {
        "cyberfighter@razer-nixos" = mkHomeConfig "razer-nixos" hostConfigs.razer-nixos;
        "jdguillot@work-nix-wsl" = mkHomeConfig "work-nix-wsl" hostConfigs.work-nix-wsl;
        "cyberfighter@ryzn-nix-wsl" = mkHomeConfig "ryzn-nix-wsl" hostConfigs.ryzn-nix-wsl;
        "cyberfighter@sys-galp-nix" = mkHomeConfig "sys-galp-nix" hostConfigs.sys-galp-nix;
      };
    };

}
