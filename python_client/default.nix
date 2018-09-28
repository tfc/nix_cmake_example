{ python36Packages }:

python36Packages.buildPythonApplication rec {
  pname = "mdb-webservice";
  version = "1.0";

  src = ./.;
  propagatedBuildInputs = with python36Packages; [ flask psycopg2 ];

  # No tests in archive
  doCheck = false;
}
