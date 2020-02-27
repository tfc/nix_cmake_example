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
            package = pkgs.postgresql_10;
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
      import shlex


      def send_message(msg):
          return mdb.succeed(
              f"echo -n {msg} | ${pkgs.nmap}/bin/ncat localhost 1300"
          )


      def check_count(select, nlines):
          output = mdb.succeed(f'su -c "psql -d ${authEnv.MDB_DB} -tAc \\"{select}\\"" postgres')
          print(output)
          return nlines == len(output.splitlines())


      mdb.start()
      mdb.wait_for_unit("mdb-webservice.service")
      mdb.wait_for_unit("postgresql.service")

      print(mdb.succeed("journalctl -u postgresql.service"))

      mdb.wait_until_succeeds(
          "${pkgs.curl}/bin/curl http://localhost:5000"
      )

      check_count("SELECT * FROM testcounter;", 0)

      send_message("hello")
      check_count("SELECT * FROM testcounter;", 1)
      assert "hello" in mdb.succeed(
          "${pkgs.curl}/bin/curl http://localhost:5000"
      )

      send_message("foobar")
      check_count("SELECT * FROM testcounter;", 2)
      check_count("SELECT * FROM testcounter WHERE content = 'foobar';", 1)
    '';
  });
in import (nixpkgs + "/nixos/tests/make-test-python.nix") testFunction
