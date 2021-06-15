systemOrPkgs:
let
  inherit (builtins) foldl' unsafeDiscardStringContext elemAt match split concatStringsSep isList substring stringLength length attrNames;
  system = systemOrPkgs.system or systemOrPkgs;
  pipe = val: functions: foldl' (x: f: f x) val functions;
  max = x: y: if x > y then x else y;

  # Minimized copy-paste https://github.com/NixOS/nixpkgs/blob/master/lib/strings.nix#L746-L762
  sanitizeDerivationName = string: pipe (toString string) [
    # Get rid of string context. This is safe under the assumption that the
    # resulting string is only used as a derivation name
    unsafeDiscardStringContext
    # Strip all leading "."
    (x: elemAt (match "\\.*(.*)" x) 0)
    # Split out all invalid characters
    # https://github.com/NixOS/nix/blob/2.3.2/src/libstore/store-api.cc#L85-L112
    # https://github.com/NixOS/nix/blob/2242be83c61788b9c0736a92bb0b5c7bbfc40803/nix-rust/src/store/path.rs#L100-L125
    (split "[^[:alnum:]+._?=-]+")
    # Replace invalid character ranges with a "-"
    (map (s: if isList s then "-" else s))
    (concatStringsSep "")
    # Limit to 211 characters (minus 4 chars for ".drv")
    (x: substring (max (stringLength x - 207) 0) (-1) x)
    # If the result is empty, replace it with "?EMPTY?"
    (x: if stringLength x == 0 then "?EMPTY?" else x)
  ];

  # Minimized version of 'sanitizeDerivationName' function
  str = it: if it == null then "null" else (sanitizeDerivationName it);

  test = name: command: derivation {
    inherit name system;
    builder = "/bin/sh";
    args = [ "-c" command ];
  };
in
{

  isEqual = a: b:
    if a == b
    then test "SUCCESS__${str a}__IS_EQUAL__${str b}" "echo success > $out"
    else test "FAILURE__${str a}__NOT_EQUAL__${str b}" "exit 1";

  hasKey = attrset: key:
    if attrset ? ${str key}
    then test "SUCCESS__${str key}__EXISTS_IN_ATTRSET" "echo success > $out"
    else test "FAILURE__${str key}__DOES_NOT_EXISTS_IN_ATTRSET_SIZE_${str(length (attrNames attrset))}" "exit 1";
}
