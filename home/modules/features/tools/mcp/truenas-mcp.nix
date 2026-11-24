# TrueNAS's own MCP server (truenas/truenas-mcp), built from the release tag.
# The pin is frozen: a bump also needs vendorHash refreshed, so
# `npins unfreeze truenas-mcp && npins update truenas-mcp`, then fix the hash.
{ pkgs }:

let
  src = (import ../../../../../npins).truenas-mcp;
  # Retiring the workaround leaves `pkgs.buildGoModule;`.
  buildGoModule =
    pkgs.buildGoModule
    # WORKAROUND(truenas-mcp-go-version)
    # go.mod and the test suite require 1.27.4 (stdlib fix GO-2026-6859).
    .override {
      go = pkgs.go.overrideAttrs {
        version = "1.27.4";
        src = pkgs.fetchurl {
          url = "https://go.dev/dl/go1.27.4.src.tar.gz";
          hash = "sha256-c8+4VxrsDAEXdofbhxY9Rqog6XeWcncokaoXZU2aYJk=";
        };
      };
    }
    # END WORKAROUND(truenas-mcp-go-version)
    ;
in
buildGoModule (finalAttrs: {
  pname = "truenas-mcp";
  version = pkgs.lib.removePrefix "v" src.version;
  inherit src;

  vendorHash = "sha256-RCcyGLepRB1YMTb6hvAyskYTzHrKlwqjRdnRLfdydls=";

  subPackages = [ "cmd/truenas-mcp" ];
  env.CGO_ENABLED = 0;
  ldflags = [
    "-s"
    "-w"
    "-X main.Version=${finalAttrs.version}"
  ];

  meta = {
    description = "TrueNAS MCP server";
    homepage = "https://github.com/truenas/truenas-mcp";
    license = pkgs.lib.licenses.gpl3Only;
    mainProgram = "truenas-mcp";
  };
})
