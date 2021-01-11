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
  backportPkgsFromAlt ? []
, # list of strings that represent module paths; pass either a list or a path to one
  backportModulesFromAlt ? []
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
  systems ? [ "x86_64-linux" "aarch64-linux" ]
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
    nixosConfigurations =
      let
        # TODO: does flattenTree produce legal hostnames?
        hosts' = maybeImportValues (lib.flattenTree (maybeImport hosts));

        overlays' =
          externOverlays
          ++ (if self ? "overlay" then [ self.overlay ] else [])
          ++ (if self ? "overlays" then builtins.attrValues self.overlays else [])
          # pull in package backports
          ++ (
            let
              resolveKey = pkgs: key:
                let
                  attrs = builtins.filter builtins.isString (builtins.split "\\." key);
                  op = sum: attr: sum.${attr} or (throw "package \"${key}\" not found");
                in
                  builtins.foldl' op pkgs attrs
              ;
              resolveOverlay = pkgKey: final: prev: {
                pkgKey = let
                  pkgs = import nixpkgsAlt {
                    inherit config;
                    localSystem = prev.stdenv.buildPlatform;
                    crossSystem = prev.stdenv.hostPlatform;
                    # no overlays on nixpkgsAlt: nixpkgsOS ones might not be compatible
                  };
                in
                  resolveKey pkgs pkgKey;
              };
              backportPkgsFromAlt' = maybeImport backportPkgsFromAlt;
            in
              map resolveOverlay backportPkgsFromAlt'
          )
        ;

        # standard modules
        # TODO: add isoImage & sdImage build targets, see: https://github.com/NixOS/nixpkgs/blob/72d906a0eafd089c90a6daab24ef344a79b00046/flake.nix#L56-L59
        # TODO: add base substituters derived from the flake.nix file
        nixosModules' =
          externNixosModules
          ++ (if self ? "nixosModule" then [ self.nixosModule ] else [])
          ++ builtins.removeAttrs
            (if self ? "nixosModules" then builtins.attrValues self.nixosModules else [])
            # profiles have special meaning & are activated per host so remove them here
            [ "profiles" ]
        ;
        globalModule = { config, ... }: {
          networking.hostName = hostName;
          nixpkgs.overlays = overlays';
          nixpkgs.config = config;
          nixpkgs.pkgs = import nixpkgsOS { inherit (config.nixpkgs) config overlays localSystem crossSystem; };
          nix.nixPath = [ "nixos-unstable=${nixpkgsAlt}" "nixpkgs=${nixpkgsOS}" ];
          nix.registry = { nixpkgsAlt.flake = nixpkgsAlt; nixpkgs.flake = nixpkgsOS; };
          system.configurationRevision = lib.mkIf (self ? rev) self.rev;
        };
        backportsModule = { config, altModulesPath, ... }: {
          disabledModules = backportModulesFromAlt;
          imports = map (path: "${altModulesPath}/${path}") backportModulesFromAlt;
        };

      in
        let
          configure = hostName: configurationModule:
            lib.nixosSystem {
              specialArgs = {} // (
                # so that we can easily pull in modules from nixpkgsAlt, see backportsModule above
                if nixpkgsAlt != null then { altModulesPath = "${nixpkgsAlt}/nixos/modules"; } else {}
              );
              modules =
                nixosModules'
                ++ [ globalModule configurationModule ]
                ++ (if nixpkgsAlt != null then [ backportsModule ] else []);
            };
        in
          builtins.mapAttrs (hn: cfg: configure hn cfg) hosts';

    # let others kick-start from your configuration
    templates."${name}" = {
      path = self;
      description = "template based on ${name}'s configuration";
    };
    defaultTemplate = self.templates.${name};
  } // (
    # share your name-spaced (mainly) custom packages as overlay (convention)
    if overlay == null then {} else {
      overlay = maybeImport overlay;
    }
  ) // (
    # share non-name-spaced custom (mainly non packages) overlays (convention)
    if overlays == {} then {} else {
      overlays = maybeImportValues (lib.flattenTree (maybeImport overlays));
    }
  ) // (
    # share your primary (or only) nixos configurations as module
    if nixosModule == null then {} else {
      nixosModule = maybeImport nixosModule;
    }
  ) // (
    # share your nixos configurations as modules
    if nixosModules == {} then {} else {
      nixosModules = maybeImportValues (lib.flattenTree (maybeImport nixosModules));
    }
  ) // (
    # share your primary (or only) devshell configurations as module
    if devshellModule == null then {} else {
      devshellModule = maybeImport devshellModule;
    }
  ) // (
    # share your devshell configurations as modules
    if devshellModules == null then {} else {
      devshellModules = maybeImportValues (lib.flattenTree (maybeImport devshellModules));
    }
  );


  outputs = lib.eachSystem systems (
    system:
      let

        pkgs = import nixpkgsOS {
          inherit config system;
          overlays =
            externOverlays
            ++ (
              if self ? "overlay" then [ self.overlay ] else []
            ) ++ (
              if self ? "overlays" then builtins.attrValues self.overlays else []
            );
        };

        packages = pkgs.${name} or {};

      in
        {

          legacyPackages = packages;

          # Filter on broken packages - we dont't want to expose them to the world
          packages = lib.filterAttrs (_: drv: drv.meta.broken != true) (lib.flattenTreeSystem system packages);

        } // (
          if packages ? defaultPackage then {
            defaultPackage = packages.defaultPackage;
          } else {}
        ) // (
          if shell != null then {
            devShell = maybeImport shell { inherit pkgs; devshellModules = externDevshellModules; };
          } else if packages ? devShell then {
            devShell = packages.devShell;
          } else {}
        )
  );
in outputs // exports
