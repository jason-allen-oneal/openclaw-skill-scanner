#!/usr/bin/env bash
# Regression tests for issue #4: namespaced ClawHub slugs.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAW="$ROOT/scripts/clawhub_scan_install.sh"

PASS=0
FAIL=0
fail() { echo "FAIL: $*"; FAIL=$((FAIL + 1)); }
pass() { echo "PASS: $*"; PASS=$((PASS + 1)); }

STAGE_ROOT="$(mktemp -d)"
set +e
STAGE_DIR=$(mktemp -d -p "$STAGE_ROOT" "clawhub-XXXXXXXX" 2>/tmp/mktemp-ok.err)
ok_ec=$?
set -e
if [[ $ok_ec -eq 0 && -d "${STAGE_DIR:-}" ]]; then
  pass "mktemp without slug slash works"
else
  fail "safe mktemp template failed"
fi
rm -rf "$STAGE_ROOT"

if grep -q 'clawhub-${SLUG}-XXXXXXXX' "$CLAW"; then
  fail "clawhub_scan_install.sh still embeds \$SLUG in mktemp template"
else
  pass "clawhub_scan_install.sh mktemp template has no \$SLUG slash"
fi

if grep -q -- '--name "$SLUG"' "$CLAW"; then
  fail "clawhub_scan_install.sh still passes full slug as --name"
else
  pass "clawhub_scan_install.sh does not pass full slug as --name"
fi

if grep -q 'DEST_NAME=' "$CLAW" && grep -F 'SLUG##*/' "$CLAW" >/dev/null; then
  pass "dest name is last path segment"
else
  fail "missing DEST_NAME last-segment assignment"
fi

echo "passed=$PASS failed=$FAIL"
[[ "$FAIL" -eq 0 ]]
