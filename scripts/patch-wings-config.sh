#!/usr/bin/env bash
#
# Point the wings directories to this project root instead of the
# /var/lib/pelican defaults. Run after `wings configure` (re)generates
# ./wings/etc/config.yml — idempotent.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$ROOT/wings/etc/config.yml"

if [ ! -f "$CONFIG" ]; then
    echo "❌ $CONFIG not found — run 'make wings-configure TOKEN=...' first" >&2
    exit 1
fi

# Drop any existing definition of the directories we manage (2-space
# indented keys of the "system" block), then re-insert our values.
sed -i -E '/^  (root_directory|data|archive_directory|backup_directory|tmp_directory|log_directory):/d' "$CONFIG"

if ! grep -q '^system:' "$CONFIG"; then
    echo 'system:' >> "$CONFIG"
fi

sed -i "/^system:/a\\
  root_directory: $ROOT/wings/data\\
  data: $ROOT/wings/data/volumes\\
  archive_directory: $ROOT/wings/data/archives\\
  backup_directory: $ROOT/wings/data/backups\\
  tmp_directory: $ROOT/wings/tmp\\
  log_directory: /var/log/pelican" "$CONFIG"

echo "✅ wings config patched: data under $ROOT/wings/"
