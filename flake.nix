{
  description = "Pure Nix flake utility functions";

  inputs.systems.flake = false;
  inputs.systems.url = "path:./systems";

  outputs = { self, systems }: {
    lib = import ./lib.nix {
      allSystems = import (systems + "/all.nix");
      systems = import systems;
    };
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
