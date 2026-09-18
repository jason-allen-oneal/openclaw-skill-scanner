#!/usr/bin/env bash
# Shared wrapper paths. This file does not execute OpenClaw or parse its config.
# Configured per-agent workspaces/extraDirs can be scanned with --catalog or
# explicit roots in scan_openclaw_skills.sh.

oc_absolute_path() {
  local value="$1"
  case "$value" in
    '~') value="$OC_HOME" ;;
    '~/'*) value="$OC_HOME/${value:2}" ;;
  esac
  [[ "$value" == /* ]] || value="$PWD/$value"
  printf '%s\n' "$value"
}

OC_HOME="${OPENCLAW_HOME:-$HOME}"
case "$OC_HOME" in null|undefined) OC_HOME="$HOME" ;; esac
case "$OC_HOME" in '~') OC_HOME="$HOME" ;; '~/'*) OC_HOME="$HOME/${OC_HOME:2}" ;; esac
[[ "$OC_HOME" == /* ]] || OC_HOME="$PWD/$OC_HOME"
OC_PROFILE="${OPENCLAW_PROFILE:-default}"
if [[ ! "$OC_PROFILE" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]{0,63}$ ]]; then
  echo "ERROR: Invalid OPENCLAW_PROFILE" >&2
  return 2
fi
case "$OC_PROFILE" in [dD][eE][fF][aA][uU][lL][tT]) OC_PROFILE=default ;; esac

if [[ -n "${OPENCLAW_STATE_DIR:-}" ]]; then
  STATE_DIR="$(oc_absolute_path "$OPENCLAW_STATE_DIR")"
elif [[ "$OC_PROFILE" != default ]]; then
  STATE_DIR="$OC_HOME/.openclaw-$OC_PROFILE"
elif [[ ! -e "$OC_HOME/.openclaw" && -d "$OC_HOME/.clawdbot" ]]; then
  STATE_DIR="$OC_HOME/.clawdbot"
else
  STATE_DIR="$OC_HOME/.openclaw"
fi

if [[ -n "${OPENCLAW_WORKSPACE_DIR:-}" ]]; then
  WORKSPACE_DIR="$(oc_absolute_path "$OPENCLAW_WORKSPACE_DIR")"
elif [[ -n "${OPENCLAW_STATE_DIR:-}" || "$OC_PROFILE" != default ]]; then
  WORKSPACE_DIR="$STATE_DIR/workspace"
else
  WORKSPACE_DIR="$OC_HOME/.openclaw/workspace"
fi
SCANNER_DIR="$(oc_absolute_path "${SKILL_SCANNER_DIR:-$WORKSPACE_DIR/skill-scanner}")"
USER_SKILLS="$(oc_absolute_path "${OPENCLAW_SKILLS_DIR:-$STATE_DIR/skills}")"
OUT_DIR="$(oc_absolute_path "${SKILL_SCANNER_REPORT_DIR:-$WORKSPACE_DIR/skill_scans}")"
STAGE_ROOT="$(oc_absolute_path "${OPENCLAW_STAGE_DIR:-$WORKSPACE_DIR/.skill_stage}")"
QUARANTINE_BASE="$(oc_absolute_path "${OPENCLAW_QUARANTINE_DIR:-$STATE_DIR/skills-quarantine}")"
export OC_HOME OC_PROFILE STATE_DIR WORKSPACE_DIR USER_SKILLS
