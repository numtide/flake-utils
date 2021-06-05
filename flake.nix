{
  description = "Pure Nix flake utility functions";
  outputs = { self }: {
    lib = import ./.;
    overlays.checks-utils = import ./checks-utils.nix;
  };
}
