{ autonix, haskellPackages, kde4, kf55, pkgs, qt4, stdenv
, debug ? false }:

with stdenv.lib; with autonix;

let

  isQt45Pkg = pkg: hasDep "qt4" pkg && hasDep "qt5" pkg;
  mkQt4Pkg = pkg:
    let qt5Deps = [ "qt5" ] ++ attrNames kf5 ++ attrNames plasma5;
        name = builtins.parseDrvName pkg.name;
    in (removePkgDeps qt5Deps pkg) // {
      name = name.name + "-qt4-" + name.version;
    };
  mkQt5Pkg = pkg:
    let qt4Deps = [ "qt4" ];
        name = builtins.parseDrvName pkg.name;
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

  removeAttr = name: filterAttrs (n: x: n != name);

  splitBreeze = pkgs: (removeAttr "breeze" pkgs) // {
    breeze-qt4 = mkQt4Pkg pkgs.breeze;
    breeze-qt5 = mkQt5Pkg pkgs.breeze;
  };

  packages =
    fold (f: x: f x)
      (importPackages ./. { mirror = "mirror://kde"; })
      [ splitBreeze
        splitQt45Pkgs
        (removeDeps [ "kf5" "kde4" ])
        (blacklist [ "kwayland" ])
        (pkgs: pkgs // { plasma-desktop = removePkgDeps [ "qt4" ] pkgs.plasma-desktop; })
        (pkgs: pkgs // { libmm-qt = removePkgDeps [ "qt4" ] pkgs.libmm-qt; })
        (pkgs: pkgs // { libnm-qt = removePkgDeps [ "qt4" ] pkgs.libnm-qt; })
      ];

  kf5 = kf55.override { inherit debug; };
  inherit (kf5) qt5;

  extraInputs = kf5 // { inherit kde4; };

  extraOutputs = {
    inherit kf5 qt5;
    poppler_qt5 = (pkgs.poppler.override { inherit qt5; }).poppler_qt5;
    startkde = plasma5.dev.callPackage ./startkde {};
  };

  names = with pkgs; with extraOutputs; kf5.dev.names // {
    inherit epoxy;
    epub = ebook_tools;
    inherit exiv2 ffmpeg fontconfig;
    fontforge_executable = fontforge;
    inherit freetype;
    gio = glib;
    glib2 = glib;
    inherit ibus;
    mobilebroadbandproviderinfo = mobile_broadband_provider_info;
    inherit modemmanager networkmanager openconnect pciutils;
    popplerqt5 = poppler_qt5;
    inherit (kf5) prison;
    inherit pulseaudio;
    raw1394 = libraw1394;
    sensors = lm_sensors;
    inherit taglib;
    usb = libusb;
    inherit xapian;
  };

  overrides = {
    breeze-qt4 = {
      buildInputs = [ pkgs.xlibs.xproto kde4.kdelibs qt4 ];
      nativeBuildInputs = with pkgs; [ cmake pkgconfig ];
      cmakeFlags = [ "-DUSE_KDE4=ON" ];
    };
    frameworkintegration = {
      buildInputs = [ plasma5.oxygen-fonts ];
    };
    kwin = {
      buildInputs = with pkgs.xlibs; [ libICE libSM libXcursor ];
    };
    libkscreen = {
      buildInputs = with pkgs.xlibs; [ libXrandr ];
    };
    plasma-desktop = {
      buildInputs = with pkgs.xlibs; [ pkgs.libcanberra libxkbfile libXcursor ];
    };
    plasma-workspace = {
      buildInputs = with pkgs.xlibs; [ libSM libXcursor pkgs.pam ];
    };
    powerdevil = {
      buildInputs = with pkgs.xlibs; [ libXrandr ];
    };
  };

  plasma5 = autonix.generateCollection ./. {
    inherit packages extraInputs extraOutputs names overrides;
    deriver = kf5.dev.mkDerivation;
  };

in plasma5
