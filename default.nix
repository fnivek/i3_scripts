{ pkgs ? import <nixpkgs> {}, ... }:

pkgs.stdenv.mkDerivation {
  name = "i3_workspace";
  propagatedBuildInputs = [
    (pkgs.python3.withPackages (pythonPackages: with pythonPackages; [
      i3ipc
    ]))
  ];
  dontUnpack = true;
  installPhase = "install -Dm755 ${./workspace.py} $out/bin/workspace";
}
