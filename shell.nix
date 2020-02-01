{ pkgs ? import <nixpkgs> {} }:

with pkgs;

mkShell {
  buildInputs = [
    (pkgs.callPackage (pkgs.fetchFromGitHub {
      owner = "aiverson";
      repo = "lovr";
      rev = "ab9073ba3cbd9965bc46dc768ecee26568d02f96";
      sha256 = "16chcpn4gzgm5r94mkbsc9jm8mj1kd1f40mdb7azf3c9mv52gi62";
      fetchSubmodules = true;
    }) {})
  ];
}
