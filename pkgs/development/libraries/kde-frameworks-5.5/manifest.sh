#!/bin/sh

if [ $# -eq 0 ]; then

  # The extra slash at the end of the URL is necessary to stop wget
  # from recursing over the whole server! (No, it's not a bug.)
  ../../../build-support/autonix/manifest.sh \
    http://download.kde.org/stable/frameworks/5.5/ \
      -A '*.tar.xz'

else

  ../../../build-support/autonix/manifest.sh -A '*.tar.xz' "$@"

fi
