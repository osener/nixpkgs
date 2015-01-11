{ autonix, haskellPackages, kf55, pkgs, stdenv
, debug ? false }:

with stdenv.lib; with autonix;

let

  plasma5 = generateCollection ./. {
    mirror = "mirror://kde";
    inherit overrider repackager resolver rewriter;
    deriver = name: stdenv.mkDerivation;
  };

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
  splitBreeze = pkgs: (removeAttr "breeze" pkgs) // {
    breeze-qt4 = mkQt4Pkg pkgs.breeze;
    breeze-qt5 = mkQt5Pkg pkgs.breeze;
  };

  repackager = pkgs: fold (f: x: f x) pkgs
    [ splitBreeze
      (blacklist ["kwayland"])
    ];

  renameDeps = nameMap: pkg:
    let lookupNames = map (name: nameMap."${name}" or name);
    in pkg // {
      buildInputs = lookupNames pkg.buildInputs;
      nativeBuildInputs = lookupNames pkg.nativeBuildInputs;
      propagatedBuildInputs = lookupNames pkg.propagatedBuildInputs;
      propagatedNativeBuildInputs = lookupNames pkg.propagatedNativeBuildInputs;
      propagatedUserEnvPkgs = lookupNames pkg.propagatedUserEnvPkgs;
    };

  rewriter = name: pkg:
    renameDeps
      {
        fontforge_executable = "fontforge";
      }
      (
        {
          libmm-qt = removePkgDeps qt4Deps pkg;
          libnm-qt = removePkgDeps qt4Deps pkg;
        }."${name}" or pkg
      );

  kf5 = kf55.override { inherit debug; };
  scope = kf5.passthru.scope // plasma5;

  resolver = name: pkg: dep:
    if dep == "kde4"
      then [scope.kde4.kdelibs]
    else optional (hasAttr dep scope) scope."${dep}";

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

  packageSoftOverrides = with scope;
    {
      breeze-qt4 = {
        buildInputs = [ xlibs.xproto kde4.kdelibs qt4 ];
        nativeBuildInputs = [ cmake pkgconfig ];
        cmakeFlags = [ "-DUSE_KDE4=ON" ];
      };
      frameworkintegration = {
        buildInputs = [ plasma5.oxygen-fonts ];
      };
      kwin = {
        buildInputs = with xlibs; [ libICE libSM libXcursor ];
        patches = [ ./kwin/kwin-import-plugin-follow-symlinks.patch ];
      };
      libkscreen = {
        buildInputs = with xlibs; [ libXrandr ];
        patches = [ ./libkscreen/libkscreen-backend-path.patch ];
      };
      plasma-desktop = {
        buildInputs = with xlibs; [ pkgs.libcanberra libxkbfile libXcursor ];
        patches = [
          ./plasma-desktop/plasma-desktop-hwclock.patch
          ./plasma-desktop/plasma-desktop-zoneinfo.patch
        ];
        preConfigure = ''
          substituteInPlace kcms/dateandtime/helper.cpp \
            --subst-var-by hwclock "${utillinux}/sbin/hwclock"
        '';
      };
      plasma-workspace = {
        buildInputs = with xlibs; [ libSM libXcursor pkgs.pam ];
        postInstall = ''
          # We use a custom startkde script
          rm $out/bin/startkde
        '';
      };
      powerdevil = {
        buildInputs = with xlibs; [ libXrandr ];
      };
    };

  packageHardOverrides = {};

in plasma5 // {
  inherit kf5;
  passthru = { inherit scope; };
  startkde = scope.newScope scope ./startkde {};
}
