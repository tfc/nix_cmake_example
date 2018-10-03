{ stdenv, lib, libpqxx, boost, cmake, gtest, static ? false }:
stdenv.mkDerivation {
  name = "mdb-server";
  version = "1.0";
  src = ./.;

  nativeBuildInputs = [ cmake ];
  buildInputs = [ boost libpqxx ];
  checkInputs = [ gtest ];

  cmakeFlags = lib.optional static "-DBUILD_STATIC=1";
  enableParallelBuilding = true;

  doCheck = true;
  checkPhase = "./test/tests";

  installPhase = ''
    mkdir -p $out/bin;
    cp src/messagedb-server $out/bin/;
  '';
}
