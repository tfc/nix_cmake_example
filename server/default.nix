let
  nixpkgs = import ../pinnedNixpkgs.nix;
  pkgs = import nixpkgs {
    config = {};
    overlays = [
      (import ./overlay.nix)
    ];
  };

in pkgs.mdb-server
