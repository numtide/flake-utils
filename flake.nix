{
  description = "Pure Nix flake utility functions";
  outputs = { self }: {
    lib = import ./.;
  };
}
