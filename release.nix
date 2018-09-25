{
  nixpkgs ? <nixpkgs>,
  pkgs ? import <nixpkgs> {}
}:
let
  serverFunction = import ./server;
  clientFunction = import ./python_client;
  makeDockerImage = name: entrypoint: pkgs.dockerTools.buildImage {
      name = name;
      tag = "latest";
      contents = [ ];
      config = {
        Entrypoint = [ entrypoint ];
      };
    };

  libpqxxWithoutPython = pkgs.libpqxx.override {
    postgresql = pkgs.postgresql.override {
      libxml2 = pkgs.libxml2.override { pythonSupport = false; };
    };
  };
  mdbServerWithoutPython = serverFunction { inherit nixpkgs pkgs; libpqxx = libpqxxWithoutPython; };

in rec {
    mdb-server        = serverFunction { inherit nixpkgs pkgs; };
    mdb-server-clang  = serverFunction { inherit nixpkgs pkgs; stdenv = pkgs.clangStdenv; };

    mdb-webservice = clientFunction { inherit nixpkgs pkgs; };

    mdb-server-docker = makeDockerImage "mdb-server" "${mdbServerWithoutPython}/bin/messagedb-server";
    mdb-webservice-docker = makeDockerImage "mdb-webservice" "${mdb-webservice}/bin/webserver";
}
