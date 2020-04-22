let
  # copied from <nixpkgs/lib>
  genAttrs = names: f:
    builtins.listToAttrs (map (n: { name = n; value = f n; }) names);

  mapAttrsToList = f: attrs:
    map (name: f name attrs.${name}) (builtins.attrNames attrs);

  # The list of systems supported by nixpkgs and hydra
  defaultSystems = [
    "aarch64-linux"
    "i686-linux"
    "x86_64-darwin"
    "x86_64-linux"
  ];

  # eachSystem using defaultSystems
  eachDefaultSystem = eachSystem defaultSystems;

  # Builds a map from <attr>=value to <system>.<attr>=value for each system.
  #
  #
  eachSystem = systems: f:
    let
      op = attrs: system:
        let
          ret = f system;
          opt = attrs: key:
            attrs //
            {
              ${key} = (attrs.${key} or {}) // { ${system} = ret.${key}; };
            }
            ;
        in
        builtins.foldl' op attrs (builtins.attrNames ret);
    in
    builtins.foldl' op {} systems
    ;

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
in
{
  inherit
    defaultSystems
    eachDefaultSystem
    eachSystem
    mkApp
    ;
}
