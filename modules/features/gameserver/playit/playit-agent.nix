{ lib, pkgs }:
pkgs.stdenv.mkDerivation rec {
  pname = "playit-agent";
  version = "0.17.1";

  src = pkgs.fetchurl {
    url = "https://github.com/playit-cloud/playit-agent/releases/download/v${version}/playit-linux-amd64";
    sha256 = "0md5z0j63vscizgnbf6fzl2rk1zyyjhxbph6db1kw7majcyld3g7";
  };

  dontUnpack = true;
  dontBuild = true;

  nativeBuildInputs = [ pkgs.autoPatchelfHook ];

  installPhase = ''
    mkdir -p $out/bin
    cp $src $out/bin/playit-cli
    chmod +x $out/bin/playit-cli
  '';

  meta = {
    mainProgram = "playit-cli";
    description = "playit.gg tunnel agent CLI";
    homepage = "https://playit.gg";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}
