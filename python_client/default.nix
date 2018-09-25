{
  nixpkgs ? <nixpkgs>,
  pkgs ? import nixpkgs {}
}:

let
  pythonEnv = pkgs.python36Packages;
in pythonEnv.buildPythonApplication rec {
  pname = "mdb-webservice";
  version = "1.0";

  src = ./.;
  buildInputs = with pythonEnv; [ flask psycopg2 ];

  # No tests in archive
  doCheck = false;
}
