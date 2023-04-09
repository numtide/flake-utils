{
  description = "Pure Nix flake utility functions";

  # Externally extensible flake systems. See <https://github.com/nix-systems/nix-systems>.
  inputs.systems.url = "github:nix-systems/default";

  outputs = { self, systems }: {
    lib = import ./lib.nix {
      defaultSystems = import systems;
    };
    templates = {
      default = self.templates.each-system;
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
  };
}
