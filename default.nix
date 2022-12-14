import ./lib.nix {
  allSystems = import ./systems/all.nix;
  systems = import ./systems;
}
