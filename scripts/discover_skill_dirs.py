#!/usr/bin/env python3
"""Discover local SKILL.md directories without importing repository code.

--catalog explicitly invokes a trusted OpenClaw CLI to include configured
per-agent, extra, plugin and bundled sources. Default discovery is filesystem-only.
"""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


def cli_json(command: list[str]) -> dict:
    result = subprocess.run(command, capture_output=True, text=True, timeout=30)
    if result.returncode:
        raise ValueError('OpenClaw catalog command failed; no complete inventory is available')
    data = json.loads(result.stdout)
    if not isinstance(data, dict) or data.get('ok') is False:
        raise ValueError('Invalid OpenClaw catalog response')
    return data


def bundled_root() -> Path | None:
    override = os.environ.get('OPENCLAW_BUNDLED_SKILLS_DIR')
    if override:
        path = Path(override).expanduser().resolve()
        if not path.is_dir():
            raise ValueError('OPENCLAW_BUNDLED_SKILLS_DIR is not a directory')
        return path
    binary = shutil.which(os.environ.get('OPENCLAW_BIN', 'openclaw'))
    if binary:
        for parent in list(Path(binary).resolve().parents)[:8]:
            manifest = parent / 'package.json'
            try:
                package = json.loads(manifest.read_text(encoding='utf-8'))
            except (OSError, ValueError):
                continue
            if isinstance(package, dict) and package.get('name') == 'openclaw':
                skills = parent / 'skills'
                return skills if skills.is_dir() else None
    return None


def discover_root(root: Path, depth: int = 0) -> list[Path]:
    if not root.exists():
        return []
    if not root.is_dir():
        raise ValueError(f'Skill root is not a directory: {root}')
    if root.is_symlink():
        raise ValueError(f'Symlink skill directory requires explicit review: {root}')
    manifest = root / 'SKILL.md'
    if manifest.is_symlink():
        raise ValueError(f'Symlink skill manifest requires explicit review: {manifest}')
    if manifest.is_file():
        return [root.resolve()]
    if depth >= 6:
        return []
    result: list[Path] = []
    for child in sorted(root.iterdir()):
        if child.is_dir():
            result.extend(discover_root(child, depth + 1))
    return result


def collect(args: argparse.Namespace) -> list[Path]:
    if args.only_roots:
        if not args.roots or args.catalog or args.agent:
            raise ValueError('--only-roots requires roots and cannot use --catalog/--agent')
        paths: list[Path] = []
        for root in args.roots:
            path = Path(root).expanduser().absolute()
            if not path.is_dir():
                raise ValueError(f'Explicit skill root does not exist: {root}')
            paths.extend(discover_root(path))
        return list(dict.fromkeys(paths))
    state = Path(os.environ['STATE_DIR'])
    workspace = Path(os.environ['WORKSPACE_DIR'])
    home = Path(os.environ['OC_HOME'])
    roots = [Path(os.environ['USER_SKILLS']), workspace / 'skills', workspace / '.agents/skills']
    if state.resolve() == (home / '.openclaw').resolve() and os.environ['OC_PROFILE'] == 'default':
        roots.append(home / '.agents/skills')
    agents = state / 'agents'
    if agents.is_dir():
        roots.extend(agent / 'agent/workshop-skills' for agent in sorted(agents.iterdir()) if agent.is_dir())
    bundled = bundled_root()
    if bundled:
        roots.append(bundled)
    elif not args.catalog:
        print('Bundled skills not located; set OPENCLAW_BUNDLED_SKILLS_DIR or use --catalog.', file=sys.stderr)
    roots.extend(Path(root).expanduser().absolute() for root in args.roots)
    for root in args.roots:
        if not Path(root).expanduser().is_dir():
            raise ValueError(f'Explicit skill root does not exist: {root}')
    paths: list[Path] = []
    if args.catalog:
        executable = shutil.which(os.environ.get('OPENCLAW_BIN', 'openclaw'))
        if not executable:
            raise ValueError('OpenClaw CLI not found for --catalog')
        command = [executable]
        profile = os.environ['OC_PROFILE']
        if profile != 'default':
            command += ['--profile', profile]
        command += ['skills']
        if args.agent:
            command += ['--agent', args.agent]
        catalog = cli_json(command + ['list', '--json'])
        if not isinstance(catalog.get('skills'), list):
            raise ValueError('OpenClaw catalog is missing the skills array')
        for field in ('workspaceDir', 'managedSkillsDir'):
            if not isinstance(catalog.get(field), str) or not Path(catalog[field]).is_absolute():
                raise ValueError(f'OpenClaw catalog has no absolute {field}')
        roots += [Path(catalog['managedSkillsDir']), Path(catalog['workspaceDir']) / 'skills', Path(catalog['workspaceDir']) / '.agents/skills']
        for entry in catalog['skills']:
            name = entry.get('name') if isinstance(entry, dict) else None
            if not isinstance(name, str) or not name:
                raise ValueError('Invalid skill name in OpenClaw catalog')
            # List JSON deliberately omits paths; info JSON contains filePath.
            info = cli_json(command + ['info', '--json', '--', name])
            filename = info.get('filePath')
            if not isinstance(filename, str) or not Path(filename).is_absolute():
                raise ValueError(f'Skill has no local absolute manifest path: {name}')
            manifest = Path(filename)
            if manifest.name != 'SKILL.md' or not manifest.is_file() or manifest.is_symlink():
                raise ValueError(f'Skill manifest is unavailable locally: {name}')
            paths.extend(discover_root(manifest.parent))
    elif args.agent:
        raise ValueError('--agent requires --catalog')
    for root in dict.fromkeys(roots):
        paths.extend(discover_root(root))
    return list(dict.fromkeys(paths))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--catalog', action='store_true')
    parser.add_argument('--only-roots', action='store_true', help='Scan only explicit local roots')
    parser.add_argument('--agent')
    parser.add_argument('roots', nargs='*')
    args = parser.parse_args()
    try:
        paths = collect(args)
    except (OSError, ValueError, KeyError, subprocess.TimeoutExpired) as exc:
        print(f'ERROR: skill discovery incomplete: {exc}', file=sys.stderr)
        return 2
    # NUL framing preserves spaces and newlines without evaluating path text.
    for path in paths:
        sys.stdout.buffer.write(os.fsencode(path) + b'\0')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
