rec {
  # copied from <nixpkgs/lib>
  genAttrs = names: f:
    builtins.listToAttrs (map (n: { name = n; value = f n; }) names);

  # The list of systems supported by nixpkgs and hydra
  supportedSystems = [
    "aarch64-linux"
    "i686-linux"
    "x86_64-darwin"
    "x86_64-linux"
  ];

  # Returns an attribute set with all the supported systems as keys and the
  # output of the passed function with each system passed to it.
  #
  # This is useful in the flake outputs because the outputs return static sets
  # that map to the different systems.
  #
  # Example:
  #   forAllSupported (x: null)
  #   > { aarch64-linux = null; i686-linux = null; x86_64-darwin = null;
  #   > x86_64-linux = null; }
  # (system -> attrs) -> attrs
  forAllSupported = genAttrs supportedSystems;

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
}
