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

in
{
  inherit pkgNameVersion pkgAttrName;
  inherit mergeAttrsBy mergeAttrsByFuncDefaults mergeAttrsByFuncDefaultsClean;
  inherit callAutonixPackage;
  inherit importManifest;
  inherit mkDerivation;
  inherit depAttrNames isDepAttr;

  writeManifestXML = callPackage ./write-manifest-xml.nix {
    inherit importManifest;
  };

  removeDeps = callPackage ./remove-deps.nix { inherit isDepAttr; };
  removePkgs = names: filterAttrs (n: v: !(builtins.elem n names));

  importPackages = callPackage ./import-packages.nix {
    inherit importManifest isDepAttr;
  };

  emptyDeps = {
    buildInputs = [];
    nativeBuildInputs = [];
    propagatedBuildInputs = [];
    propagatedNativeBuildInputs = [];
    propagatedUserEnvPkgs = [];
  };

  generateCollection = callPackage ./generate-collection.nix {
    inherit callAutonixPackage mkDerivation isDepAttr;
  };
}
