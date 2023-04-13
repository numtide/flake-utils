{
  # The list of systems supported by nixpkgs and hydra
  defaultSystems ? [
    "aarch64-linux"
    "aarch64-darwin"
    "x86_64-darwin"
    "x86_64-linux"
  ]
}:
let
  inherit defaultSystems;

  # List of all systems defined in nixpkgs
  # Keep in sync with nixpkgs wit the following command:
  # $ nix-instantiate --json --eval --expr "with import <nixpkgs> {}; lib.platforms.all" | jq 'sort' | sed 's!,!!' > allSystems.nix
  allSystems = import ./allSystems.nix;

  # A map from system to system. It's useful to detect typos.
  #
  # Instead of typing `"x86_64-linux"`, type `flake-utils.lib.system.x86_64-linux`
  # and get an error back if you used a dash instead of an underscore.
  system =
    builtins.listToAttrs
      (map (system: { name = system; value = system; }) allSystems);

  # eachSystem using defaultSystems
  eachDefaultSystem = eachSystem defaultSystems;

  # Builds a map from <attr>=value to <attr>.<system>=value for each system
  #
  eachSystem = systems: f:
    let
      # Merge together the outputs for all systems.
      op = attrs: system:
        let
          ret = f system;
          op = attrs: key: attrs //
              {
                ${key} = (attrs.${key} or { })
                  // { ${system} = ret.${key}; };
              }
          ;
        in
        builtins.foldl' op attrs (builtins.attrNames ret);
    in
    builtins.foldl' op { } systems
  ;

  # eachSystemMap using defaultSystems
  eachDefaultSystemMap = eachSystemMap defaultSystems;

  # Builds a map from <attr>=value to <system>.<attr> = value.
  eachSystemMap = systems: f: builtins.listToAttrs (builtins.map (system: { name = system; value = f system; }) systems);

  # Nix flakes insists on having a flat attribute set of derivations in
  # various places like the `packages` and `checks` attributes.
  #
  # This function traverses a tree of attributes (by respecting
  # recurseIntoAttrs) and only returns their derivations, with a flattened
  # key-space.
  #
  # Eg:
  #
  #   flattenTree { hello = pkgs.hello; gitAndTools = pkgs.gitAndTools };
  #
  # Returns:
  #
  #   {
  #      hello = «derivation»;
  #      "gitAndTools/git" = «derivation»;
  #      "gitAndTools/hub" = «derivation»;
  #      # ...
  #   }
  flattenTree = tree: import ./flattenTree.nix tree;

  # Nix check functionality validates packages for various conditions, like if
  # they build for any given platform or if they are marked broken.
  #
  # This function filters a flattend package set for conditinos that
  # would *trivially* break `nix flake check`. It does not flatten a tree and it
  # does not implement advanced package validation checks.
  #
  # Eg:
  #
  #   filterPackages "x86_64-linux" {
  #     hello = pkgs.hello;
  #     "gitAndTools/git" = pkgs.gitAndTools // {meta.broken = true;};
  #    };
  #
  # Returns:
  #
  #   {
  #      hello = «derivation»;
  #   }
  filterPackages = import ./filterPackages.nix { inherit allSystems; };

  # Returns the structure used by `nix app`
  mkApp =
    { drv
    , name ? drv.pname or drv.name
    , exePath ? drv.passthru.exePath or "/bin/${name}"
    }:
    {
      type = "app";
      program = "${drv}${exePath}";
    };

  # This function tries to capture a common flake pattern.
  simpleFlake = import ./simpleFlake.nix { inherit lib defaultSystems; };

  # Helper functions for Nix evaluation
  check-utils = import ./check-utils.nix;

  lib = {
    inherit
      allSystems
      check-utils
      defaultSystems
      eachDefaultSystem
      eachSystem
      eachDefaultSystemMap
      eachSystemMap
      filterPackages
      flattenTree
      mkApp
      simpleFlake
      system
      ;
  };
in
lib
