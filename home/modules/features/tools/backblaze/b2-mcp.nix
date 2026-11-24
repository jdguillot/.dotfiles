# Backblaze's official B2 MCP server (backblaze-labs/b2-mcp), built from the
# release tag. The pin is frozen: a bump also needs the pnpmDeps hash
# refreshed, so `npins unfreeze b2-mcp && npins update b2-mcp`, then fix the hash.
{ pkgs }:

let
  src = (import ../../../../../npins).b2-mcp;
  pnpm = pkgs.pnpm_11;
  # engines: ^22.22.2 || ^24 || ^26
  nodejs = pkgs.nodejs_22;
in
pkgs.stdenv.mkDerivation (finalAttrs: {
  pname = "b2-mcp";
  version = pkgs.lib.removePrefix "v" src.version;
  inherit src;

  nativeBuildInputs = [
    nodejs
    pnpm
    pkgs.pnpmConfigHook
    pkgs.pnpmBuildHook
    pkgs.makeWrapper
  ];

  pnpmDeps = pkgs.fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    inherit pnpm;
    fetcherVersion = 5;
    hash = "sha256-cUcsreJ/M+s1aUyDlC6khWZcxMTE1YH6ohdppHPADsM=";
  };

  installPhase = ''
    runHook preInstall
    # Drop the dev toolchain (vercel, wrangler, vitest, ...) from the closure.
    pnpm prune --prod --ignore-scripts
    mkdir -p $out/lib/b2-mcp $out/bin
    cp -r dist node_modules package.json $out/lib/b2-mcp/
    makeWrapper ${nodejs}/bin/node $out/bin/b2-mcp \
      --add-flags $out/lib/b2-mcp/dist/index.js
    runHook postInstall
  '';

  meta = {
    description = "Backblaze B2 Cloud Storage MCP server";
    homepage = "https://github.com/backblaze-labs/b2-mcp";
    license = pkgs.lib.licenses.mit;
    mainProgram = "b2-mcp";
  };
})
