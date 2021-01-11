{ pkgs, devshellModules }: pkgs.mkDevShell {
  imports = [ (import ./shells/main.nix) ] ++ devshellModules;
}
