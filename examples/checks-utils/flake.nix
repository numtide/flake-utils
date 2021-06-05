{
  description = "Flake utils demo";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ flake-utils.overlays.checks-utils ];
        };

        testDataset = { key1 = "value1"; key2 = "value2"; key3 = "value3"; };
      in
      rec {
        checks = {
          valid_key1 = pkgs.isEqual testDataset.key1 "value1";
          contains_key2 = pkgs.hasKey testDataset "key2";
        };
      }
    );
}
