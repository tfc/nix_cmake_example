let
  sources = import ../nix/sources.nix {};
  pkgs = import sources.nixpkgs {
    config = {};
    overlays = [
      (import ./overlay.nix)
    ];
  };

in pkgs.mdb-server
