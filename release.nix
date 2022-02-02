let
  sources = import ./nix/sources.nix { };
  pkgs = import sources.nixpkgs {
    overlays = [
      (import ./server/overlay.nix)
      (import ./python_client/overlay.nix)
    ];
  };

  inherit (pkgs) lib;

  mdbServerWithoutPython =
    let
      # this is useful because libpqxx with python support depends on python2.7
      # but we don't want python in its closure if we package it into a small
      # docker image!
      libpqxxWithoutPython = pkgs.libpqxx.override {
        postgresql = pkgs.postgresql.override {
          libxml2 = pkgs.libxml2.override { pythonSupport = false; };
        };
      };
    in
    pkgs.mdb-server.override { libpqxx = libpqxxWithoutPython; };

  makeStatic =
    let
      staticPostgresql = (pkgs.postgresql_11.overrideAttrs (o: {
        dontDisableStatic = true;
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
      })).override { gssSupport = false; };

      staticPqxx = (pkgs.libpqxx.overrideAttrs (o: { configureFlags = [ ]; })).override {
        stdenv = pkgs.makeStaticLibraries pkgs.stdenv;
        postgresql = staticPostgresql;
      };
      staticOpenssl = pkgs.openssl.override { static = true; };
    in
    drv: (drv.override {
      static = true;
      libpqxx = staticPqxx;
    }).overrideAttrs (o: {
      buildInputs = o.buildInputs ++ [
        pkgs.glibc.static
        staticOpenssl
        staticPostgresql
      ];
      doCheck = false;
    });

  serverVariants =
    let
      fromInputs = { stdenv, boost16x, static }:
        let
          p = pkgs.mdb-server;
          noDots = lib.replaceChars [ "." ] [ "_" ];
          staticStr = lib.optionalString static "-static";
          name = "${p.name}-${noDots stdenv.cc.cc.name}-${noDots boost16x.name}${staticStr}";
          maybeMakeStatic = drv: if static then makeStatic drv else drv;
          drv = maybeMakeStatic (p.override { inherit boost16x stdenv; });
        in
        lib.nameValuePair name drv;

      inputVariants = lib.cartesianProductOfSets {
        stdenv = with pkgs;
          map (overrideCC stdenv) [ gcc9 gcc10 gcc11 ]
          ++ map (overrideCC clangStdenv) [ clang_11 clang_12 clang_13 ];
        boost16x = with pkgs; [ boost168 boost169 ];
        static = [ true false ];
      };
    in
    builtins.listToAttrs (builtins.map fromInputs inputVariants);

  integrationTests =
    let
      integrationTest = mdbServer: import ./integration_test.nix {
        inherit pkgs mdbServer;
        mdbWebservice = pkgs.mdb-webserver;
      };
    in
    pkgs.lib.mapAttrs'
      (k: v: pkgs.lib.nameValuePair "integrationtest-${k}"
        (integrationTest v { }));

  dockerImages =
    let
      makeDockerImage = name: entrypoint: pkgs.dockerTools.buildImage {
        inherit name;
        tag = "latest";
        contents = [ ];
        config = { Entrypoint = [ entrypoint ]; };
      };
    in
    {
      mdb-webservice = makeDockerImage "mdb-webservice" "${pkgs.mdb-webserver}/bin/webserver";
      mdb-server = makeDockerImage "mdb-server" "${mdbServerWithoutPython}/bin/messagedb-server";
      mdb-server-static = makeDockerImage "mdb-server" "${makeStatic pkgs.mdb-server}/bin/messagedb-server";
    };

in
builtins.mapAttrs (_: pkgs.recurseIntoAttrs) {
  inherit serverVariants dockerImages;
  webServer = { inherit (pkgs) mdb-webserver; };
  integrationTest = integrationTests serverVariants;
}
