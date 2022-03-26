{ lib }:
# This function returns a flake outputs-compatible schema.
{
  # pass an instance of self
  self
, # pass an instance of the nixpkgs flake
  nixpkgs
, # we assume that the name maps to the project name, and also that the
  # overlay has an attribute with the `name` prefix that contains all of the
  # project's packages.
  name
, # nixpkgs config
  config ? { }
, # pass either a function or a file
  overlay ? null
, # use this to load other flakes overlays to supplement nixpkgs
  preOverlays ? [ ]
, # maps to the devShell output. Pass in a shell.nix file or function.
  shell ? null
, # pass the list of supported systems
  systems ? [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ]
}:
let
  loadOverlay = obj:
    if obj == null then
      [ ]
    else
      [ (maybeImport obj) ]
  ;

  maybeImport = obj:
    if (builtins.typeOf obj == "path") || (builtins.typeOf obj == "string") then
      import obj
    else
      obj
  ;

  overlays = preOverlays ++ (loadOverlay overlay);

  shell_ = maybeImport shell;

  outputs = lib.eachSystem systems (system:
    let
      pkgs = import nixpkgs {
        inherit
          config
          overlays
          system
          ;
      };

      packages = pkgs.${name} or { };
    in
    {
      # Use the legacy packages since it's more forgiving.
      legacyPackages = packages;
    }
    //
    (
      if packages ? defaultPackage then {
        defaultPackage = packages.defaultPackage;
      } else { }
    )
    //
    (
      if packages ? checks then {
        checks = packages.checks;
      } else { }
    )
    //
    (
      if shell != null then {
        devShell = shell_ { inherit pkgs; };
      } else if packages ? devShell then {
        devShell = packages.devShell;
      } else { }
    )
  );
in
outputs
