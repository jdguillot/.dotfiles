{ config, lib, ... }:

let
  cfg = config.cyberfighter.features.git;
in
{
  options.cyberfighter.features.git = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Git configuration";
    };

    userName = lib.mkOption {
      type = lib.types.str;
      default = "user";
      description = "Git user name";
    };

    userEmail = lib.mkOption {
      type = lib.types.str;
      default = "user@example.com";
      description = "Git user email";
    };

    extraSettings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Extra Git settings";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.git = {
      enable = true;
      settings = {
        init.defaultBranch = "main";
        pull.rebase = true;
        diff.tool = "nvimdiff";
        user = {
          name = cfg.userName;
          email = cfg.userEmail;
        };
      } // cfg.extraSettings;
    };
  };
}