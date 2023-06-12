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
            else if isDerivation value then (merged.${name} or { }) // { ${system} = value; }
            else pushDownSystem system (merged.${name} or { }) value);

      # Merge together the outputs for all systems.
      op = attrs: system:
        let
          ret = f system;
          op = attrs: key:
            let
              appendSystem = key: system: ret:
                if key == "hydraJobs"
                then (pushDownSystem system (attrs.hydraJobs or { }) ret.hydraJobs)
                else { ${system} = ret.${key}; };
            in
            attrs //
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

  # Meld merges subflakes using common inputs.  Useful when you want
  # to split up a large flake with many different components into more
  # manageable parts.
  #
  # For example:
  #
  #   {
  #     inputs = {
  #       flutils.url = "github:numtide/flake-utils";
  #       nixpkgs.url = "github:nixos/nixpkgs";
  #     };
  #     outputs = inputs@{ flutils, ... }: flutils.lib.meld inputs [
  #       ./nix/packages
  #       ./nix/hardware
  #       ./nix/overlays
  #       # ...
  #     ];
  #   }
  #
  # Where ./nix/packages/default.nix looks like just the output
  # portion of a flake.
  #
  #   { flutils, nixpkgs, ... }: flutils.lib.eachDefaultSystem (system:
  #     let pkgs = import nixpkgs { inherit system; }; in
  #     {
  #       packages = {
  #         foo = ...;
  #         bar = ...;
  #         # ...
  #       };
  #     }
  #   )
  #
  # You can also use meld within the subflakes to further subdivide
  # your flake into a tree like structure.  For example,
  # ./nix/hardware/default.nix might look like:
  #
  #  inputs@{ flutils, ... }: flutils.lib.meld inputs [
  #    ./foobox.nix
  #    ./barbox.nix
  #  ]
  meld = let
    # Pulled from nixpkgs.lib
    recursiveUpdateUntil =
      # Predicate, taking the path to the current attribute as a list of strings for attribute names, and the two values at that path from the original arguments.
      pred:
      # Left attribute set of the merge.
      lhs:
      # Right attribute set of the merge.
      rhs:
      let
        f = attrPath:
          builtins.zipAttrsWith (n: values:
            let here = attrPath ++ [ n ];
            in if builtins.length values == 1
            || pred here (builtins.elemAt values 1) (builtins.head values) then
              builtins.head values
            else
              f here values);
      in f [ ] [ rhs lhs ];

    # Pulled from nixpkgs.lib
    recursiveUpdate =
      # Left attribute set of the merge.
      lhs:
      # Right attribute set of the merge.
      rhs:
      recursiveUpdateUntil (path: lhs: rhs: !(builtins.isAttrs lhs && builtins.isAttrs rhs)) lhs
      rhs;
  in inputs:
  builtins.foldl' (output: subflake:
    recursiveUpdate output (import subflake inputs)) { };

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
      meld
      mkApp
      simpleFlake
      system
      ;
  };
in
lib
