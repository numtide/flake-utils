let
  str = it: if it == null then "null" else (toString it);
in
final: prev: {

  isEqual = a: b:
    if a == b
    then final.runCommandNoCC "SUCCESS__${str a}__IS_EQUAL__${str b}" { } "echo success > $out"
    else final.runCommandNoCC "FAILURE__${str a}__NOT_EQUAL__${str b}" { } "exit 0";

  hasKey = attrset: key:
    if attrset ? ${str key}
    then final.runCommandNoCC "SUCCESS__${str key}__EXISTS_IN_ATTRSET" { } "echo success > $out"
    else final.runCommandNoCC "FAILURE__${str key}__DOES_NOT_EXISTS_IN_ATTRSET_SIZE_${str(final.lib.length (builtins.attrNames attrset))}" { } "exit 0";
}
