#!/usr/bin/env bash
# Regression tests for issue #3: fail-open install gate.
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
export FAKE_SCAN_EXIT=1
export FAKE_SCAN_REPORT=""
set +e
"$SCAN" "$SRC" --name crash-skill >/tmp/scan-crash.out 2>/tmp/scan-crash.err
code=$?
set -e
if [[ $code -ne 0 && ! -e "$OPENCLAW_STATE_DIR/skills/crash-skill" ]]; then
  pass "scanner non-zero exit blocks install"
else
  fail "scanner non-zero exit installed or returned 0 (code=$code)"
fi
teardown

setup_env
export FAKE_SCAN_EXIT=0
export FAKE_SCAN_REPORT=""
set +e
"$SCAN" "$SRC" --name empty-report >/tmp/scan-empty.out 2>/tmp/scan-empty.err
code=$?
set -e
if [[ $code -ne 0 && ! -e "$OPENCLAW_STATE_DIR/skills/empty-report" ]]; then
  pass "empty/unparseable report blocks install"
else
  fail "empty report fail-opened (code=$code)"
fi
teardown

setup_env
export FAKE_SCAN_EXIT=0
export FAKE_SCAN_REPORT=$'- **Critical:** 2\n- **High:** 0\n- **Medium:** 0\n- **Low:** 0\n- **Info:** 0\n'
set +e
"$SCAN" "$SRC" --name crit-skill >/tmp/scan-crit.out 2>/tmp/scan-crit.err
code=$?
set -e
if [[ $code -ne 0 && ! -e "$OPENCLAW_STATE_DIR/skills/crit-skill" ]]; then
  pass "Critical findings block install"
else
  fail "Critical findings did not block (code=$code)"
fi
teardown

setup_env
export FAKE_SCAN_EXIT=0
export FAKE_SCAN_REPORT=$'- **Critical:** 0\n- **High:** 0\n- **Medium:** 1\n- **Low:** 0\n- **Info:** 0\n'
set +e
"$SCAN" "$SRC" --name warn-skill >/tmp/scan-warn.out 2>/tmp/scan-warn.err
code=$?
set -e
if [[ $code -eq 0 && -d "$OPENCLAW_STATE_DIR/skills/warn-skill" ]]; then
  pass "Medium-only findings still install"
else
  fail "Medium-only should install (code=$code)"
fi
teardown

echo "passed=$PASS failed=$FAIL"
[[ "$FAIL" -eq 0 ]]
