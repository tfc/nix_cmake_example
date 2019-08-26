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

  staticPostgresql = pkgs.postgresql_10.overrideAttrs (o: {
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

  staticPqxx = (pkgs.libpqxx.overrideAttrs (o: { configureFlags = []; })).override {
    stdenv = pkgs.makeStaticLibraries pkgs.stdenv;
    postgresql = staticPostgresql;
  };
  staticOpenssl = pkgs.openssl.override { static = true; };

  staticServer = (pkgs.mdb-server.override {
    static = true;
    libpqxx = staticPqxx;
  }).overrideAttrs (o: {
    buildInputs = o.buildInputs ++ [staticPostgresql staticOpenssl pkgs.glibc.static];
    doCheck = false;
    name = "${o.name}-static";
  });

  originalDerivations = [
    pkgs.mdb-server
    staticServer
  ];

  compilers = with pkgs; {
    gcc7 = stdenv;
    gcc8 = overrideCC stdenv gcc8;
    clang7 = overrideCC stdenv clang_7;
    clang8 = overrideCC stdenv clang_8;
  };

  f = libname: libs: derivs: with pkgs.lib;
    concatMap (deriv:
      mapAttrsToList (libVers: lib:
        (deriv.override { "${libname}" = lib; }).overrideAttrs
          (old: { name = "${old.name}-${libVers}"; })
      ) libs
    ) derivs;

  overrides = [
    (f "stdenv" compilers)
    (f "boost"  boostLibs)
  ];

  boostLibs = {
    inherit (pkgs) boost166 boost167 boost168 boost169;
  };

  integrationTest = mdbServer: import ./integration_test.nix {
    inherit nixpkgs mdbServer;
    mdbWebservice = pkgs.mdb-webserver;
  };

  integrationTests = pkgs.lib.mapAttrs'
    (k: v: pkgs.lib.nameValuePair ("integrationtest-" + k) (integrationTest v {}));

  dockerImages = rec {
    mdb-webservice = pkgs.mdb-webserver;
    mdb-server-docker = makeDockerImage "mdb-server" "${mdbServerWithoutPython}/bin/messagedb-server";
    mdb-server-docker-static = makeDockerImage "mdb-server" "${staticServer}/bin/messagedb-server";
    mdb-webservice-docker = makeDockerImage "mdb-webservice" "${mdb-webservice}/bin/webserver";
  };

  allDerivations = with pkgs.lib; foldl (a: b: a // { "${b.name}" = b; }) {} (
    foldl (a: f: f a) originalDerivations overrides
  );

in allDerivations //
   (integrationTests allDerivations) //
   dockerImages
