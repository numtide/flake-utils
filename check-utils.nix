systemOrPkgs:
let
  str = it: if it == null then "null" else (toString it);
  system = systemOrPkgs.system or systemOrPkgs;
  test = name: command: derivation {
    inherit name system;
    builder = "/bin/sh";
    args = [ "-c" command ];
   };
in {

  isEqual = a: b:
    if a == b
    then test "SUCCESS__${str a}__IS_EQUAL__${str b}" "echo success > $out"
    else test "FAILURE__${str a}__NOT_EQUAL__${str b}" "exit 1";

  hasKey = attrset: key:
    if attrset ? ${str key}
    then test "SUCCESS__${str key}__EXISTS_IN_ATTRSET" "echo success > $out"
    else test "FAILURE__${str key}__DOES_NOT_EXISTS_IN_ATTRSET_SIZE_${str(builtins.length (builtins.attrNames attrset))}" "exit 1";
}
