{ config, lib, ... }:

let
  cfg = config.cyberfighter.features.git;
  sopsAvailable = (config.sops.secrets or { }) != { };
  useSecretsForIdentity = cfg.useSecretsForIdentity && sopsAvailable;
  gitconfigTemplateName = "git-identity";
  gitconfigTemplatePath = "${config.xdg.configHome}/sops-nix/templates/${gitconfigTemplateName}";
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
      default = "";
      description = "Git user name (ignored when useSecretsForIdentity is true)";
    };

    userEmail = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Git user email (ignored when useSecretsForIdentity is true)";
    };

    useSecretsForIdentity = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Read user.name and user.email from sops secrets via a rendered template";
    };

    nameSecretKey = lib.mkOption {
      type = lib.types.str;
      default = "personal-info/fullname";
      description = "SOPS secret key for git user.name";
    };

    emailSecretKey = lib.mkOption {
      type = lib.types.str;
      default = "personal-info/email";
      description = "SOPS secret key for git user.email";
    };

    extraSettings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Extra Git settings";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        programs.git = {
          enable = true;
          signing.format = null; # This was changed in later version of HM and because my stateVersion i need this
          settings = {
            init.defaultBranch = "main";
            pull.rebase = true;
            pager = {
              diff = "delta";
              log = "delta";
              reflog = "delta";
              show = "delta";
            };
            status = {
              branch = true;
              showStash = true;
              showUntrackedFiles = "all";
            };
            diff = {
              tool = "nvimdiff";
              context = 3;
              renames = "copies";
              interHunkContext = 10;
            };
            core.pager = "delta";
            interactive.diffFilter = "delta --color-only";
            delta = {
              features = "catppuccin-frappe";
              navigate = true;
              side-by-side = true;
              line-numbers = true;
              dark = true;
            };
          }
          // (lib.optionalAttrs (!useSecretsForIdentity && cfg.userName != "" && cfg.userEmail != "") {
            user = {
              name = cfg.userName;
              email = cfg.userEmail;
            };
          })
          // cfg.extraSettings;

          # Include the sops-rendered identity file at runtime
          includes = lib.mkIf useSecretsForIdentity [
            { path = gitconfigTemplatePath; }
          ];
        };
      }

      # Render a [user] gitconfig snippet from sops secrets
      (lib.mkIf useSecretsForIdentity {
        sops.templates.${gitconfigTemplateName} = {
          content = ''
            [user]
            	name = ${config.sops.placeholder.${cfg.nameSecretKey}}
            	email = ${config.sops.placeholder.${cfg.emailSecretKey}}
          '';
          path = gitconfigTemplatePath;
        };
      })
    ]
  );
}
