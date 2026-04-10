# Nix derivation for AstroTuxLauncher
# https://github.com/JoeJoeTV/AstroTuxLauncher
{ pkgs }:

let
  version = "1.1.11";

  # pansi is not in nixpkgs; build from PyPI
  pansi = pkgs.python3Packages.buildPythonPackage rec {
    pname = "pansi";
    version = "2020.7.3";
    format = "setuptools";

    src = pkgs.fetchPypi {
      inherit pname version;
      hash = "sha256-vRgtUEUo+HBgGssCgq3tQRrQCgFIQnsOU6EhYvTnTc8=";
    };

    meta = {
      description = "Text mode rendering library";
      homepage = "https://github.com/technige/pansi";
      license = pkgs.lib.licenses.asl20;
    };
  };

  pythonEnv = pkgs.python3.withPackages (
    p: with p; [
      alive-progress
      chardet
      colorlog
      dataclasses-json
      ipy
      packaging
      pansi
      pathvalidate
      psutil
      requests
      tomli
      tomli-w
    ]
  );

  runtimeDeps = [
    pkgs.wineWow64Packages.staging
    pkgs.dotnet-sdk_8
    pkgs.depotdownloader
    pkgs.winetricks
    pkgs.gnutls
  ];

in
pkgs.python3Packages.buildPythonApplication {
  pname = "AstroTuxLauncher";
  inherit version;

  src = pkgs.fetchFromGitHub {
    owner = "JoeJoeTV";
    repo = "AstroTuxLauncher";
    rev = version;
    hash = "sha256-O9ZMwDioP848BXfZaUs/Bp0MyxK8t7ixI+7eAa7xXsc=";
  };

  format = "other";

  nativeBuildInputs = [
    pythonEnv
    pkgs.makeWrapper
  ];

  dontBuild = true;

  installPhase = ''
    install -d $out/libexec/AstroTuxLauncher
    cp -r ./* $out/libexec/AstroTuxLauncher/
    install -d $out/bin

    makeWrapper ${pythonEnv.interpreter} $out/bin/AstroTuxLauncher \
      --add-flags "$out/libexec/AstroTuxLauncher/AstroTuxLauncher.py" \
      --add-flags "-d ${pkgs.depotdownloader}/bin/DepotDownloader" \
      --prefix PATH : ${pkgs.lib.makeBinPath runtimeDeps}
  '';

  meta = {
    description = "Dedicated Astroneer server launcher for Linux using WINE";
    homepage = "https://github.com/JoeJoeTV/AstroTuxLauncher";
    license = pkgs.lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = "AstroTuxLauncher";
  };
}
