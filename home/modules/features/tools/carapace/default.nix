{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.tools.carapace;
in
{
  options.cyberfighter.features.tools.carapace = {
    enable = lib.mkEnableOption "Carapace multi-shell completion";

    enableZshIntegration = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Zsh integration";
    };

    enableBashIntegration = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Bash integration";
    };

    enableFishIntegration = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Fish integration";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.carapace = {
      enable = true;
      inherit (cfg) enableZshIntegration enableBashIntegration enableFishIntegration;
    };
  };
}
