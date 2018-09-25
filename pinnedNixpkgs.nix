let
  spec = builtins.fromJSON (builtins.readFile ./nixpkgs-src.json);
  url = "https://github.com/${spec.owner}/${spec.repo}/archive/${spec.rev}.tar.gz";
in
  builtins.fetchTarball { url = url; sha256 = spec.sha256; }
