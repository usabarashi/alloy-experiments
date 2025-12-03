{
  description = "Alloy Experiments";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    utils.url = "github:numtide/flake-utils";
  };
  outputs =
    {
      self,
      nixpkgs,
      utils,
    }:
    utils.lib.eachDefaultSystem (
      system:
      let
        config = {
          allowUnfree = true;
        };
        pkgs = import nixpkgs { inherit config system; };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            alloy6
            jdk

            jq
            graphviz
          ];

          shellHook = ''
            export JAVA_OPTS="-Xmx8g -Xms2g"
          '';
        };
      }
    );
}
