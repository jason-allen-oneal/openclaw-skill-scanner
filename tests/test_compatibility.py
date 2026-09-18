"""Offline compatibility tests. All CLI processes are test doubles."""
from pathlib import Path
import json
import os
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
CLEAN = '\n'.join(f'- **{s}:** 0' for s in ('Critical', 'High', 'Medium', 'Low', 'Info'))


class CompatibilityTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.bin = self.home / 'bin'
        self.bin.mkdir()
        self.env = {k: v for k, v in os.environ.items() if not k.startswith(('OPENCLAW_', 'SKILL_SCANNER_', 'FAKE_', 'OC_'))}
        self.env.update(HOME=str(self.home), PATH=f'{self.bin}:{os.environ["PATH"]}', FAKE_SCAN_REPORT=CLEAN)
        self.state = self.home / '.openclaw'
        self.workspace = self.state / 'workspace'
        (self.workspace / 'skill-scanner').mkdir(parents=True)
        self.executable('uv', '''#!/usr/bin/env python3
import os, sys
from pathlib import Path
args = sys.argv[1:]
target = Path(args[args.index('scan') + 1])
if not target.is_dir(): raise SystemExit(8)
Path(args[args.index('--output') + 1]).write_text(os.environ.get('FAKE_SCAN_REPORT', ''))
raise SystemExit(int(os.environ.get('FAKE_SCAN_EXIT', '0')))
''')

    def executable(self, name, content):
        path = self.bin / name
        path.write_text(content)
        path.chmod(0o755)
        return path

    def skill(self, relative):
        path = self.home / relative
        path.mkdir(parents=True, exist_ok=True)
        (path / 'SKILL.md').write_text('---\nname: example\n---\nLocal fixture.\n')
        return path

    def script(self, name, *args):
        return subprocess.run(['bash', str(ROOT / 'scripts' / name), *map(str, args)], cwd=self.home, env=self.env, capture_output=True, text=True, timeout=15)

    def paths(self):
        command = 'source "$1"; printf "%s\\n" "$STATE_DIR" "$WORKSPACE_DIR" "$USER_SKILLS"'
        result = subprocess.run(['bash', '-euc', command, '_', str(ROOT / 'scripts/openclaw_paths.sh')], cwd=self.home, env=self.env, capture_output=True, text=True)
        return result

    def discover(self, *args):
        command = 'source "$1"; shift; exec python3 "$@"'
        return subprocess.run(['bash', '-euc', command, '_', str(ROOT / 'scripts/openclaw_paths.sh'), str(ROOT / 'scripts/discover_skill_dirs.py'), *map(str, args)], cwd=self.home, env=self.env, capture_output=True, timeout=15)

    def test_default_paths(self):
        self.assertEqual(self.paths().stdout.splitlines(), list(map(str, [self.state, self.workspace, self.state / 'skills'])))

    def test_home_profile_paths(self):
        self.env.update(OPENCLAW_HOME=str(self.home / 'alternate'), OPENCLAW_PROFILE='review')
        state = self.home / 'alternate/.openclaw-review'
        self.assertEqual(self.paths().stdout.splitlines(), list(map(str, [state, state / 'workspace', state / 'skills'])))

    def test_explicit_state_and_workspace(self):
        self.env.update(OPENCLAW_STATE_DIR='state with spaces', OPENCLAW_WORKSPACE_DIR='workspace', OPENCLAW_PROFILE='review')
        self.assertEqual(self.paths().stdout.splitlines(), list(map(str, [self.home / 'state with spaces', self.home / 'workspace', self.home / 'state with spaces/skills'])))

    def test_invalid_profile(self):
        self.env['OPENCLAW_PROFILE'] = '../other'
        self.assertNotEqual(self.paths().returncode, 0)

    def test_relative_candidate_survives_scanner_cwd(self):
        self.skill('candidate')
        result = self.script('scan_and_add_skill.sh', 'candidate')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.state / 'skills/candidate/SKILL.md').is_file())

    def test_force_cannot_bypass_scanner_failure(self):
        candidate = self.skill('candidate')
        self.env['FAKE_SCAN_EXIT'] = '9'
        self.assertNotEqual(self.script('scan_and_add_skill.sh', candidate, '--force').returncode, 0)
        self.assertFalse((self.state / 'skills/candidate').exists())

    def test_force_cannot_bypass_unknown_report(self):
        self.env['FAKE_SCAN_REPORT'] = 'Looks clean. All clear.'
        self.assertNotEqual(self.script('scan_and_add_skill.sh', self.skill('candidate'), '--force').returncode, 0)

    def test_duplicate_summary_fails_closed(self):
        self.env['FAKE_SCAN_REPORT'] = CLEAN + '\n- **High:** 1'
        self.assertNotEqual(self.script('scan_and_add_skill.sh', self.skill('candidate')).returncode, 0)

    def test_dangling_destination_is_not_overwritten(self):
        (self.state / 'skills').mkdir()
        (self.state / 'skills/candidate').symlink_to(self.home / 'missing')
        result = self.script('scan_and_add_skill.sh', self.skill('candidate'))
        self.assertEqual(result.returncode, 3)
        self.assertTrue((self.state / 'skills/candidate').is_symlink())

    def test_clawhub_uses_sibling_gate(self):
        self.executable('npx', '''#!/usr/bin/env python3
import sys
from pathlib import Path
args = sys.argv[1:]
root = Path(args[args.index('--workdir') + 1]) / 'skills/publisher/example'
root.mkdir(parents=True)
(root / 'SKILL.md').write_text('fixture')
''')
        result = self.script('clawhub_scan_install.sh', 'publisher/example')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.state / 'skills/example/SKILL.md').is_file())
        self.assertFalse((self.state / 'skills/skill-scanner-guard').exists())

    def test_tag_is_rejected(self):
        self.assertEqual(self.script('clawhub_scan_install.sh', 'example', '--tag', 'latest').returncode, 2)

    def test_grouped_sources(self):
        names = ['.openclaw/skills/group/managed', '.openclaw/workspace/skills/workspace', '.openclaw/workspace/.agents/skills/project', '.agents/skills/personal', '.openclaw/agents/main/agent/workshop-skills/learned']
        expected = {str(self.skill(name)) for name in names}
        result = self.discover()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(set(result.stdout.decode().strip('\0').split('\0')), expected)

    def test_named_state_excludes_personal(self):
        self.skill('.agents/skills/personal')
        candidate = self.skill('isolated/skills/managed')
        self.env['OPENCLAW_STATE_DIR'] = str(self.home / 'isolated')
        result = self.discover()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, os.fsencode(candidate) + b'\0')

    def test_only_roots_stops_at_manifest(self):
        parent = self.skill('extra/parent')
        self.skill('extra/parent/nested')
        self.skill('.openclaw/skills/unrelated')
        result = self.discover('--only-roots', self.home / 'extra')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, os.fsencode(parent) + b'\0')

    def test_symlink_inventory_fails(self):
        target = self.skill('elsewhere')
        (self.state / 'skills').mkdir()
        (self.state / 'skills/link').symlink_to(target, target_is_directory=True)
        self.assertEqual(self.discover().returncode, 2)

    def test_bundled_discovery_without_executing_openclaw(self):
        package = self.home / 'npm/openclaw'
        package.mkdir(parents=True)
        (package / 'package.json').write_text('{"name":"openclaw"}')
        cli = package / 'openclaw.mjs'
        cli.write_text('#!/bin/sh\nexit 99\n')
        cli.chmod(0o755)
        (self.bin / 'openclaw').symlink_to(cli)
        skill = self.skill('npm/openclaw/skills/bundled')
        result = self.discover()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, os.fsencode(skill) + b'\0')

    def test_catalog_uses_info_paths(self):
        skill = self.skill('plugin/skill')
        self.env['FIXTURE_PATH'] = str(skill / 'SKILL.md')
        self.executable('openclaw', '''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
args = sys.argv[1:]
if 'list' in args:
 print(json.dumps({'workspaceDir':str(Path.home()/'configured'), 'managedSkillsDir':str(Path.home()/'.openclaw/skills'), 'skills':[{'name':'example'}]}))
else:
 assert args[-2:] == ['--', 'example']
 print(json.dumps({'filePath':os.environ['FIXTURE_PATH']}))
''')
        result = self.discover('--catalog', '--agent', 'main')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, os.fsencode(skill) + b'\0')

    def test_catalog_error_is_not_an_empty_success(self):
        self.executable('openclaw', '#!/bin/sh\nprintf "{}"\n')
        self.assertEqual(self.discover('--catalog').returncode, 2)

    def test_scan_failure_propagates(self):
        self.skill('.openclaw/skills/example')
        self.env['FAKE_SCAN_EXIT'] = '7'
        self.assertEqual(self.script('scan_openclaw_skills.sh').returncode, 1)

    def test_auto_unknown_report_does_not_claim_clean(self):
        skill = self.skill('.openclaw/skills/example')
        self.env['FAKE_SCAN_REPORT'] = 'All clear'
        result = self.script('auto_scan_user_skills.sh')
        self.assertEqual(result.returncode, 1)
        self.assertTrue(skill.exists())
        self.assertNotIn('critical=0', result.stdout)

    def test_auto_quarantines_scanned_grouped_path_only(self):
        skill = self.skill('.openclaw/skills/group/example')
        unrelated = self.skill('unrelated')
        self.env['FAKE_SCAN_REPORT'] = CLEAN.replace('High:** 0', 'High:** 1') + f'\n- **Directory:** {unrelated}'
        result = self.script('auto_scan_user_skills.sh')
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertFalse(skill.exists())
        self.assertTrue(unrelated.exists())
        self.assertEqual(len(list((self.state / 'skills-quarantine').glob('example-*'))), 1)


if __name__ == '__main__':
    unittest.main()
