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

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak";
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    vscode-server.url = "github:nix-community/nixos-vscode-server";

    catppuccin.url = "github:catppuccin/nix";
    isd.url = "github:kainctl/isd";
    #    pst-bin.url = "path:./programs/pst";
    #    tasmotizer.url = "path:./programs/tasmotizer";
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      nix-flatpak,
      nixpkgs-stable,
      sops-nix,
      catppuccin,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      pkgs-stable = import nixpkgs-stable { inherit system; };

      # Import centralized host metadata
      hostConfigs = import ./hosts/default.nix;

      # Shared special args
      sharedSpecialArgs = hostMeta: {
        inherit
          inputs
          system
          pkgs-stable
          hostMeta
          ;
        hostProfile = hostMeta.profile;
      };

      # Helper function to create NixOS system configuration
      mkNixosSystem =
        hostname: hostMeta:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = sharedSpecialArgs hostMeta;
          modules = [
            ./hosts/${hostname}/configuration.nix
            sops-nix.nixosModules.sops
            catppuccin.nixosModules.catppuccin
          ];
        };

      # Helper function to create home-manager configuration
      mkHomeConfig =
        hostname: hostMeta:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          extraSpecialArgs = sharedSpecialArgs hostMeta;
          modules = [
            ./home/${hostMeta.system.username}/home.nix
            nix-flatpak.homeManagerModules.nix-flatpak
            catppuccin.homeModules.catppuccin
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
        nixos-portable = mkNixosSystem "nixos-portable" hostConfigs.nixos-portable;
      };

      homeConfigurations = {
        "cyberfighter@razer-nixos" = mkHomeConfig "razer-nixos" hostConfigs.razer-nixos;
        "jdguillot@work-nix-wsl" = mkHomeConfig "work-nix-wsl" hostConfigs.work-nix-wsl;
        "cyberfighter@ryzn-nix-wsl" = mkHomeConfig "ryzn-nix-wsl" hostConfigs.ryzn-nix-wsl;
        "cyberfighter@sys-galp-nix" = mkHomeConfig "sys-galp-nix" hostConfigs.sys-galp-nix;
      };
    };

}
