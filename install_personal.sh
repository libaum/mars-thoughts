#!/usr/bin/env bash
# Wie install_release.sh, aber die private Version mit Sync.
exec app "$(dirname "$0")" "$@" --flavor personal
