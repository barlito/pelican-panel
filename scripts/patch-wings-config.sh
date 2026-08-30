#!/usr/bin/env bash
#
# Point the wings directories to this project root instead of the
# /var/lib/pelican and /etc/pelican defaults. Run after `wings configure`
# (re)generates ./wings/etc/config.yml — idempotent.
#
# Every directory rewritten here is handed by wings to the HOST docker
# daemon as a bind mount source when it creates the game containers
# (server data, install tmp, passwd/group files, machine-id), so each of
# them must exist identically on the host and inside the wings container
# — i.e. live under the same-path mounts wings/data and wings/tmp.
#
# `wings configure` writes the fully-materialized config (every key
# present with its default value), so this script only rewrites values in
# place — inserting blocks would create duplicate YAML keys, and wings'
# parser silently keeps the default one.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$ROOT/wings/etc/config.yml"

if [ ! -f "$CONFIG" ]; then
    echo "❌ $CONFIG not found — run 'make wings-configure TOKEN=...' first" >&2
    exit 1
fi

awk -v root="$ROOT" '
  /^[a-z]/                { in_passwd=0; in_machine=0 }
  /^  root_directory:/    { print "  root_directory: " root "/wings/data"; next }
  /^  data:/              { print "  data: " root "/wings/data/volumes"; next }
  /^  archive_directory:/ { print "  archive_directory: " root "/wings/data/archives"; next }
  /^  backup_directory:/  { print "  backup_directory: " root "/wings/data/backups"; next }
  /^  tmp_directory:/     { print "  tmp_directory: " root "/wings/tmp"; next }
  /^  log_directory:/     { print "  log_directory: /var/log/pelican"; next }
  /^    passwd:/          { in_passwd=1; print; next }
  /^  machine_id:/        { in_machine=1; print; next }
  in_passwd && /^      directory:/ { print "      directory: " root "/wings/data/etc"; in_passwd=0; next }
  in_machine && /^    directory:/  { print "    directory: " root "/wings/data/etc/machine-id"; in_machine=0; next }
  { print }
' "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"

if grep -qE 'directory: /etc/pelican' "$CONFIG"; then
    echo "❌ patch incomplete: a directory still points to /etc/pelican — check $CONFIG" >&2
    exit 1
fi

echo "✅ wings config patched: data under $ROOT/wings/"
