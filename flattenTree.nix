tree:
let
  op = sum: path: val:
    let
      pathStr = builtins.concatStringsSep "/" path;
    in
    if isDerivation val then
    # builtins.trace "${pathStr} is a derivation"
    # we used to use the derivation outPath as the key, but that crashes Nix
    # so fallback on constructing a static key
      (sum // {
        "${pathStr}" = val;
      })
    else if val ? recurseForDerivations && val.recurseForDerivations == true then
    # builtins.trace "${pathStr} is a recursive"
    # recurse into that attribute set
      (recurse sum path val)
    else
    # ignore that value
    # builtins.trace "${pathStr} is something else"
      sum
  ;

  isAttrs = builtins.isAttrs or (builtins.typeOf val) == "set";
  isDerivation = x: isAttrs x && x ? type && x.type == "derivation";

  recurse = sum: path: val:
    builtins.foldl'
      (sum: key: op sum (path ++ [ key ]) val.${key})
      sum
      (builtins.attrNames val)
  ;
in
recurse { } [ ] tree
