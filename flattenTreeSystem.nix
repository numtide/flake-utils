system: tree:
let
  op = sum: path: val:
    let
      pathStr = builtins.concatStringsSep "/" path;
    in
    # Ignore values that are not attrsets
    if (builtins.typeOf val) != "set" then
      sum
    # For derivations
    else if val ? type && val.type == "derivation" then
      let
        meta = val.meta or { };
        platforms = meta.hydraPlatforms or meta.platforms or [ ];
      in
      # Only include those that target this system
      if builtins.any (p: p == system) platforms then
        (sum // {
          # We used to use the derivation outPath as the key, but that crashes Nix
          # so fallback on constructing a static key
          "${pathStr}" = val;
        })
      else
        sum
    # Recurse into attrsets who have that key
    else if (val.recurseForDerivations or false) == true then
      recurse sum path val
    # Ignore that value as well
    else
      sum
  ;

  recurse = sum: path: val:
    builtins.foldl'
      (sum: key: op sum (path ++ [ key ]) val.${key})
      sum
      (builtins.attrNames val)
  ;
in
recurse { } [ ] tree
