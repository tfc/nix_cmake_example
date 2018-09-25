{
  nixpkgs ? import ./pinnedNixpkgs.nix,
  pkgs ? import nixpkgs {}
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

  # this is useful because libpqxx with python support depends on python2.7
  # but we don't want python in its closure if we package it into a small
  # docker image!
  libpqxxWithoutPython = pkgs.libpqxx.override {
    postgresql = pkgs.postgresql.override {
      libxml2 = pkgs.libxml2.override { pythonSupport = false; };
    };
  };
  mdbServerWithoutPython = serverFunction { inherit nixpkgs pkgs; libpqxx = libpqxxWithoutPython; };

  staticPostgresql = pkgs.postgresql100.overrideAttrs (o: {
      # https://www.postgresql-archive.org/building-libpq-a-static-library-td5970933.html
      postConfigure = o.postConfigure + ''
        echo -e 'libpq.a: $(OBJS)\n\tar rcs $@ $^'   >> ./src/interfaces/libpq/Makefile
      '';
      buildPhase = ''
        make world
        make -C ./src/interfaces/libpq libpq.a
      '';
      postInstall = o.postInstall + ''
        cp src/interfaces/libpq/libpq.a $out/lib/
        cp src/interfaces/libpq/libpq.a $lib/lib/
      '';
    });

  staticStdenv = pkgs.makeStaticLibraries pkgs.stdenv;
  staticPqxx = (pkgs.libpqxx.overrideAttrs (o: { configureFlags = []; })).override {
    stdenv = staticStdenv; postgresql = staticPostgresql;
  };
  staticOpenssl = pkgs.openssl.override { static = true; };

in rec {
  mdb-server = serverFunction { inherit nixpkgs pkgs; };
  mdb-server-static = (serverFunction {
    inherit nixpkgs pkgs;
    static = true;
    stdenv = staticStdenv;
    libpqxx = staticPqxx;
  }).overrideAttrs (o: {
    buildInputs = o.buildInputs ++ [staticPostgresql staticOpenssl pkgs.glibc.static];
  });
  mdb-server-clang  = serverFunction { inherit nixpkgs pkgs; stdenv = pkgs.clangStdenv; };

  mdb-webservice = clientFunction { inherit nixpkgs pkgs; };

  mdb-server-docker = makeDockerImage "mdb-server" "${mdbServerWithoutPython}/bin/messagedb-server";
  mdb-webservice-docker = makeDockerImage "mdb-webservice" "${mdb-webservice}/bin/webserver";

  integration-test = import ./integration_test.nix {
    inherit nixpkgs;
    mdbServer = mdb-server;
    mdbWebservice = mdb-webservice;
  };
}
