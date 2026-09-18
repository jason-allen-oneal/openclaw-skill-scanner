# OpenClaw Skill Scanner

Pre-install scanning and local skill inventory using a separately reviewed
`cisco-ai-defense/skill-scanner` installation. A scan is evidence, not proof that
a skill, scanner checkout, or OpenClaw installation is trustworthy.

## Usage

From this repository or the installed skill directory:

```bash
./scripts/scan_and_add_skill.sh /absolute/path/to/candidate
./scripts/clawhub_scan_install.sh publisher/skill --version 1.0.0
./scripts/scan_openclaw_skills.sh
# Optional: execute your trusted OpenClaw CLI to resolve configured sources.
./scripts/scan_openclaw_skills.sh --catalog --agent main
```

Review the scanner checkout before installing its dependencies or executing it.
Set `SKILL_SCANNER_DIR` to that checkout; by default it is
`<workspace>/skill-scanner`. The Bash wrappers require `bash`, `python3`, and
`uv`; ClawHub staging also requires `npx`.

State, home, profile, workspace, grouped discovery, environment overrides,
installation examples, and coverage limits are documented in [SKILL.md](SKILL.md).
[COMPATIBILITY.md](COMPATIBILITY.md) records the exact upstream source baseline.

## Policy

High/Critical findings block installation unless the local scanner wrapper's
explicit `--force` override is used. Medium/Low/Info findings warn. Scanner
errors, missing reports, and ambiguous severity summaries always block, even
with `--force`. Existing destinations are never overwritten.

These wrappers do not intercept native OpenClaw installs, updates, personal
library operations, or workshop approvals. Managed-tree auto-quarantine moves
only the path that was actually scanned. It does not unload already captured
session instructions or guarantee prevention of execution.

The `references/` systemd units are **templates**, not a recursive file watcher
or a pre-load security boundary. Review both paths and service environment
before enabling them. The service example uses the repository skill name;
ClawHub installations named `skill-scanner-guard` need an adjusted ExecStart.

## Offline tests

```bash
python3 -m unittest discover -s tests -p 'test_*.py' -v
bash tests/test_fail_open.sh
bash tests/test_dest_name.sh
bash tests/test_namespaced_slug.sh
```

Tests use isolated fixtures and mock CLIs, not live OpenClaw, ClawHub, or scanner
services. The existing ClawHub listing is `jason-allen-oneal/skill-scanner-guard`;
this compatibility change does not publish a new ClawHub version.
