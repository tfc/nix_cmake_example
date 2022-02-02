{ buildPythonApplication, flask, psycopg2 }:

buildPythonApplication rec {
  pname = "mdb-webserver";
  version = "1.0";

  src = ./.;
  propagatedBuildInputs = [ flask psycopg2 ];

  # No tests in archive
  doCheck = false;
}
