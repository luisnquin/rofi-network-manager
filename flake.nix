{
  description = "A manager for network connections using rofi";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {
          inherit system;
        };

        rofi-network-manager = pkgs.callPackage ./default.nix {};
      in {
        defaultPackage = rofi-network-manager;

        packages = {
          inherit rofi-network-manager;
        };
      }
    );
}
