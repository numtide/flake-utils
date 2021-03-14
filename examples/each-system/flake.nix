{
  description = "Flake utils demo";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system}; in
      rec {
        lib = {
          system = system;

          generic = {
            inc = a: a + 1;
          };
        };

        packages = flake-utils.lib.flattenTree {
          hello = pkgs.hello;
          gitAndTools = pkgs.gitAndTools;

          printLib = pkgs.writeShellScriptBin "hello" ''
            echo ${self.lib."${system}".system}
            echo ${toString (self.lib.inc 41)}
          '';
        };
        defaultPackage = packages.hello;

        apps.hello = flake-utils.lib.mkApp { drv = packages.hello; };
        defaultApp = apps.hello;
      }
    );
}
