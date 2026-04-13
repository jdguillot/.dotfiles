{
  config,
  lib,
  hostMeta,
  ...
}:
{
  cyberfighter.features.sops.enable = lib.mkDefault true;

  xdg.configFile."git/scripts/personal-signing-key".text = ''
    #!/run/current-system/sw/bin/bash
    printf "key::"
    op read "op://Private/${hostMeta.system.hostname}/public key"
  '';
  xdg.configFile."git/scripts/personal-signing-key".executable = true;

  sops.templates.git-identity-personal = {
    content = ''
      [user]
      	name = ${config.sops.placeholder."personal-info/fullname"}
      	email = ${config.sops.placeholder."personal-info/email"}
      [commit]
      	gpgsign = true
      [gpg]
      	format = ssh
      [gpg "ssh"]
      	defaultKeyCommand = ${config.xdg.configHome}/git/scripts/personal-signing-key
      [tag]
      	gpgSign = true
    '';
    path = "${config.xdg.configHome}/git/identities/personal.gitconfig";
  };
}
