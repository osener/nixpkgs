{ callPackage, fetchurl, haskellPackages, stdenv }:

with stdenv.lib;

let
  pkgNameVersion = pkg: nameFromURL pkg.name ".tar";
  pkgAttrName = pkg: (builtins.parseDrvName (pkgNameVersion pkg)).name;
  pkgVersion = pkg: (builtins.parseDrvName (pkgNameVersion pkg)).version;

  mkDerivation = args: attrs:
    stdenv.mkDerivation (mergeAttrsByFuncDefaultsClean (attrs ++ [args]));

  # sane defaults (same name as attr name so that inherit can be used)
  mergeAttrBy = # { buildInputs = concatList; [...]; passthru = mergeAttr; [..]; }
    listToAttrs (map (n : nameValuePair n concat)
      # Lists to concat
      [ "nativeBuildInputs"
        "buildInputs"
        "propagatedBuildInputs"
        "propagatedNativeBuildInputs"
        "cmakeFlags"
        "configureFlags"
        "prePhases"
        "postAll"
        "patches"
      ])
    // listToAttrs (map (n : nameValuePair n mergeAttrs)
      # Attribute sets to merge
      [ "passthru"
        "meta"
        "cfg"
        "flags"
      ])
    // listToAttrs (map (n : nameValuePair n (a: b: "${a}\n${b}"))
      # Strings to concat, separated by a newline
      [ "preConfigure"
        "postInstall"
      ]);

  mergeAttrsByFuncDefaults = foldl mergeAttrByFunc { inherit mergeAttrBy; };
  mergeAttrsByFuncDefaultsClean = list: removeAttrs (mergeAttrsByFuncDefaults list) ["mergeAttrBy"];

  importManifest = callPackage ./import-manifest.nix {
    inherit pkgAttrName pkgVersion;
  };

  callAutonixPackage = callPackage ./call-autonix-package.nix {};

  depAttrNames = [
    "buildInputs" "nativeBuildInputs"
    "propagatedBuildInputs" "propagatedNativeBuildInputs"
    "propagatedUserEnvPkgs"
  ];

  isDepAttr = name: builtins.elem name depAttrNames;

  removePkgDeps = deps:
    let removeDepsIfDepAttr = attr: value:
          if isDepAttr attr then fold remove value deps else value;
    in mapAttrs removeDepsIfDepAttr;

  removeDeps = deps: mapAttrs (pkg: removePkgDeps deps);

  removePkgs = names: filterAttrs (n: v: !(builtins.elem n names));

  hasDep = dep: pkg:
    let depAttrs = attrValues (filterAttrs (n: v: isDepAttr n) pkg);
        allDeps = concatLists depAttrs;
    in elem dep allDeps;

  importPackages = callPackage ./import-packages.nix {
    inherit importManifest isDepAttr;
  };

  defaultFetcher = callPackage ./default-fetcher.nix {};

  defaultDeriver = callPackage ./default-deriver.nix {};

in
{
  inherit pkgNameVersion pkgAttrName;
  inherit mergeAttrsBy mergeAttrsByFuncDefaults mergeAttrsByFuncDefaultsClean;
  inherit callAutonixPackage;
  inherit importManifest;
  inherit mkDerivation;
  inherit depAttrNames isDepAttr hasDep;
  inherit removePkgDeps removeDeps removePkgs;
  inherit importPackages;

  writeManifestXML = callPackage ./write-manifest-xml.nix {
    inherit importManifest;
  };

  blacklist = names: pkgs: removeDeps names (removePkgs names pkgs);

  emptyDeps = {
    buildInputs = [];
    nativeBuildInputs = [];
    propagatedBuildInputs = [];
    propagatedNativeBuildInputs = [];
    propagatedUserEnvPkgs = [];
  };

  generateCollection = callPackage ./generate-collection.nix {
    inherit defaultDeriver defaultFetcher importPackages;
  };

}
