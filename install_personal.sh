#!/usr/bin/env bash
# Build, archive and install the PERSONAL release build (private, with sync).
#   applicationId: com.catchingclouds.marsthoughts.personal
# Same commands as install_release.sh (build | list | restore [versionCode]).
cd "$(dirname "$0")"
FLAVOR=personal exec ./install_release.sh "$@"
