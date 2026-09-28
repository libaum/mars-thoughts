#!/usr/bin/env bash
# Release bauen, archivieren, installieren – siehe `app --help`.
#   ./install_release.sh [list|restore [versionCode]]   FLAVOR=personal für die private Version
exec app "$(dirname "$0")" "$@"
