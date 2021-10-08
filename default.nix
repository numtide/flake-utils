let
  # The list of systems supported by nixpkgs and hydra
  defaultSystems = [
    "x86_64-linux"
    "aarch64-linux"
    "x86_64-darwin"
    "aarch64-darwin"
    "armv6l-linux"
    "armv7l-linux"
    "i686-linux"
    "mipsel-linux"
  ];

  # List of all systems defined in nixpkgs
  # Keep in sync with nixpkgs wit the following command:
  # $ nix-instantiate --json --eval --expr "with import <nixpkgs> {}; lib.platforms.all" | jq
  allSystems = [
    "i686-cygwin"
    "x86_64-cygwin"
    "x86_64-darwin"
    "i686-darwin"
    "aarch64-darwin"
    "armv7a-darwin"
    "i686-freebsd"
    "x86_64-freebsd"
    "aarch64-genode"
    "i686-genode"
    "x86_64-genode"
    "x86_64-solaris"
    "js-ghcjs"
    "aarch64-linux"
    "armv5tel-linux"
    "armv6l-linux"
    "armv7a-linux"
    "armv7l-linux"
    "i686-linux"
    "m68k-linux"
    "mipsel-linux"
    "powerpc64-linux"
    "powerpc64le-linux"
    "riscv32-linux"
    "riscv64-linux"
    "s390-linux"
    "s390x-linux"
    "x86_64-linux"
    "mmix-mmixware"
    "aarch64-netbsd"
    "armv6l-netbsd"
    "armv7a-netbsd"
    "armv7l-netbsd"
    "i686-netbsd"
    "m68k-netbsd"
    "mipsel-netbsd"
    "powerpc-netbsd"
    "riscv32-netbsd"
    "riscv64-netbsd"
    "x86_64-netbsd"
    "aarch64-none"
    "arm-none"
    "armv6l-none"
    "avr-none"
    "i686-none"
    "msp430-none"
    "or1k-none"
    "m68k-none"
    "powerpc-none"
    "riscv32-none"
    "riscv64-none"
    "s390-none"
    "s390x-none"
    "vc4-none"
    "x86_64-none"
    "i686-openbsd"
    "x86_64-openbsd"
    "x86_64-redox"
    "wasm64-wasi"
    "wasm32-wasi"
    "x86_64-windows"
    "i686-windows"
  ];

  # eachSystem using defaultSystems
  eachDefaultSystem = eachSystem defaultSystems;

  # Builds a map from <attr>=value to <attr>.<system>=value for each system.
  #
  #
  eachSystem = systems: f:
    let
      op = attrs: system:
        let
          ret = f system;
          op = attrs: key:
            attrs //
            {
              ${key} = (attrs.${key} or { }) // { ${system} = ret.${key}; };
            }
          ;
        in
        builtins.foldl' op attrs (builtins.attrNames ret);
    in
    builtins.foldl' op { } systems
  ;

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
  simpleFlake = import ./simpleFlake.nix { inherit lib; };

  # Helper functions for Nix evaluation
  check-utils = import ./check-utils.nix;

  lib = {
    inherit
      allSystems
      check-utils
      defaultSystems
      eachDefaultSystem
      eachSystem
      filterPackages
      flattenTree
      mkApp
      simpleFlake
      ;
  };
in
lib
