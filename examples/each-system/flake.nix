{
  description = "Flake utils demo";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system}; in
      {
        packages = {
          default = pkgs.hello;
          # `nix run .#find` will work because findutils.meta.mainProgram is set to "find".
          find = pkgs.findutils;
        };
        # Use apps to expose packages that have multiple binaries.
        apps = {
          xargs = flake-utils.lib.mkApp {
            drv = pkgs.findutils;
            name = "xargs";
          };
          ls = flake-utils.lib.mkApp {
            drv = pkgs.coreutils;
            name = "ls";
          };
        };
      }
    );
}
