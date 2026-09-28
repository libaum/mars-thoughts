#!/usr/bin/env bash
# flutter run (Hot Reload). FLAVOR=personal für die private Version.
exec app "$(dirname "$0")" run --flavor "${FLAVOR:-store}" "$@"
