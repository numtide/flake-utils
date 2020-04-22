# flake-utils

**STATUS: WIP**

Pure Nix flake utility functions.

The goal of this project is to build a collection of pure Nix functions that don't
depend on nixpkgs, and that are useful in the context of writing other Nix
flakes.

## Usage

`flake.nix`
```nix
{
  edition = 201909;
  description = "My flake";
  inputs = {
    utils = { type = "github"; owner = "numtide"; repo = "flake-utils"; };
  };
  outputs = { self, nixpkgs, utils }:
    utils.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system}; in
      rec {
        packages = {
          my-app = pkgs.callPackage ./my-app.nix {};
        };

        defaultPackage = package.my-app;

        apps = {
          my-app = flake.mkApp packages.my-app;
        };

        defaultApp = apps.my-app;
      };
    );
}
```

