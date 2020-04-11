{
  description = "Pure Nix flake utility functions";
  edition = 201909;
  outputs = { self }: {
    lib = import ./.;
  };
}
