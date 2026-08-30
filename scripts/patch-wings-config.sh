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
# present with its default value), so this script rewrites values in
# place — inserting nested blocks would create duplicate YAML keys, and
# wings' parser silently keeps the default one. Flat keys are re-inserted
# only if missing (cleanup of older script versions can remove them).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$ROOT/wings/etc/config.yml"

if [ ! -f "$CONFIG" ]; then
    echo "❌ $CONFIG not found — run 'make wings-configure TOKEN=...' first" >&2
    exit 1
fi

# Clean up the duplicate blocks a previous (insert-based) version of this
# script may have left behind — they shadow the real keys.
sed -i '/# pelican-panel:managed$/d' "$CONFIG"

# Rewrite the managed values in place.
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

# Flat system keys are safe to (re-)insert when absent — no nesting involved.
ensure_flat() {
    grep -qE "^  $1:" "$CONFIG" || sed -i "/^system:/a\\
  $1: $2" "$CONFIG"
}
ensure_flat root_directory "$ROOT/wings/data"
ensure_flat data "$ROOT/wings/data/volumes"
ensure_flat archive_directory "$ROOT/wings/data/archives"
ensure_flat backup_directory "$ROOT/wings/data/backups"
ensure_flat tmp_directory "$ROOT/wings/tmp"
ensure_flat log_directory /var/log/pelican

if grep -qE 'directory: /etc/pelican|: /var/lib/pelican' "$CONFIG"; then
    echo "❌ patch incomplete: a directory still points to a /etc/pelican or /var/lib/pelican default — check $CONFIG" >&2
    exit 1
fi

echo "✅ wings config patched: data under $ROOT/wings/"
