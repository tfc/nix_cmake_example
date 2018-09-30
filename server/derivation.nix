{ stdenv, lib, libpqxx, boost, cmake, static ? false }:
stdenv.mkDerivation {
  name = "mdb-server";
  version = "1.0";
  src = ./.;
  nativeBuildInputs = [ cmake ];
  buildInputs = [ boost libpqxx ];
  cmakeFlags = lib.optional static "-DBUILD_STATIC=1";

  enableParralelBuilding = true;

  installPhase = ''
    mkdir -p $out/bin;
    cp src/messagedb-server $out/bin/;
  '';
}
