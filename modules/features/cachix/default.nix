{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.cachix;
in
{
  options.cyberfighter.features.cachix = {
    enable = lib.mkEnableOption "Enable devenv cachix substituter";
  };
  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        environment.systemPackages = with pkgs; [
          cachix
        ];
      }

      {
        assertions = [
          {
            assertion = config.cyberfighter.features.sops.enable or false;
            message = "Cachix requires SOPS to be enabled for managing credentials";
          }
        ];

        sops.secrets."cachix-auth-token" = lib.mkIf (builtins.pathExists ../../../secrets/secrets.yaml) {
          owner = "${config.cyberfighter.system.username}";
        };

        environment.shellInit = ''
          export CACHIX_AUTH_TOKEN=$(cat ${config.sops.secrets."cachix-auth-token".path})
        '';
      }
    ]
  );

}
