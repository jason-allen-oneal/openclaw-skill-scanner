---
name: openclaw-skill-scanner
description: Scan local or staged ClawHub skills before installation; report High/Critical findings and optionally quarantine managed skills. A scan is not proof of safety.
metadata: {"openclaw":{"requires":{"bins":["bash","python3","uv"]}}}
---

# Skill Scanner Guard

Use a separately reviewed installation of cisco-ai-defense/skill-scanner.
The default scanner checkout is `<workspace>/skill-scanner`; override it with
`SKILL_SCANNER_DIR`. These scripts do not establish that a scanner checkout,
OpenClaw installation, or candidate skill is trustworthy. Do not execute a
candidate skill as part of review.

## Scan before installing

```bash
bash {baseDir}/scripts/scan_and_add_skill.sh /absolute/path/to/skill
bash {baseDir}/scripts/clawhub_scan_install.sh publisher/skill --version VERSION
```

ClawHub staging additionally requires `npx`. Downloads stay in a private staging
directory outside the default skill roots. Existing destination folders are not
replaced. High/Critical findings block; Medium/Low/Info findings allow with a
warning. `--force` overrides findings only, never scanner errors or incomplete
severity summaries. `--tag` is rejected rather than silently ignored.

These are explicit wrappers, not an interception hook for `openclaw skills
install`, ClawHub installs performed elsewhere, skill updates, or Workshop apply.
Never describe a successful scan as a safety guarantee.

## Scan installed skills

```bash
bash {baseDir}/scripts/scan_openclaw_skills.sh
bash {baseDir}/scripts/scan_openclaw_skills.sh --only-roots /path/to/skill/root
bash {baseDir}/scripts/scan_openclaw_skills.sh --catalog --agent main
```

Filesystem-only mode checks managed, default workspace, project `.agents`,
default-state personal `.agents`, workshop, and discoverable bundled sources.
Grouped skills are discovered up to six levels deep, stopping at `SKILL.md`.
Symlink skill directories require explicit review; discovery errors are not
reported as a successful complete scan.

`--catalog` explicitly executes the installed OpenClaw CLI. Use it only with an
installation you trust. It uses `skills list --json` and `skills info --json` to
include configured agent workspaces and extra/plugin/bundled sources. It does
not inspect every user's private library, disconnected nodes, remote hosts, or
shadowed skills outside the selected roots. Unavailable local manifests fail
inventory creation. No candidate skill code is executed by discovery.

## Paths

`OPENCLAW_HOME`, `OPENCLAW_STATE_DIR`, `OPENCLAW_PROFILE`, and
`OPENCLAW_WORKSPACE_DIR` select the layout. Named profiles do not inherit the
default personal `.agents/skills` root. The legacy `.clawdbot` state fallback is
retained when neither an explicit state nor a named profile is selected.

Wrapper overrides: `OPENCLAW_SKILLS_DIR`, `OPENCLAW_QUARANTINE_DIR`,
`OPENCLAW_STAGE_DIR`, `SKILL_SCANNER_DIR`, `SKILL_SCANNER_REPORT_DIR`,
`OPENCLAW_BUNDLED_SKILLS_DIR`, and `OPENCLAW_BIN` (one executable, not a shell
command). Per-agent configuration is resolved through explicit catalog mode,
not by guessing or evaluating OpenClaw configuration files.

Reports default to `<workspace>/skill_scans`; managed installs to
`<state>/skills`; quarantine to `<state>/skills-quarantine`.

## Optional systemd watcher

The units in `references/` are templates for the default Linux user layout.
Review the `ExecStart` and watched paths before enabling them, especially with
a profile, custom workspace, or renamed installation directory. Environment
variables are not expanded inside systemd path directives. A path unit is not
a recursive watcher and does not guarantee interception before a skill loads.

`auto_scan_user_skills.sh` scans grouped managed skills individually and
quarantines High/Critical results outside the managed skill tree. It never
accepts quarantine paths from report text. Failed scans and malformed reports
return nonzero without declaring skills safe. Cross-filesystem quarantine is
refused rather than performed as a non-atomic copy/delete.

See `COMPATIBILITY.md` for the upstream reference and test scope.
