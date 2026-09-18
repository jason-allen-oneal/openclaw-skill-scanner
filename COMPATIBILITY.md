# OpenClaw compatibility

Reviewed against `openclaw/openclaw` main at
`31157a19b41dae0ec28a4010d08656d11f55c067` (2026-09-17 America/New_York).
This is a source/API compatibility review, not a live Gateway certification.

Upstream references at that exact revision:

- `docs/tools/skills.md`: workspace, project/personal .agents, managed,
  workshop, bundled and extra/plugin sources; grouped discovery depth six;
  named-state personal-root isolation.
- `src/cli/skills-cli.format.ts`: list JSON omits file paths, info JSON returns
  the complete status entry, including filePath.
- `src/agents/workspace-default-path.ts`, `src/config/state-dir.ts`, and
  `src/cli/profile-utils.ts`: state/home/workspace/profile paths.

The scanner still requires a reviewed Cisco skill-scanner checkout and its
Markdown severity summaries. An unsupported report format fails closed for
installation and automatic quarantine. Offline tests use synthetic local
fixtures and mocked uv, npx, and OpenClaw executables. They do not download or
execute candidate skills or assume any existing OpenClaw clone is clean.

The install wrappers preserve the earlier fail-closed and namespaced-slug fixes.
Relative source paths are resolved before changing to the scanner directory;
report filenames are unique; existing or dangling-symlink destinations are not
replaced. `--force` is not an override for failed or unreadable scans.

Limits: filesystem discovery is not the entire configured/remote catalog;
`--catalog` is explicit and local-only. No before-load interception, complete
private-library coverage, recursive systemd watch, concurrent-mutation safety,
or Windows-native Bash compatibility is claimed. Scanner reports must be
reviewed; a successful scan is not proof that code is safe.

The Cisco MarkdownReporter summary contract was also reviewed at blob
`50255ff4fc6eeee13b29d46f4a7e1fbd619a4954`
(`skill_scanner/core/reporters/markdown_reporter.py`): single and bulk reports
emit explicit counts for all five severities. Tests use that summary shape;
no live scanner installation was run.

Before pushing, main was rechecked at
`57034eb5e70b33bcf1e11ba782693d0d0889bb83`. The intervening seven commits
were compared; none changes the reviewed path, skills CLI, or health contracts.
