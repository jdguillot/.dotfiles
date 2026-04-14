{
  config,
  lib,
  hostProfile,
  ...
}:
lib.mkIf (hostProfile != "minimal") {
  cyberfighter.features.sops.enable = lib.mkDefault true;

  xdg.configFile."git/scripts/work-signing-key".text = ''
    #!/run/current-system/sw/bin/bash
    printf "key::"
    op read "op://Private/WSL-Work/public key"
  '';
  xdg.configFile."git/scripts/work-signing-key".executable = true;

  sops.templates.git-identity-work = {
    content = ''
      [user]
      	name = ${config.sops.placeholder."personal-info/work-github"}
      	email = ${config.sops.placeholder."personal-info/work-email"}
      [commit]
      	gpgsign = true
      [gpg]
      	format = ssh
      [gpg "ssh"]
      	defaultKeyCommand = ${config.xdg.configHome}/git/scripts/work-signing-key
      [tag]
      	gpgSign = true
    '';
    path = "${config.xdg.configHome}/git/identities/work.gitconfig";
  };
}
