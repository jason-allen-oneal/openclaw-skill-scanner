#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'HELP'
Usage: scan_and_add_skill.sh <skill-dir> [--name NAME] [--force]
Scan before copying into the active state's managed skills directory.
High/Critical findings block; Medium/Low/Info warn. --force overrides findings,
never a failed scanner or an unreadable report. Existing destinations are not replaced.
HELP
}
if [[ ${1:-} == -h || ${1:-} == --help || ${1:-} == help ]]; then usage; exit 0; fi
SRC_DIR=${1:-}
shift || true
if [[ -z "$SRC_DIR" || ! -d "$SRC_DIR" ]]; then
  echo "ERROR: Skill directory not found: $SRC_DIR" >&2; exit 2
fi
DEST_NAME="$(basename -- "$SRC_DIR")"
FORCE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=1; shift ;;
    --name) [[ -n ${2:-} ]] || { echo 'ERROR: --name requires a value' >&2; exit 2; }; DEST_NAME=$2; shift 2 ;;
    *) echo "ERROR: Unknown arg: $1" >&2; exit 2 ;;
  esac
done
# Validate before canonicalizing, preserving rejection of basename '.' and '..'.
[[ "$DEST_NAME" =~ ^[a-zA-Z0-9_-]+$ ]] || { echo 'ERROR: Invalid destination name' >&2; exit 2; }
SRC_DIR="$(cd -- "$SRC_DIR" && pwd -P)"
[[ -f "$SRC_DIR/SKILL.md" ]] || { echo 'ERROR: Skill must contain SKILL.md' >&2; exit 2; }
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/openclaw_paths.sh"
[[ -d "$SCANNER_DIR" ]] || { echo "ERROR: Scanner repository not found: $SCANNER_DIR" >&2; exit 2; }
UV_BIN="$(command -v uv)" || { echo 'ERROR: uv not found in PATH' >&2; exit 2; }
umask 077
mkdir -p -- "$OUT_DIR"
# Unique report files prevent a previous same-second report from being reused.
REPORT="$(mktemp "$OUT_DIR/${DEST_NAME}_XXXXXXXX.md")"
SCAN_OUT="${REPORT%.md}.txt"
SCAN_CODE=0
(cd -- "$SCANNER_DIR" && "$UV_BIN" run skill-scanner scan "$SRC_DIR" --format markdown --detailed --output "$REPORT") >"$SCAN_OUT" 2>&1 || SCAN_CODE=$?
if [[ "$SCAN_CODE" -ne 0 ]]; then
  echo "BLOCKED: scanner exited $SCAN_CODE. --force cannot bypass a failed scan. Log: $SCAN_OUT" >&2
  exit 1
fi
get_count() {
  local label="$1" n
  n=$(sed -nE "s/^[[:space:]]*[-*][[:space:]]+\\*\\*${label}:\\*\\*[[:space:]]*([0-9]+)[[:space:]]*$/\\1/p" "$REPORT")
  [[ "$n" =~ ^[0-9]+$ && ${#n} -le 9 ]] || return 1
  printf '%s\n' "$((10#$n))"
}
COUNTS=()
for severity in Critical High Medium Low Info; do
  count="$(get_count "$severity")" || { echo "BLOCKED: missing/invalid $severity summary. Report: $REPORT" >&2; exit 1; }
  COUNTS+=("$count")
done
if (( COUNTS[0] > 0 || COUNTS[1] > 0 )); then
  if [[ "$FORCE" -ne 1 ]]; then echo "BLOCKED: High/Critical findings. Report: $REPORT" >&2; exit 1; fi
  echo "WARNING: explicitly overriding High/Critical findings. Report: $REPORT" >&2
elif (( COUNTS[2] > 0 || COUNTS[3] > 0 || COUNTS[4] > 0 )); then
  echo 'Scan result: ALLOWED WITH WARNINGS (no High/Critical)'
else
  echo 'Scan result: CLEAN (no findings; not a safety guarantee)'
fi
DEST_DIR="$USER_SKILLS/$DEST_NAME"
mkdir -p -- "$USER_SKILLS"
# Include dangling symlinks in the collision check.
[[ ! -e "$DEST_DIR" && ! -L "$DEST_DIR" ]] || { echo "ERROR: Destination already exists: $DEST_DIR" >&2; exit 3; }
cp -a -- "$SRC_DIR" "$DEST_DIR"
echo "Installed skill to: $DEST_DIR"
echo "Report: $REPORT"
