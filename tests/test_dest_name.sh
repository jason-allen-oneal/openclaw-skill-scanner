#!/usr/bin/env bash
# Regression tests for issue #5: unsanitized default dest name.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAN="$ROOT/scripts/scan_and_add_skill.sh"
FAKE_UV="$ROOT/tests/helpers/fake-uv"
chmod +x "$FAKE_UV" "$SCAN"

PASS=0
FAIL=0
fail() { echo "FAIL: $*"; FAIL=$((FAIL + 1)); }
pass() { echo "PASS: $*"; PASS=$((PASS + 1)); }

setup_env() {
  TEST_HOME="$(mktemp -d)"
  export OPENCLAW_STATE_DIR="$TEST_HOME/state"
  export OPENCLAW_WORKSPACE_DIR="$TEST_HOME/workspace"
  mkdir -p "$OPENCLAW_WORKSPACE_DIR/skill-scanner" "$OPENCLAW_STATE_DIR/skills"
  : >"$OPENCLAW_WORKSPACE_DIR/skill-scanner/.keep"
  SRC="$(mktemp -d)"
  echo "skill" >"$SRC/SKILL.md"
  ln -sfn "$FAKE_UV" "$(dirname "$FAKE_UV")/uv"
  PATH="$(dirname "$FAKE_UV"):$PATH"
  export PATH
}

teardown() {
  rm -rf "${TEST_HOME:-}" "${SRC:-}"
}

setup_env
export FAKE_SCAN_EXIT=0
export FAKE_SCAN_REPORT=$'- **Critical:** 0\n- **High:** 0\n- **Medium:** 0\n- **Low:** 0\n- **Info:** 0\n'
DOTDOT="$TEST_HOME/dotdot/.."
mkdir -p "$TEST_HOME/dotdot"
set +e
"$SCAN" "$DOTDOT" >/tmp/scan-dotdot.out 2>/tmp/scan-dotdot.err
code=$?
set -e
if [[ $code -eq 2 ]] && ! grep -q "Installed skill" /tmp/scan-dotdot.out /tmp/scan-dotdot.err 2>/dev/null; then
  pass "default dest name rejects .."
else
  fail "basename .. was accepted (code=$code)"
fi
teardown

setup_env
export FAKE_SCAN_EXIT=0
export FAKE_SCAN_REPORT=$'- **Critical:** 0\n- **High:** 0\n- **Medium:** 0\n- **Low:** 0\n- **Info:** 0\n'
set +e
"$SCAN" "$SRC" --name "skill-scanner-guard" >/tmp/scan-last.out 2>/tmp/scan-last.err
last_code=$?
set -e
if [[ $last_code -eq 0 && -d "$OPENCLAW_STATE_DIR/skills/skill-scanner-guard" ]]; then
  pass "valid dest name still installs"
else
  fail "valid dest name failed (code=$last_code)"
fi
teardown

echo "passed=$PASS failed=$FAIL"
[[ "$FAIL" -eq 0 ]]
