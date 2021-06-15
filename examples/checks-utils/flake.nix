{
  description = "Flake utils demo";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        inherit (flake-utils.lib.check-utils system) isEqual hasKey;
        testDataset = { key1 = "value1"; key2 = 123; key3 = "some>value with^invalid&characters"; };
      in
      rec {
        checks = {
          # Successful cases
          success_isEqual = isEqual testDataset.key1 "value1";
          success_hasKey = hasKey testDataset "key2";

          # Failing cases
          failure_isEqual = isEqual testDataset.key1 "failing-data";
          failure_hasKey = hasKey testDataset "failing-data";

          # Formatting
          formatting_number = isEqual testDataset.key2 123;
          formatting_null = isEqual null null;
          formatting_invalid_chars = isEqual testDataset.key3 "some>value with^invalid&characters";

        };
      }
    );
}
