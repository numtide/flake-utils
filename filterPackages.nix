{ allSystems }:
system: packages:
let
  # Adopted from nixpkgs.lib
  inherit (builtins) listToAttrs concatMap attrNames;
  nameValuePair = name: value: { inherit name value; };
  filterAttrs = pred: set:
    listToAttrs (
      concatMap
        (name:
          let v = set.${name}; in
          if pred name v then [ (nameValuePair name v) ] else [ ]
        )
        (attrNames set)
    );

  # Everything that nix flake check requires for the packages output
  sieve = n: v:
    with v;
    let
      inherit (builtins) isAttrs;
      isDerivation = x: isAttrs x && x ? type && x.type == "derivation";
      isBroken = meta.broken or false;
      platforms = meta.hydraPlatforms or meta.platforms or allSystems;
    in
    # check for isDerivation, so this is independently useful of
      # flattenTree, which also does filter on derviations
    isDerivation v && !isBroken && builtins.elem system platforms
  ;
in
filterAttrs sieve packages
