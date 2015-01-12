{ autonix, kde4, kf55, pkgs, qt4, stdenv
, debug ? false }:

with stdenv.lib; with autonix;

let

  kdeApps = generateCollection ./. {
    mirror = "mirror://kde";
    inherit overrider repackager resolver rewriter;
    deriver = name: stdenv.mkDerivation;
  };

  repackager = pkgs: fold (f: x: f x) pkgs
    [ (blacklist ["artikulate"]) # build failure, wrong boost?
      (blacklist ["cantor"]) # link failure, Qt version mismatch?
      (blacklist [ "kde-dev-scripts" "kde-dev-utils" ]) # docbook errors
      (blacklist ["kdewebdev"]) # unknown build failure
    ];

  qt5Deps = [ "qt5" ] ++ attrNames kf5;
  qt4Only = removePkgDeps qt5Deps;

  qt4Deps = [ "kde4" "qt4" ];
  isQt4Pkg = pkg: any (dep: hasDep dep pkg) qt4Deps;
  qt5Only = removePkgDeps qt4Deps;

  rewriter = name: pkg:
    fold (f: x: f x) pkg
      [
        (renameDeps
          {
            canberra = "libcanberra";
            eigen3 = "eigen";
            gphoto2 = "libgphoto2";
            kde4 = "kdelibs";
            kde4workspace = "kde_workspace";
            musicbrainz3 = "libmusicbrainz";
            poppler = "popplerQt4";
            qtgstreamer = "qt_gstreamer";
            libattica = "attica";
            libkonq = "kde-baseapps";
            sndfile = "libsndfile";
            telepathyqt4 = "telepathy_qt";
          }
        )

        (pkg: if isQt4Pkg pkg
          then pkg // { cmakeFlags = [ "-DQT_QMAKE_EXECUTABLE=${qt4}/bin/qmake" ]; }
          else pkg
        )

        (pkg:
          {
            kde-baseapps = qt4Only pkg;
            kde-runtime = qt4Only pkg;
            kmix = qt4Only pkg;
            okular = qt4Only pkg;
          }."${name}" or pkg
        )
      ];

  kf5 = kf55.override { inherit debug; };
  inherit kde4;
  scope =
      kf5.passthru.scope
    // { inherit (kde4) kde_workspace kdelibs kdepimlibs; }
    // kdeApps;

  resolver = name: pkg: dep: optional (hasAttr dep scope) scope."${dep}";

  overrider = name: attrs:
    (mergeAttrsByFuncDefaultsClean
      [
        attrs

        {
          setupHook = ./setup-hook.sh;

          enableParallelBuilding = true;
          cmakeFlags =
            [ "-DBUILD_TESTING=OFF"
              "-DKDE_DEFAULT_HOME=.kde5"
              "-DKDE4_DEFAULT_HOME=.kde"
            ]
            ++ optional debug "-DCMAKE_BUILD_TYPE=Debug";

          meta =
          {
            license = with stdenv.lib.licenses; [
              lgpl21Plus lgpl3Plus bsd2 mit gpl2Plus gpl3Plus fdl12
            ];
            platforms = stdenv.lib.platforms.linux;
            maintainers = with stdenv.lib.maintainers; [ ttuegel ];
            homepage = "http://www.kde.org";
          };
        }

        (packageSoftOverrides."${name}" or {})
      ]
    ) // (packageHardOverrides."${name}" or {});

  packageSoftOverrides = with scope; {
    ffmpegthumbs = { nativeBuildInputs = [ pkgconfig ]; };
    kalzium = { nativeBuildInputs = [ pkgconfig ]; };
    kde-runtime = {
      buildInputs = [ kde4.kactivities pkgs.attica ];
      NIX_CFLAGS_COMPILE = "-I${ilmbase}/include/OpenEXR";
    };
    kdesdk-thumbnailers = { nativeBuildInputs = [ gettext ]; };
    kgpg = { buildInputs = [ boost ]; };
    kmix = { nativeBuildInputs = [ pkgconfig ]; };
    kmousetool = { buildInputs = [ xlibs.libXtst xlibs.libXt ]; };
    kremotecontrol = { buildInputs = [ xlibs.libXtst ]; };
    krfb = {
      buildInputs = with kde4.telepathy; [
        xlibs.libXtst common_internals
      ];
    };
    libkdcraw = {
      buildInputs = [ kdelibs libraw ];
      nativeBuildInputs = [ pkgconfig ];
    };
    libkexiv2 = {
      buildInputs = [ exiv2 kdelibs ];
    };
    libkface = { buildInputs = [ kdelibs opencv ]; };
    libkipi = { buildInputs = [ kdelibs ]; };
    libksane = { buildInputs = [ kdelibs saneBackends ]; };
    okular = {
      buildInputs = [ ebook_tools kde4.kactivities ];
    };
  };

  packageHardOverrides = {};

in kdeApps
