{ stdenv, lib, libpqxx, boost, cmake, gtest, static ? false }:
stdenv.mkDerivation {
  name = "mdb-server";
  version = "1.0";
  src = ./.;

  nativeBuildInputs = [ cmake ];
  buildInputs = [ boost libpqxx ];
  checkInputs = [ gtest ];

  cmakeFlags = [
    (lib.optional static "-DBUILD_STATIC=1")
    (lib.optional (!static) "-DENABLE_TESTS=1")
  ];
  makeTarget = "mdb-server";
  enableParallelBuilding = true;

  doCheck = true;
  checkTarget = "test";

  installPhase = ''
    mkdir -p $out/bin;
    cp src/messagedb-server $out/bin/;
  '';
}
