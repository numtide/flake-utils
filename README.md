# flake-utils

**STATUS: stable**

Pure Nix flake utility functions.

The goal of this project is to build a collection of pure Nix functions that don't
depend on nixpkgs, and that are useful in the context of writing other Nix
flakes.

## Usage

### `system :: { system = system, ... }`

A map from system to system built from `allSystems`:
```nix
system = {
  x86_64-linux = "x86_64-linux";
  x86_64-darwin = "x86_64-darwin";
  ...
}
```
It's mainly useful to
detect typos and auto-complete if you use [rnix-lsp](https://github.com/nix-community/rnix-lsp).
   
Eg: instead of typing `"x86_64-linux"`, use `system.x86_64-linux`.


### `allSystems :: [<system>]`

A list of all systems defined in nixpkgs. For a smaller list see `defaultSystems`.

### `defaultSystems :: [<system>]`

The list of systems to use in `eachDefaultSystem` and `simpleFlake`.

The default values are `["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"]`.

It's possible to override and control that list by changing the `systems` input of this flake.

Eg (in your `flake.nix`):

```nix
{
  # 1. Defined a "systems" inputs that maps to only ["x86_64-linux"]
  inputs.systems.url = "github:nix-systems/x86_64-linux";

  inputs.flake-utils.url = "github:numtide/flake-utils";
  # 2. Override the flake-utils default to your version
  inputs.flake-utils.inputs.systems.follows = "systems";

  outputs = { self, flake-utils, ... }:
    # Now eachDefaultSystem is only using ["x86_64-linux"], but this list can also
    # further be changed by users of your flake.
    flake-utils.lib.eachDefaultSystem (system: {
      # ...
    });
}
```

For more details in this pattern, see: <https://github.com/nix-systems/nix-systems>.

### `eachSystem :: [<system>] -> (<system> -> attrs)`

A common case is to build the same structure for each system. Instead of
building the hierarchy manually or per prefix, iterate over each systems and
then re-build the hierarchy.

Eg:

```nix
eachSystem [ system.x86_64-linux ] (system: { hello = 42; })
# => { hello = { x86_64-linux = 42; }; }
eachSystem allSystems (system: { hello = 42; })
# => {
   hello.aarch64-darwin = 42,
   hello.aarch64-genode = 42,
   hello.aarch64-linux = 42,
   ...
   hello.x86_64-redox = 42,
   hello.x86_64-solaris = 42,
   hello.x86_64-windows = 42
}
```

### `eachDefaultSystem :: (<system> -> attrs)`

`eachSystem` pre-populated with `defaultSystems`.

#### Example

[$ examples/each-system/flake.nix](examples/each-system/flake.nix) as nix
```nix
{
  description = "Flake utils demo";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system}; in
      {
        packages = {
          default = pkgs.hello;
          # `nix run .#find` will work because findutils.meta.mainProgram is set to "find".
          find = pkgs.findutils;
        };
        # Use apps to expose packages that have multiple binaries.
        apps = {
          xargs = flake-utils.lib.mkApp {
            drv = pkgs.findutils;
            name = "xargs";
          };
          ls = flake-utils.lib.mkApp {
            drv = pkgs.coreutils;
            name = "ls";
          };
        };
      }
    );
}
```

### `meld :: attrs -> [ path ] -> attrs`

Meld merges subflakes using common inputs.  Useful when you want to
split up a large flake with many different components into more
manageable parts.

### `mkApp { drv, name ? drv.pname or drv.name, exePath ? drv.passthru.exePath or "/bin/${name}"`

> **DEPRECATED**
>
> `mkApp` has been deprecated in favor of direct definitions.
>
> Example: `{ type = "app"; program = nixpkgs.lib.getExe drv; }`

A small utility that builds the structure expected by the special `apps` and `defaultApp` prefixes.


### `flattenTree :: attrs -> attrs`

Nix flakes insists on having a flat attribute set of derivations in
various places like the `packages` and `checks` attributes.

This function traverses a tree of attributes (by respecting
recurseIntoAttrs) and only returns their derivations, with a flattened
key-space.

Eg:
```nix
flattenTree { hello = pkgs.hello; gitAndTools = pkgs.gitAndTools }
```
Returns:

```nix
{
  hello = «derivation»;
  "gitAndTools/git" = «derivation»;
  "gitAndTools/hub" = «derivation»;
  # ...
}
```

### `simpleFlake :: attrs -> attrs`

This function should be useful for most common use-cases where you have a
simple flake that builds a package. It takes nixpkgs and a bunch of other
parameters and outputs a value that is compatible as a flake output.

Input:
```nix
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
}: null
```

#### Example

Here is how it looks like in practice:

[$ examples/simple-flake/flake.nix](examples/simple-flake/flake.nix) as nix
```nix
{
  description = "Flake utils demo";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.simpleFlake {
      inherit self nixpkgs;
      name = "simple-flake";
      overlay = ./overlay.nix;
      shell = ./shell.nix;
    };
}
```
