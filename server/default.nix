{
  nixpkgs ? <nixpkgs>,
  pkgs ? import nixpkgs {},
  stdenv ? pkgs.stdenv,
  libpqxx ? pkgs.libpqxx
}:
stdenv.mkDerivation {
  name = "mdb-server";
  version = "1.0";
  src = ./.;
  buildInputs = with pkgs; [ boost cmake libpqxx ];

  installPhase = ''
    mkdir -p $out/bin;
    cp src/messagedb-server $out/bin/;
  '';
}
