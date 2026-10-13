#!/usr/bin/env bash
# Usage: ./run.sh <number of files>
# Runs empty-trash.sh on a private session bus with a throwaway HOME under /tmp,
# so the gvfs daemons it starts never see your real trash or metadata.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d /tmp/gvfs-metadata-repro.XXXXXX)
mkdir -p "$work/home"
# Services activated by the bus inherit the bus's environment, so the
# throwaway HOME and XDG dirs must be set before the bus starts.
env HOME="$work/home" XDG_DATA_HOME="$work/home/.local/share" \
    XDG_CACHE_HOME="$work/home/.cache" XDG_CONFIG_HOME="$work/home/.config" \
    dbus-run-session --config-file="$here/session.conf" -- "$here/empty-trash.sh" "$1" 2>&1 \
  | grep -vE '^dbus-daemon|^$|fusermount|bus can.t be made' || true
rm -rf "$work"
