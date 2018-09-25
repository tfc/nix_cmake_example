{
  nixpkgs,
  mdbServer,
  mdbWebservice
}:
let
  pkgs = import nixpkgs {};
  authEnv = {
    MDB_HOST = "127.0.0.1";
    MDB_DB   = "testdb";
    MDB_USER = "testuser";
    MDB_PASS = "testpass";
  };

  testFunction = ({ pkgs, ... }: {
    name = "run-mdb-service-with-webservice";

    nodes = {
      mdb = { pkgs, lib, ... }: {
        networking.firewall.allowedTCPPorts = [ 1300 5000 ];

        services = {
          postgresql = {
            enable = true;
            package = pkgs.postgresql100;
            enableTCPIP = true;
            authentication = "host  all  all 0.0.0.0/0 md5";
            initialScript = pkgs.writeText "postgres-initScript" ''
              CREATE ROLE ${authEnv.MDB_USER} WITH LOGIN PASSWORD '${authEnv.MDB_PASS}';
              CREATE DATABASE ${authEnv.MDB_DB};
              GRANT ALL PRIVILEGES ON DATABASE ${authEnv.MDB_DB} TO ${authEnv.MDB_USER};
            '';
          };
        };

        systemd.services.mdb-server = {
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" "postgresql.service" ];
          serviceConfig.Restart = "always";
          script = "exec ${mdbServer}/bin/messagedb-server";
          environment = authEnv;
        };

        systemd.services.mdb-webservice = {
          wantedBy = [ "multi-user.target" ];
          after = [ "mdb-server.service" ];
          serviceConfig.Restart = "always";
          script = "exec ${mdbWebservice}/bin/mdb-webserver";
          environment = authEnv;
        };
      };
    };

    testScript = ''
      sub check_count {
        my ($select, $nlines) = @_;
        return 'test $(sudo -u postgres psql ${authEnv.MDB_DB} -tAc "' . $select . '"|wc -l) -eq ' . $nlines;
      }

      $mdb->start();
      $mdb->waitForUnit("mdb-webservice.service");
      $mdb->sleep(2);

      $mdb->succeed(check_count("SELECT * FROM testcounter;", 0));

      $mdb->succeed("echo -n hello | ${pkgs.nmap}/bin/ncat localhost 1300");
      $mdb->succeed(check_count("SELECT * FROM testcounter;", 1));
      $mdb->succeed("${pkgs.curl}/bin/curl http://localhost:5000") =~ /hello/ or die;;

      $mdb->succeed("echo -n foobar | ${pkgs.nmap}/bin/ncat localhost 1300");
      $mdb->succeed(check_count("SELECT * FROM testcounter;", 2));
      $mdb->succeed(check_count("SELECT * FROM testcounter WHERE content = 'foobar';", 1));
    '';
  });
in import (nixpkgs + "/nixos/tests/make-test.nix") testFunction
