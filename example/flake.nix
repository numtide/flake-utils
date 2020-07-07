{
  description = "Flake utils demo";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system}; in
      rec {
        packages.hello = pkgs.hello;
        defaultPackage = packages.hello;
        apps.hello = flake-utils.lib.mkApp { drv = packages.hello; };
        defaultApp = apps.hello;
      }
    );
}
