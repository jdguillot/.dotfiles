{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.tools.jujutsu;
in
{
  options.cyberfighter.features.tools.jujutsu = {
    enable = lib.mkEnableOption "Jujutsu VCS";

    userName = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "User name for Jujutsu";
    };

    userEmail = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "User email for Jujutsu";
    };

    extraSettings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Extra settings for Jujutsu";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.jujutsu = {
      enable = true;
      settings = {
        user = lib.mkIf (cfg.userName != "" && cfg.userEmail != "") {
          name = cfg.userName;
          email = cfg.userEmail;
        };
      } // cfg.extraSettings;
    };
  };
}
