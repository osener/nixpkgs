{ autonix, pkgs, qt5, stdenv, debug ? false }:

with stdenv.lib; with autonix;

let

  kf5 = generateCollection ./. {
    mirror = "mirror://kde";
    inherit overrider resolver;
    deriver = name: stdenv.mkDerivation;
  };

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
      extra-cmake-modules = {
        cmakeFlags = [ "-DBUILD_TESTING=OFF" ];
        patches = [
          ./extra-cmake-modules/0001-libdir-default.patch
          ./extra-cmake-modules/0002-qt5-plugin-dir.patch
        ];
      };

      kauth = {
        buildInputs = [ polkit_qt5 ];
        patches = [ ./kauth/kauth-policy-install.patch ];
      };

      kcmutils = {
        patches = [ ./kcmutils/kcmutils-pluginselector-follow-symlinks.patch ];
      };

      kconfigwidgets = {
        patches =
          [ ./kconfigwidgets/kconfigwidgets-helpclient-follow-symlinks.patch ];
      };

      kdelibs4support = {
        buildInputs = [ networkmanager xlibs.libSM ];
        cmakeFlags = [
          "-DDocBookXML4_DTD_DIR=${docbook_xml_dtd_45}/xml/dtd/docbook"
          "-DDocBookXML4_DTD_VERSION=4.5"
        ];
      };

      kdoctools = {
        cmakeFlags = [
          "-DDocBookXML4_DTD_DIR=${docbook_xml_dtd_45}/xml/dtd/docbook"
          "-DDocBookXML4_DTD_VERSION=4.5"
          "-DDocBookXSL_DIR=${docbook5_xsl}/xml/xsl/docbook"
        ];
        patches = [
          ./kdoctools/kdoctools-no-find-docbook-xml.patch
        ];
      };

      ki18n = { propagatedNativeBuildInputs = [ gettext python ]; };

      kimageformats = { NIX_CFLAGS_COMPILE = "-I${ilmbase}/include/OpenEXR"; };

      kinit = { patches = [ ./kinit/kinit-libpath.patch ]; };

      kservice = {
        buildInputs = [ kf5.kwindowsystem ];
        patches = [
          ./kservice/kservice-kbuildsycoca-follow-symlinks.patch
          ./kservice/kservice-kbuildsycoca-no-canonicalize-path.patch
        ];
      };

      plasma-framework = {
        patches = [ ./plasma-framework/plasma-framework-external-paths.patch ];
      };

    };

  packageHardOverrides = with scope;
    {
      extra-cmake-modules = {
        propagatedNativeBuildInputs = [ cmake pkgconfig ];
        meta = {
          license = with stdenv.lib.licenses; [ bsd2 ];
          platforms = stdenv.lib.platforms.linux;
          maintainers = with stdenv.lib.maintainers; [ ttuegel ];
          homepage = "http://www.kde.org";
        };
      };
    };

  resolver = name: pkg: dep: optional (hasAttr dep scope) scope."${dep}";

  scope =
    pkgs
    // {
      inherit qt5 stdenv;
      gst = pkgs.gst_all_1;
      inherit (pkgs.gst_all_1) gstreamer;
      dbusmenu-qt5 = pkgs.libdbusmenu_qt5.override { inherit qt5; };
      phonon4qt5 = pkgs.phonon_qt5.override { inherit qt5; };
      polkit_qt5 = pkgs.polkit_qt5.override { inherit qt5; };
      prison = pkgs.callPackage ../prison/qt5.nix {
        inherit (kf5) extra-cmake-modules;
      };
      gif = pkgs.giflib;
      jpeg = pkgs.libjpeg;
      liblzma = pkgs.lzma;
      png = pkgs.libpng;
      pythoninterp = pkgs.python;
      qt5core = qt5;
      qt5dbus = qt5;
      qt5gui = qt5;
      sharedmimeinfo = pkgs.shared_mime_info;
      xcb = pkgs.xlibs.xcbproto;
    }
    // kf5;

in
kf5 // {
  passthru = {
    inherit scope;
  };
}
