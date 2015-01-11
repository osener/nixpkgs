{ stdenv, fetchurl, importManifest, isDepAttr }:

with stdenv.lib;

let
  # Do not allow any package to depend on itself.
  removeSelfDep = pkg:
    mapAttrs (n: if isDepAttr n then filter (dep: dep != pkg) else id);
  breakRecursion = mapAttrs removeSelfDep;
in

path: { mirror }:

let
  manifest = importManifest (path + "/manifest.nix") { inherit mirror; };
  deps = import (path + "/dependencies.nix") {};
  mkPkg = pkg: pkgManifest:
    {
      name = nameFromURL pkgManifest.name ".tar";
      src = { inherit (pkgManifest) sha256 name url; };
      inherit (deps."${pkg}")
        buildInputs nativeBuildInputs propagatedBuildInputs
        propagatedNativeBuildInputs propagatedUserEnvPkgs;
    };
in
  breakRecursion (mapAttrs mkPkg manifest)
