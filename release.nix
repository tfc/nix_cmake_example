{
  nixpkgs ? import ./pinnedNixpkgs.nix
}:
let
  pkgs = import nixpkgs {
    overlays = [ (import ./server/overlay.nix) (import ./python_client/overlay.nix) ];
  };

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
  mdbServerWithoutPython = pkgs.mdb-server.override { libpqxx = libpqxxWithoutPython; };

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

  staticPqxx = selectedStdenv: (pkgs.libpqxx.overrideAttrs (o: { configureFlags = []; })).override {
    stdenv = pkgs.makeStaticLibraries selectedStdenv; postgresql = staticPostgresql;
  };
  staticOpenssl = pkgs.openssl.override { static = true; };

  staticServer = selectedStdenv: (pkgs.mdb-server.override {
    static = true;
    stdenv = pkgs.makeStaticLibraries selectedStdenv;
    libpqxx = staticPqxx selectedStdenv;
  }).overrideAttrs (o: {
    buildInputs = o.buildInputs ++ [staticPostgresql staticOpenssl pkgs.glibc.static];
  });

  integrationTest = serverPkg: import ./integration_test.nix {
    inherit nixpkgs;
    mdbServer = serverPkg;
    mdbWebservice = pkgs.mdb-webserver;
  };

  integrationTests = pkgs.lib.mapAttrs'
    (k: v: pkgs.lib.nameValuePair ("integrationtest-" + k) (integrationTest v));

  serverBinaries = {
    mdb-server = pkgs.mdb-server;
    mdb-server-boost163 = pkgs.mdb-server.override { boost = pkgs.boost163; };
    mdb-server-boost164 = pkgs.mdb-server.override { boost = pkgs.boost164; };
    mdb-server-boost165 = pkgs.mdb-server.override { boost = pkgs.boost165; };

    mdb-server-static = staticServer pkgs.stdenv;
    mdb-server-static-boost163 = (staticServer pkgs.stdenv).override { boost = pkgs.boost163; };
    mdb-server-static-boost164 = (staticServer pkgs.stdenv).override { boost = pkgs.boost164; };
    mdb-server-static-boost165 = (staticServer pkgs.stdenv).override { boost = pkgs.boost165; };

    mdb-server-clang  = pkgs.mdb-server.override { stdenv = pkgs.clangStdenv; };
    mdb-server-clang-static = staticServer pkgs.clangStdenv;
  };

in rec {
  mdb-webservice = pkgs.mdb-webserver;

  mdb-server-docker = makeDockerImage "mdb-server" "${mdbServerWithoutPython}/bin/messagedb-server";
  mdb-webservice-docker = makeDockerImage "mdb-webservice" "${mdb-webservice}/bin/webserver";

} // serverBinaries
  // (integrationTests serverBinaries)
