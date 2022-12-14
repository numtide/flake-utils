{ # The list of all valid systems
  allSystems
  # The list of systems chosen for evaluation
, systems
}:
let
  # Included from `nixpkgs/lib/trivial.nix`.
  warn =
    if builtins.elem (builtins.getEnv "NIX_ABORT_ON_WARN") ["1" "true" "yes"]
    then msg: builtins.trace "[1;31mwarning: ${msg}[0m" (abort "NIX_ABORT_ON_WARN=true; warnings are treated as unrecoverable errors.")
    else msg: builtins.trace "[1;31mwarning: ${msg}[0m";

  # A map from system to system. It's useful to detect typos.
  #
  # Instead of typing `"x86_64-linux"`, type `flake-utils.lib.system.x86_64-linux`
  # and get an error back if you used a dash instead of an underscore.
  system =
    builtins.listToAttrs
      (map (system: { name = system; value = system; }) allSystems);

  # eachSystem using systems
  eachDefaultSystem = eachSystem systems;

  # Builds a map from <attr>=value to <attr>.<system>=value for each system,
  # except for the `hydraJobs` attribute, where it maps the inner attributes,
  # from hydraJobs.<attr>=value to hydraJobs.<attr>.<system>=value.
  #
  eachSystem = systems: f:
    let
      # Taken from <nixpkgs/lib/attrsets.nix>
      isDerivation = x: builtins.isAttrs x && x ? type && x.type == "derivation";

      # Used to match Hydra's convention of how to define jobs. Basically transforms
      #
      #     hydraJobs = {
      #       hello = <derivation>;
      #       haskellPackages.aeson = <derivation>;
      #     }
      #
      # to
      #
      #     hydraJobs = {
      #       hello.x86_64-linux = <derivation>;
      #       haskellPackages.aeson.x86_64-linux = <derivation>;
      #     }
      #
      # if the given flake does `eachSystem [ "x86_64-linux" ] { ... }`.
      pushDownSystem = system: merged:
        builtins.mapAttrs
          (name: value:
            if ! (builtins.isAttrs value) then value
            else if isDerivation value then (merged.${name} or {}) // { ${system} = value; }
            else pushDownSystem system (merged.${name} or {}) value);

      # Merge together the outputs for all systems.
      op = attrs: system:
        let
          ret = f system;
          op = attrs: key:
            let
              appendSystem = key: system: ret:
                if key == "hydraJobs"
                  then (pushDownSystem system (attrs.hydraJobs or {}) ret.hydraJobs)
                  else { ${system} = ret.${key}; };
            in attrs //
              {
                ${key} = (attrs.${key} or { })
                  // (appendSystem key system ret);
              }
          ;
        in
        builtins.foldl' op attrs (builtins.attrNames ret);
    in
    builtins.foldl' op { } systems
  ;

  # eachSystemMap using systems
  eachDefaultSystemMap = eachSystemMap systems;

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
  simpleFlake = import ./simpleFlake.nix { inherit lib systems; };

  # Helper functions for Nix evaluation
  check-utils = import ./check-utils.nix;

  lib = {
    inherit
      allSystems
      check-utils
      eachDefaultSystem
      eachSystem
      eachDefaultSystemMap
      eachSystemMap
      filterPackages
      flattenTree
      mkApp
      simpleFlake
      system
      systems
      ;
    defaultSystems = warn "`lib.defaultSystems` is deprecated, use `lib.systems` instead!"
      systems;
  };
in
lib
