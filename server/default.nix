{
  nixpkgs ? <nixpkgs>,
  pkgs ? import nixpkgs {},
  stdenv ? pkgs.stdenv,
  libpqxx ? pkgs.libpqxx,
  static ? false
}:
stdenv.mkDerivation {
  name = "mdb-server";
  version = "1.0";
  src = ./.;
  buildInputs = with pkgs; [ boost cmake libpqxx ];
  cmakeFlags = pkgs.lib.optional static "-DBUILD_STATIC=1";

  installPhase = ''
    mkdir -p $out/bin;
    cp src/messagedb-server $out/bin/;
  '';
}
