let
  # The list of systems supported by nixpkgs and hydra
  defaultSystems = [
    "aarch64-linux"
    "aarch64-darwin"
    "i686-linux"
    "x86_64-darwin"
    "x86_64-linux"
  ];

  # List of all systems defined in nixpkgs
  # Keep in sync with nixpkgs wit the following command:
  # $ nix-instantiate --json --eval --expr "with import <nixpkgs> {}; lib.platforms.all" | jq 'sort' | sed 's!,!!'

  allSystems = [
    "aarch64-darwin"
    "aarch64-genode"
    "aarch64-linux"
    "aarch64-netbsd"
    "aarch64-none"
    "aarch64_be-none"
    "arm-none"
    "armv5tel-linux"
    "armv6l-linux"
    "armv6l-netbsd"
    "armv6l-none"
    "armv7a-darwin"
    "armv7a-linux"
    "armv7a-netbsd"
    "armv7l-linux"
    "armv7l-netbsd"
    "avr-none"
    "i686-cygwin"
    "i686-darwin"
    "i686-freebsd"
    "i686-genode"
    "i686-linux"
    "i686-netbsd"
    "i686-none"
    "i686-openbsd"
    "i686-windows"
    "js-ghcjs"
    "m68k-linux"
    "m68k-netbsd"
    "m68k-none"
    "mips64el-linux"
    "mipsel-linux"
    "mipsel-netbsd"
    "mmix-mmixware"
    "msp430-none"
    "or1k-none"
    "powerpc-netbsd"
    "powerpc-none"
    "powerpc64-linux"
    "powerpc64le-linux"
    "powerpcle-none"
    "riscv32-linux"
    "riscv32-netbsd"
    "riscv32-none"
    "riscv64-linux"
    "riscv64-netbsd"
    "riscv64-none"
    "s390-linux"
    "s390-none"
    "s390x-linux"
    "s390x-none"
    "vc4-none"
    "wasm32-wasi"
    "wasm64-wasi"
    "x86_64-cygwin"
    "x86_64-darwin"
    "x86_64-freebsd"
    "x86_64-genode"
    "x86_64-linux"
    "x86_64-netbsd"
    "x86_64-none"
    "x86_64-openbsd"
    "x86_64-redox"
    "x86_64-solaris"
    "x86_64-windows"
  ];

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
