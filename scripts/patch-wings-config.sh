#!/usr/bin/env bash
#
# Point the wings directories to this project root instead of the
# /var/lib/pelican and /etc/pelican defaults. Run after `wings configure`
# (re)generates ./wings/etc/config.yml — idempotent.
#
# Every directory listed here is handed by wings to the HOST docker daemon
# as a bind mount source when it creates the game containers (server data,
# install tmp, passwd/group files, machine-id), so each of them must be a
# path that exists identically on the host and inside the wings container
# — i.e. live under the same-path mounts wings/data and wings/tmp.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$ROOT/wings/etc/config.yml"
MARK="# pelican-panel:managed"

if [ ! -f "$CONFIG" ]; then
    echo "❌ $CONFIG not found — run 'make wings-configure TOKEN=...' first" >&2
    exit 1
fi

# Drop lines from a previous run of this script, then the panel-generated
# definitions of the keys we manage (2-space indented keys of "system").
sed -i "/$MARK\$/d" "$CONFIG"
sed -i -E '/^  (root_directory|data|archive_directory|backup_directory|tmp_directory|log_directory):/d' "$CONFIG"

if ! grep -q '^system:' "$CONFIG"; then
    echo 'system:' >> "$CONFIG"
fi

sed -i "/^system:/a\\
  root_directory: $ROOT/wings/data $MARK\\
  data: $ROOT/wings/data/volumes $MARK\\
  archive_directory: $ROOT/wings/data/archives $MARK\\
  backup_directory: $ROOT/wings/data/backups $MARK\\
  tmp_directory: $ROOT/wings/tmp $MARK\\
  log_directory: /var/log/pelican $MARK\\
  user: $MARK\\
    passwd: $MARK\\
      directory: $ROOT/wings/data/etc $MARK\\
  machine_id: $MARK\\
    directory: $ROOT/wings/data/etc/machine-id $MARK" "$CONFIG"

echo "✅ wings config patched: data under $ROOT/wings/"
