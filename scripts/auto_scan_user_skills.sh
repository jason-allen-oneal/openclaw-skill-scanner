#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/openclaw_paths.sh"
[[ -d "$USER_SKILLS" ]] || { echo "No managed skills directory: $USER_SKILLS"; exit 0; }
[[ -d "$SCANNER_DIR" ]] || { echo "ERROR: Scanner repository not found: $SCANNER_DIR" >&2; exit 2; }
UV_BIN="$(command -v uv)" || { echo 'ERROR: uv not found in PATH' >&2; exit 2; }
umask 077
OUT_DIR="$OUT_DIR/auto"
mkdir -p -- "$OUT_DIR"
INVENTORY="$(mktemp "$OUT_DIR/inventory_XXXXXXXX")"
trap 'rm -f -- "$INVENTORY"' EXIT
python3 "$SCRIPT_DIR/discover_skill_dirs.py" --only-roots "$USER_SKILLS" >"$INVENTORY"
STATUS=0
while IFS= read -r -d '' skill; do
  REPORT="$(mktemp "$OUT_DIR/openclaw_skill_XXXXXXXX.md")"
  if ! (cd -- "$SCANNER_DIR" && "$UV_BIN" run skill-scanner scan "$skill" --format markdown --detailed --output "$REPORT"); then
    echo "ERROR: scan failed; no safety verdict or quarantine applied: $skill" >&2
    STATUS=1; continue
  fi
  COUNTS=()
  for severity in Critical High; do
    count=$(sed -nE "s/^[[:space:]]*[-*][[:space:]]+\\*\\*${severity}:\\*\\*[[:space:]]*([0-9]+)[[:space:]]*$/\\1/p" "$REPORT")
    if [[ ! "$count" =~ ^[0-9]+$ || ${#count} -gt 9 ]]; then
      echo "ERROR: missing/invalid $severity summary: $REPORT" >&2
      STATUS=1; break
    fi
    COUNTS+=("$((10#$count))")
  done
  [[ ${#COUNTS[@]} -eq 2 ]] || continue
  echo "Scan report: $REPORT critical=${COUNTS[0]} high=${COUNTS[1]}"
  if (( COUNTS[0] > 0 || COUNTS[1] > 0 )); then
    STATUS=1
    # Quarantine the directory we actually scanned, never a path from report text.
    python3 - "$USER_SKILLS" "$skill" "$QUARANTINE_BASE" <<'PY' || STATUS=1
import os
from pathlib import Path
import sys
import uuid
root, source, quarantine = map(Path, sys.argv[1:])
root, quarantine = root.resolve(), quarantine.resolve()
resolved = source.resolve()
if resolved == root or root not in resolved.parents or resolved != source.absolute():
    raise SystemExit('Refusing quarantine outside managed skills or through a symlink')
if quarantine == root or root in quarantine.parents:
    raise SystemExit('Quarantine must be outside the active managed skill tree')
quarantine.mkdir(parents=True, exist_ok=True)
destination = quarantine / (source.name + '-' + uuid.uuid4().hex)
# Atomic on one filesystem; a cross-device move fails without copying/deleting.
os.rename(source, destination)
print(f'Quarantined: {source} -> {destination}')
PY
  fi
done <"$INVENTORY"
exit "$STATUS"
