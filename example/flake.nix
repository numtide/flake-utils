{
  description = "Flake utils demo";
  edition = 201909;

  inputs.utils = {
    type = "git";
    uri = "file:///home/zimbatm/go/src/github.com/zimbatm/flake-utils";
  };

  outputs = { self, nixpkgs, utils }:
    utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system}; in
      rec {
        packages.hello = pkgs.hello;
        defaultPackage = packages.hello;
        apps.hello = utils.lib.mkApp packages.hello;
        defaultApp = apps.hello;
      }
    );
}
