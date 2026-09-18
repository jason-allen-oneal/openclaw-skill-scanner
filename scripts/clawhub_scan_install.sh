#!/usr/bin/env bash
set -euo pipefail
usage() {
  cat <<'HELP'
Usage: clawhub_scan_install.sh <slug> [--version VERSION] [--force]
Download into staging, scan, and copy into the active state's managed skills.
--force overrides findings only, not a failed or unreadable scan.
--tag is not supported; use --version to select an exact version.
HELP
}
if [[ ${1:-} == -h || ${1:-} == --help || ${1:-} == help ]]; then usage; exit 0; fi
SLUG=${1:-}
shift || true
[[ "$SLUG" =~ ^([a-zA-Z0-9][a-zA-Z0-9_-]*/)?[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]] || { echo 'ERROR: Invalid skill slug' >&2; exit 2; }
VERSION=''
FORCE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) [[ -n ${2:-} ]] || { echo 'ERROR: --version requires a value' >&2; exit 2; }; VERSION=$2; shift 2 ;;
    --force) FORCE=1; shift ;;
    --tag) echo 'ERROR: --tag is unsupported; use --version' >&2; exit 2 ;;
    *) echo "ERROR: Unknown arg: $1" >&2; exit 2 ;;
  esac
done
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/openclaw_paths.sh"
umask 077
mkdir -p -- "$STAGE_ROOT"
STAGE_DIR="$(mktemp -d "$STAGE_ROOT/clawhub-XXXXXXXX")"
DEST_NAME="${SLUG##*/}"
INSTALL_ARGS=(install "$SLUG")
[[ -z "$VERSION" ]] || INSTALL_ARGS+=(--version "$VERSION")
(cd -- "$STAGE_DIR" && npx -y clawhub --workdir "$STAGE_DIR" --dir skills "${INSTALL_ARGS[@]}")
CANDIDATE=''
for cand in "$STAGE_DIR/skills/$DEST_NAME" "$STAGE_DIR/skills/$SLUG"; do
  if [[ -d "$cand" && ! -L "$cand" && -f "$cand/SKILL.md" ]]; then CANDIDATE="$cand"; break; fi
done
[[ -n "$CANDIDATE" ]] || { echo "ERROR: Expected staged skill missing under $STAGE_DIR/skills" >&2; exit 3; }
ADD_ARGS=("$CANDIDATE" --name "$DEST_NAME")
[[ "$FORCE" -ne 1 ]] || ADD_ARGS+=(--force)
# Resolve beside this script, regardless of installation folder or skill name.
"$SCRIPT_DIR/scan_and_add_skill.sh" "${ADD_ARGS[@]}"
echo "Staging directory preserved at: $STAGE_DIR"
