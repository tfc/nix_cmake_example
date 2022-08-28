{
  description = "Nix CMake Template";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit self; } {
      systems = [ "x86_64-linux" ];
      imports = [
      ];
      perSystem = { config, self', inputs', pkgs, system, ... }:
        let
          pkgs = inputs'.nixpkgs.legacyPackages;
          inherit (pkgs) lib;

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
                  p = self'.packages.mdb-server;
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
            let integrationTest = mdbServer: import ./integration_test.nix {
              inherit pkgs mdbServer;
              mdbWebservice = self'.packages.mdb-webserver;
            };
            in
            pkgs.lib.mapAttrs' (k: v: pkgs.lib.nameValuePair ("integrationtest-${k}") (integrationTest v));
        in
        {
          packages = {
            mdb-server = pkgs.python3Packages.callPackage ./server/derivation.nix { };
            mdb-server-static = makeStatic self'.packages.mdb-server;
            mdb-server-no-python =
              let # this is useful because libpqxx with python support depends on python2.7
                # but we don't want python in its closure if we package it into a small
                # docker image!
                libpqxxWithoutPython = pkgs.libpqxx.override {
                  postgresql = pkgs.postgresql.override {
                    libxml2 = pkgs.libxml2.override { pythonSupport = false; };
                  };
                };
              in self'.packages.mdb-server.override { libpqxx = libpqxxWithoutPython; };
            mdb-webserver = pkgs.python3Packages.callPackage ./python_client/derivation.nix { };
          };
          checks = { } // (integrationTests serverVariants);

        };
    };
}
