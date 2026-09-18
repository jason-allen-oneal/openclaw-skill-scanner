#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/openclaw_paths.sh"
# Help works without an installed scanner or OpenClaw runtime.
if [[ ${1:-} == --help || ${1:-} == -h ]]; then
  python3 "$SCRIPT_DIR/discover_skill_dirs.py" --help
  exit 0
fi
[[ -d "$SCANNER_DIR" ]] || { echo "ERROR: Scanner repository not found: $SCANNER_DIR" >&2; exit 2; }
UV_BIN="$(command -v uv)" || { echo 'ERROR: uv not found in PATH' >&2; exit 2; }
umask 077
mkdir -p -- "$OUT_DIR"
INVENTORY="$(mktemp "$OUT_DIR/inventory_XXXXXXXX")"
trap 'rm -f -- "$INVENTORY"' EXIT
# Check discovery status before consuming its output (not process substitution).
python3 "$SCRIPT_DIR/discover_skill_dirs.py" "$@" >"$INVENTORY"
STATUS=0
COUNT=0
while IFS= read -r -d '' skill; do
  COUNT=$((COUNT + 1))
  REPORT="$(mktemp "$OUT_DIR/openclaw_skill_${COUNT}_XXXXXXXX.md")"
  echo "Scanning: $skill"
  if ! (cd -- "$SCANNER_DIR" && "$UV_BIN" run skill-scanner scan "$skill" --format markdown --detailed --output "$REPORT"); then
    echo "ERROR: scan failed: $skill" >&2
    STATUS=1
  fi
  if [[ ! -s "$REPORT" ]]; then
    echo "ERROR: empty scan report: $skill" >&2
    STATUS=1
  fi
  echo "Report: $REPORT"
done <"$INVENTORY"
if [[ "$COUNT" -eq 0 ]]; then
  echo 'No local skill manifests found in the selected sources.' >&2
  exit 1
fi
echo "Scanned $COUNT local skill directories. Review reports; this is not a safety certification."
exit "$STATUS"
