{ fetchurl }:

attr: pkg:

fetchurl { inherit (pkg.src) url name sha256; }
