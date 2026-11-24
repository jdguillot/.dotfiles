{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.tools.backblaze;
  creds = cfg.credentials;
  # Credentials live in secrets.yaml, not secrets_common.yaml (personal info
  # only, readable by every user key); home sops needs the file named.
  secretsYaml = ../../../../../secrets/secrets.yaml;
  keyIdPath = config.sops.secrets.${creds.keyIdSecret}.path;
  keyPath = config.sops.secrets.${creds.keySecret}.path;
  awsCredsPath = config.sops.templates."backblaze-s3-credentials".path;
  endpoint = "https://s3.${cfg.region}.backblazeb2.com";

  # nixpkgs installs the CLI as `backblaze-b2`; upstream docs all say `b2`.
  # With sops credentials it authorizes from them unless the caller set its own.
  b2 = pkgs.writeShellScriptBin "b2" ''
    ${lib.optionalString creds.enable ''
      : "''${B2_APPLICATION_KEY_ID:=$(cat ${keyIdPath})}"
      : "''${B2_APPLICATION_KEY:=$(cat ${keyPath})}"
      export B2_APPLICATION_KEY_ID B2_APPLICATION_KEY
    ''}
    exec ${pkgs.backblaze-b2}/bin/backblaze-b2 "$@"
  '';

  # stu speaks S3; B2's S3 endpoint takes the key ID as the access key. A
  # credentials file of its own so ~/.aws stays untouched.
  stuB2 = pkgs.writeShellScriptBin "stu-b2" ''
    export AWS_SHARED_CREDENTIALS_FILE=${awsCredsPath}
    exec ${pkgs.stu}/bin/stu --endpoint-url ${endpoint} --region ${cfg.region} "$@"
  '';
in
{
  options.cyberfighter.features.tools.backblaze = {
    enable = lib.mkEnableOption "Backblaze B2 tools (b2 CLI, stu S3 TUI, b2-mcp)" // {
      default = config.cyberfighter.traits.dev;
      defaultText = lib.literalExpression "config.cyberfighter.traits.dev";
    };

    region = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "us-west-004";
      description = ''
        The account's B2 region (the `s3.<region>.backblazeb2.com` part of the
        bucket endpoint). Needed for `stu-b2`; the MCP server discovers it.
      '';
    };

    credentials = {
      enable = lib.mkEnableOption ''
        an application key from sops (secrets/secrets.yaml), wired into `b2`,
        `stu-b2` and the `backblaze` MCP entry. Only for homes whose user age
        key is a recipient of that file; an undecryptable secret fails the
        whole sops-nix user unit
      '';

      keyIdSecret = lib.mkOption {
        type = lib.types.str;
        default = "backblaze/key-id";
        description = "sops secret holding the application key ID.";
      };

      keySecret = lib.mkOption {
        type = lib.types.str;
        default = "backblaze/application-key";
        description = "sops secret holding the application key.";
      };
    };

    mcpPackage = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = import ./b2-mcp.nix { inherit pkgs; };
      description = "The b2-mcp build, shared with the MCP catalog.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !creds.enable || config.cyberfighter.features.sops.enable;
        message = "cyberfighter.features.tools.backblaze.credentials needs cyberfighter.features.sops.enable.";
      }
    ];

    home.packages = [
      b2
      pkgs.stu
      # Bare `b2-mcp` for project-scoped MCP configs.
      cfg.mcpPackage
    ]
    ++ lib.optional (creds.enable && cfg.region != null) stuB2;

    sops = lib.mkIf creds.enable {
      secrets.${creds.keyIdSecret}.sopsFile = secretsYaml;
      secrets.${creds.keySecret}.sopsFile = secretsYaml;
      templates."backblaze-s3-credentials".content = ''
        [default]
        aws_access_key_id = ${config.sops.placeholder.${creds.keyIdSecret}}
        aws_secret_access_key = ${config.sops.placeholder.${creds.keySecret}}
      '';
    };
  };
}
