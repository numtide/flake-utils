{
  description = "Pure Nix flake utility functions";
  outputs = { self }: {
    lib = import ./.;
    templates = {
      simple-flake = {
        path = ./examples/simple-flake;
        description = "A flake using flake-utils.lib.simpleFlake";
      };
      each-system = {
        path = ./examples/each-system;
        description = "A flake using flake-utils.lib.eachDefaultSystem";
      };
      check-utils = {
        path = ./examples/check-utils;
        description = "A flake with tests";
      };
    };
    defaultTemplate = self.templates.each-system;
  };
}
