{ stdenv, pkgAttrName, pkgVersion }:

with stdenv.lib;

let
  uniqueNames = manifest:
    unique (map pkgAttrName manifest);

  versionsOf = manifest: name:
    filter (pkg: pkgAttrName pkg == name) manifest;

  bestVersion = versions:
    let
      strictLess = a: b:
        builtins.compareVersions (pkgVersion a) (pkgVersion b) > 0;
      sorted = sort strictLess versions;
    in head sorted;

  onlyBestVersions = manifest:
    map (name: bestVersion (versionsOf manifest name)) (uniqueNames manifest);

  manifestWithNames = manifest:
    builtins.listToAttrs (map (p: nameValuePair (pkgAttrName p) p) manifest);
in

path: { mirror }:

let
  orig = import path { inherit mirror; };
  transforms = [
    manifestWithNames
    onlyBestVersions
  ];
in
  fold (f: x: f x) orig transforms
