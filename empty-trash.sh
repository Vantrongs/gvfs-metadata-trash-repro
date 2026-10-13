#!/usr/bin/env bash
# Usage: run through ./run.sh, never directly.
# Trashes a directory of N empty files, empties the trash with
# `gio trash --empty`, and reports how long gvfsd-metadata stays busy.
set -euo pipefail
export LC_ALL=C
N=$1
case "$HOME" in /tmp/*) ;; *) echo "refusing: HOME=$HOME is not a throwaway directory under /tmp"; exit 1;; esac
[ "${XDG_DATA_HOME:-}" = "$HOME/.local/share" ] || { echo "refusing: XDG_DATA_HOME is not under HOME"; exit 1; }

dir=$HOME/tree
mkdir -p "$dir" "$XDG_DATA_HOME"
(cd "$dir" && seq -f "file-%06g.txt" 1 "$N" | xargs touch)
gio set "$dir/file-000001.txt" metadata::note x   # creates the metadata database
gio trash "$dir"
[ "$(gio list trash:///)" = "tree" ] || { echo "refusing: trash:/// holds more than the test directory"; exit 1; }

pid=$(gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus \
        --method org.freedesktop.DBus.GetConnectionUnixProcessID org.gtk.vfs.Metadata | sed -E 's/[^ ]* ([0-9]+).*/\1/')
dbus-monitor --session "interface='org.gtk.vfs.Metadata'" > "$HOME/bus.txt" 2>/dev/null &
monitor=$!
sleep 1
cpu() { awk '{print $14 + $15}' "/proc/$pid/stat"; }
cpu0=$(cpu)
t0=$(date +%s.%N)
gio trash --empty
files_gone= peak=0 last= still=0
while :; do
  now=$(date +%s.%N)
  if [ -z "$files_gone" ] && [ -z "$(ls -A "$XDG_DATA_HOME/Trash/files")" ] \
     && [ -z "$(ls -A "$XDG_DATA_HOME/Trash/expunged" 2>/dev/null)" ]; then
    files_gone=$(echo "$now - $t0" | bc)
  fi
  rss=$(awk '/^VmRSS/ {print $2}' "/proc/$pid/status"); [ "$rss" -gt "$peak" ] && peak=$rss
  c=$(cpu); if [ "$c" = "$last" ]; then still=$((still + 1)); else still=0; last=$c; fi
  [ "$still" -ge 25 ] && break      # no CPU used for 5 s: the daemon is idle
  sleep 0.2
done
done_at=$(echo "$now - $t0 - 5" | bc)
kill "$monitor"
printf 'files: %d\nfiles deleted after: %.1f s\ngvfsd-metadata busy for: %.1f s (CPU %.1f s)\nRemove calls received: %d\nAttributeChanged signals: %d\npeak RSS: %d MiB\n' \
  "$N" "$files_gone" "$done_at" "$(echo "($(cpu) - $cpu0) / $(getconf CLK_TCK)" | bc -l)" \
  "$(grep -c 'member=Remove' "$HOME/bus.txt")" "$(grep -c 'member=AttributeChanged' "$HOME/bus.txt")" $((peak / 1024))
