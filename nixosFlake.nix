{ lib }:
# This function returns a flake outputs-compatible schema.
{
  # pass an instance of self
  self
, # pass an instance of the nixpkgs flake used to determine your nixos version
  nixpkgsOS
, # we assume that the name maps to the project name, and also that the
  # overlay has an attribute with the `name` prefix that contains all of the
  # project's packages.
  name
, # pass an instance of the nixpkgs flake for access to alternative package versions (eg. unstable)
  nixpkgsAlt ? null
, # list of strings that represent a package path; pass either a list or a path to one
  backportFromAlt ? []
, # nixpkgs config for nixpkgsOS & nixpkgs-unstable
  config ? {}
, # pass either an attribute set or a path to one
  hosts ? null
, # overlay for local packages; pass either an overlay function or a path to one
  overlay ? null
, # local additional overlays; pass either an overlay function or a path to one to each leaf attr
  overlays ? {}
, # use this to load other flakes modules to supplement your overlays
  externOverlays ? []
, # main (or only) local nixos configuration module; pass either a nixos module or a path to one
  nixosModule ? null
, # local nixos configuration modules; pass either an attrset of module or a path to one to each leaf attr
  nixosModules ? {}
, # use this to load other flakes modules to supplement your configuration
  externNixosModules ? []
, # main (or only) local numtide/devshell configuration module; pass either a devshell module or a path to one
  devshellModule ? null
, # local numtide/devshell configuration modules; pass either a devshell module or a path to one to each leaf attr
  devshellModules ? {}
, # use this to load other flakes modules to supplement your devshells
  externDevshellModules ? []
, # maps to the devShell output. Pass in a shell.nix file or function.
  shell ? null
, # pass the list of supported systems
  systems ? [ "x86_64-linux" ]
}:
let
  maybeImportValues = flatAttrSet:
    builtins.mapAttrs (name: value: maybeImport value) flatAttrSet
  ;
  maybeImport = obj:
    if (builtins.typeOf obj == "path") || (builtins.typeOf obj == "string") then
      import obj
    else
      obj
  ;

  exports = {
    # let others kick-start from your configuration
    templates."${name}" = {
      path = self;
      description = "template based on ${name}'s configuration";
    };
    defaultTemplate = self.templates.${name};
  }
  # share your name-spaced (mainly) custom packages as overlay (convention)
  // (
    if overlay != null then {
      overlay = maybeImport overlay;
    } else {}
  )
  # share non-name-spaced custom (mainly non packages) overlays (convention)
  // (
    if overlays != {} then {
      overlays = maybeImportValues (lib.flattenTree (maybeImport overlays));
    } else {}
  )
  # share your primary (or only) nixos configurations as module
  // (
    if nixosModule != null then {
      nixosModule = maybeImport nixosModule;
    } else {}
  )
  # share your nixos configurations as modules
  // (
    if nixosModules != {} then {
      nixosModules = maybeImportValues (lib.flattenTree (maybeImport nixosModules));
    } else {}
  )
  # share your primary (or only) devshell configurations as module
  // (
    if devshellModule != null then {
      devshellModule = maybeImport devshellModule;
    } else {}
  )
  # share your devshell configurations as modules
  // (
    if devshellModules != null then {
      devshellModules = maybeImportValues (lib.flattenTree (maybeImport devshellModules));
    } else {}
  );

  outputs = lib.eachSystem systems (
    system:
      let
        nixosModules' =
          externNixosModules
          ++ (if self ? "nixosModule" then [ self.nixosModule ] else [])
          ++ (if self ? "nixosModules" then builtins.attrValues self.nixosModules else [])
        ;

        devshellModules' =
          externDevshellModules
          ++ (if self ? "devshellModule" then [ self.devshellModule ] else [])
          ++ (if self ? "devshellModules" then builtins.attrValues self.devshellModules else [])
        ;

        overlays' =
          externOverlays
          ++ (if self ? "overlay" then [ self.overlay ] else [])
          ++ (if self ? "overlays" then builtins.attrValues self.overlays else [])
          ++ (
            let
              resolveKey = pkgs: key:
                let
                  attrs = builtins.filter builtins.isString (builtins.split "\\." key);
                  op = sum: attr: sum.${attr} or (throw "package \"${key}\" not found");
                in
                  builtins.foldl' op pkgs attrs
              ;
              resolveOverlay = pkgs: pkgKey: final: prev: {
                pkgKey = resolveKey pkgs pkgKey;
              };
            in
              let
                backportFromAlt' = maybeImport backportFromAlt;
                pkgsAlt = import nixpkgsAlt {
                  inherit
                    config
                    system
                    ;
                };
              in
                map resolveOverlay pkgsAlt backportFromAlt'
          )
        ;

        pkgs = import nixpkgsOS {
          overlays = overlays';
          inherit
            config
            system
            ;
        };

        packages = pkgs.${name} or {};
      in
        {
          nixosConfigurations =
            maybeImportValues (lib.flattenTree (maybeImport hosts))
              (
                recursiveUpdate inputs {
                  inherit lib pkgs system utils externModules;
                }
              );

          legacyPackages = packages;

          packages = lib.filterAttrs
            # Filter on broken packages - you dont't want to expose them to the world
            (_: drv: drv.meta.broken != true)
            lib.flattenTreeSystem system packages;
        } // (
          if packages ? defaultPackage then {
            defaultPackage = packages.defaultPackage;
          } else {}
        ) // (
          if shell != null then {
            devShell = maybeImport shell { inherit pkgs; };
          } else if packages ? devShell then {
            devShell = packages.devShell;
          } else {}
        );
    in
    outputs // exports
