#!/usr/bin/env bash
set -euo pipefail
# Build, archive and install a RELEASE build of Mars Thoughts.
#   store    (default) applicationId com.catchingclouds.marsthoughts — the Play Store app
#   personal           applicationId com.catchingclouds.marsthoughts.personal — private build with sync
# Both are release-signed. Pick the flavor with FLAVOR=personal, or use
# ./install_personal.sh which does exactly that.
# Every build is archived under apk_archive/ so a known-good version can be
# reinstalled later without rebuilding — handy when a new build regresses.
#
# Usage:
#   ./install_release.sh              build a fresh release APK, archive it, install
#   ./install_release.sh list         list archived APKs (newest first)
#   ./install_release.sh restore      install the most recent archived APK (no build)
#   ./install_release.sh restore 21   install the archived APK for versionCode 21
cd "$(dirname "$0")"

FLAVOR="${FLAVOR:-store}"
ARCHIVE_DIR="apk_archive"
APK_OUT="build/app/outputs/flutter-apk/app-${FLAVOR}-release.apk"
# Store archives keep the original "mars_" prefix so older ones still match.
case "$FLAVOR" in
  store)    ARCHIVE_PREFIX="mars_" ;;
  personal) ARCHIVE_PREFIX="mars-personal_" ;;
  *) echo "Unknown flavor '$FLAVOR' (store|personal)." >&2; exit 1 ;;
esac

require_device() {
  if [ -z "$(adb devices | sed '1d' | grep -w device || true)" ]; then
    echo "No device connected (check 'adb devices')." >&2
    exit 1
  fi
}

install_apk() {
  # -r reinstall keeping data, -d allow version downgrade (so rollbacks work)
  echo "==> Installing $(basename "$1")"
  adb install -r -d "$1"
}

case "${1:-build}" in
  list)
    ls -1t "$ARCHIVE_DIR"/"$ARCHIVE_PREFIX"*.apk 2>/dev/null || echo "No archived $FLAVOR APKs in $ARCHIVE_DIR/."
    ;;
  restore)
    require_device
    if [ -n "${2:-}" ]; then
      apk=$(ls -1t "$ARCHIVE_DIR"/"$ARCHIVE_PREFIX"*"+${2}_"*.apk 2>/dev/null | head -n1 || true)
      [ -z "$apk" ] && { echo "No archived $FLAVOR APK for versionCode ${2}." >&2; exit 1; }
    else
      apk=$(ls -1t "$ARCHIVE_DIR"/"$ARCHIVE_PREFIX"*.apk 2>/dev/null | head -n1 || true)
      [ -z "$apk" ] && { echo "No archived $FLAVOR APKs in $ARCHIVE_DIR/." >&2; exit 1; }
    fi
    install_apk "$apk"
    ;;
  build)
    require_device
    echo "==> Building $FLAVOR release APK"
    flutter build apk --release --flavor "$FLAVOR"
    mkdir -p "$ARCHIVE_DIR"
    version=$(grep -m1 '^version:' pubspec.yaml | sed 's/version:[[:space:]]*//')
    githash=$(git rev-parse --short HEAD 2>/dev/null || echo nogit)
    stamp=$(date +%Y%m%d-%H%M%S)
    archived="$ARCHIVE_DIR/${ARCHIVE_PREFIX}${version}_${githash}_${stamp}.apk"
    cp "$APK_OUT" "$archived"
    echo "==> Archived $(basename "$archived")"
    install_apk "$archived"
    ;;
  *)
    echo "Usage: [FLAVOR=store|personal] $0 [build|list|restore [versionCode]]" >&2
    exit 1
    ;;
esac
