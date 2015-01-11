{ autonix, kde4, kf55, pkgs, qt4, stdenv
, debug ? false }:

with stdenv.lib; with autonix;

let

  isQt45Pkg = pkg: hasAnyDeps pkg qt4Deps && hasAnyDeps pkg qt5Deps;
  hasAnyDeps = pkg: any (dep: hasDep dep pkg);
  qt5Deps = [ "qt5" ] ++ attrNames kf5;
  qt4Deps = [ "kde4" "qt4" ];
  mkQt4Pkg = pkg:
    let name = builtins.parseDrvName pkg.name;
    in (removePkgDeps qt5Deps pkg) // {
      name = name.name + "-qt4-" + name.version;
    };
  mkQt5Pkg = pkg:
    let name = builtins.parseDrvName pkg.name;
    in (removePkgDeps qt4Deps pkg) // {
      name = name.name + "-qt5-" + name.version;
    };
  splitQt45Pkgs = pkgs:
    let pkgNames = attrNames pkgs;
        go = name: set:
          let pkg = pkgs."${name}"; in
          if !(isQt45Pkg pkg)
            then set // { "${name}" = pkg; }
            else set // {
              "${name}-qt4" = mkQt4Pkg pkg;
              "${name}-qt5" = mkQt5Pkg pkg;
            };
    in fold go {} pkgNames;

  qt5Only = tgt: mapAttrs (pkg: if tgt == pkg then removePkgDeps qt4Deps else id);
  qt4Only = tgt: mapAttrs (pkg: if tgt == pkg then removePkgDeps qt5Deps else id);

  packages =
    fold (f: x: f x)
      (importPackages ./. { mirror = "mirror://kde"; })
      [ splitQt45Pkgs
        (removeDeps [ "kf5" ])
        (qt5Only "kapptemplate")
        (qt4Only "kbreakout")
        (qt4Only "artikulate")
        (qt4Only "kde-baseapps")
        (blacklist [ "jovie" "kde-dev-scripts" "kde-dev-utils" ])
      ];

  kf5 = kf55.override { inherit debug; };
  inherit (kf5) qt5;

  extraInputs = kf5 // { inherit kde4; };

  extraOutputs = {
  };

  names = with pkgs; with extraOutputs; kf5.dev.names // {
    inherit exiv2 ffmpeg gettext gmp lcms2 taglib;
    inherit (kde4) libkdegames;
    gphoto2 = libgphoto2;
    kde4 = kde4.kdelibs;
    libkonq = kdeApps.kde-baseapps;
    qtgstreamer = qt_gstreamer1;
  };

  overrides = with pkgs; {
    ffmpegthumbs = { nativeBuildInputs = [ pkgconfig ]; };
    kalzium = { nativeBuildInputs = [ pkgconfig ]; };
  };

  kdeApps = autonix.generateCollection ./. {
    inherit packages extraInputs extraOutputs names overrides;
    deriver = kf5.dev.mkDerivation;
  };

in kdeApps
