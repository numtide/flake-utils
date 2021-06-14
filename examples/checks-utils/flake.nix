{
  description = "Flake utils demo";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        inherit (flake-utils.lib.check-utils system) isEqual hasKey;

        testDataset = { key1 = "value1"; key2 = "value2"; key3 = "value3"; };
      in
      rec {
        checks = {
          valid_key1 = isEqual testDataset.key1 "value1";
          contains_key2 = hasKey testDataset "key2";

          failing_valid_key1 = isEqual testDataset.key1 "failing-data";
          failing_contains_key2 = hasKey testDataset "failing-data";

          number_formatting_isEqual = isEqual testDataset.key1 123;
          number_formatting_hasKey = hasKey testDataset 123;

          null_formatting_key1 = isEqual testDataset.key1 null;
          null_formatting_hasKey = hasKey testDataset null;
        };
      }
    );
}
