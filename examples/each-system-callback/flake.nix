{
  description = "Flake utils demo";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem {
      generic =
        {
          lib = {
            system-independent = "hi";
          };
        };
      callback = system:
        let pkgs = nixpkgs.legacyPackages.${system}; in
        rec {
          lib = {
            system-specific = "hi from ${system}";
          };

          packages = flake-utils.lib.flattenTree {
            hello = pkgs.hello;
            gitAndTools = pkgs.gitAndTools;
          };
          defaultPackage = packages.hello;
          apps.hello = flake-utils.lib.mkApp { drv = packages.hello; };
          defaultApp = apps.hello;
        };
    };
}
