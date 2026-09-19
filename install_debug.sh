#!/bin/bash
set -e
# Store flavor by default. FLAVOR=personal ./install_debug.sh runs the
# private build with sync ("Mars Thoughts Personal Debug").
flutter run --debug --flavor "${FLAVOR:-store}"
