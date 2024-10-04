{
  description = "Pastebin Tool";

  outputs = { self, nixpkgs }: {
    defaultPackage.x86_64-linux = self.packages.x86_64-linux.pst-bin;

    packages.x86_64-linux.pst-bin =
      let
        pkgs = import nixpkgs { system = "x86_64-linux"; };

        my-name = "pst";
        pst-bin = pkgs.writeShellScriptBin my-name ''

		# Change the url accordingly
		URL="https://bin.mesa-automation-test.cloud"

		FILEPATH="$1"
		FILENAME=$(basename -- "$FILEPATH")
		EXTENSION="''${FILENAME##*.}"
		RESPONSE=$(curl --data-binary @''${FILEPATH:-/dev/stdin} --url $URL)
		PASTELINK="$URL$RESPONSE"

        [ -z "$EXTENSION" ] && \
	        echo "$PASTELINK" || \
	        echo "$PASTELINK.$EXTENSION"

        '';
        my-buildInputs = with pkgs; [ ];
      in pkgs.symlinkJoin {
        name = my-name;
        paths = [ pst-bin ] ++ my-buildInputs;
        buildInputs = [ pkgs.makeWrapper ];
        postBuild = "wrapProgram $out/bin/${my-name} --prefix PATH : $out/bin";
      };
  };
}
