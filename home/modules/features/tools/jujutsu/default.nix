{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.tools.jujutsu;
  sopsSecrets = config.sops.secrets or { };
  nameSecretPath = sopsSecrets."personal-info/fullname".path or null;
  emailSecretPath = sopsSecrets."personal-info/email".path or null;
  useSecretsForIdentity = cfg.useSecretsForIdentity && nameSecretPath != null && emailSecretPath != null;
in
{
  options.cyberfighter.features.tools.jujutsu = {
    enable = lib.mkEnableOption "Jujutsu VCS";

    userName = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "User name for Jujutsu (ignored when useSecretsForIdentity is true)";
    };

    userEmail = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "User email for Jujutsu (ignored when useSecretsForIdentity is true)";
    };

    useSecretsForIdentity = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Read user.name and user.email from sops personal-info secrets at activation";
    };

    extraSettings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Extra settings for Jujutsu";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      programs.jujutsu = {
        enable = true;
        settings =
          (lib.optionalAttrs (!useSecretsForIdentity && cfg.userName != "" && cfg.userEmail != "") {
            user = {
              name = cfg.userName;
              email = cfg.userEmail;
            };
          })
          // cfg.extraSettings;
      };
    }

    # When using sops secrets, write jj identity via activation script
    (lib.mkIf useSecretsForIdentity {
      home.activation.jjIdentityFromSops = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        _jj_name=$(cat "${nameSecretPath}")
        _jj_email=$(cat "${emailSecretPath}")
        _jj_config="${config.home.homeDirectory}/.config/jj/config.toml"
        if [ -f "$_jj_config" ]; then
          $DRY_RUN_CMD ${lib.getExe pkgs.gnused} -i \
            -e "s|^name = .*|name = \"$_jj_name\"|" \
            -e "s|^email = .*|email = \"$_jj_email\"|" \
            "$_jj_config"
        fi
      '';
    })
  ]);
}
