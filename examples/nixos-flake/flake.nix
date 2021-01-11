{
  description = "A highly structured configuration database.";

  inputs.nixpkgsOS.url = "nixpkgs/release-20.09";
  inputs.home.url = "github:nix-community/home-manager/release-20.09";
  inputs.nixpkgsAlt.url = "nixpkgs/master";

  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.devshell.url = "github:numtide/devshell";

  inputs.myRubyGuru.url = "github:myRubyGuru/nixflk";

  outputs = inputs@{ self, home, nixpkgsOS, nixpkgsAlt, flake-utils, nur, devshell }:
    flake-utils.lib.nixosFlake {
      inherit self nixpkgsOS nixpkgsAlt;
      backportFromAlt = [
        "manix" # currently only exists on master
      ];
      name = "nixos-flake"; # use github user name
      shell = ./shell.nix;
      hosts = ./hosts.nix;                      # can be path or function

      externOverlays = [ devshell.overlay ];
      externNixosModules = [ home.nixosModules.home-manager ];
      externDevshellModules = [ myRubyGuru.devshellModules.ruby ];

      overlay = ./pkgs.nix;                     # can be path or function
      overlays = ./overlays;                    # can be path or attrset
      nixosModule = ./modules/main.nix;         # can be path or function
      nixosModules = ./modules;                 # can be path or attrset
      devshellModule = ./shells/main.nix;       # can be path or function
      devshellModules = {                       # can be path or attrset
        python = { # will be flattend
          frontend = ./shells/py-frontend.nix;  # can be path or function
          backend = ./shells/py-backend.nix;    # can be path or function
        };
      };
    };
}
