# OpenClaw Skill Scanner

A security gate for OpenClaw AgentSkills powered by the `cisco-ai-defense/skill-scanner` engine.

## Overview
This skill provides a robust mechanism to scan, validate, and manage the security of OpenClaw skills. It enforces a strict policy: blocking installations with **High** or **Critical** severity findings while allowing others with explicit warnings.

## Features
- **Pre-install Scanning**: Scan local folders or ClawHub skills before they are added to your environment.
- **Automated Monitoring**: Systemd user units to automatically scan `~/.openclaw/skills` on every change.
- **Auto-Quarantine**: Automatically moves high-risk skills to `~/.openclaw/skills-quarantine` to prevent execution.
- **Detailed Reporting**: Generates Markdown risk reports for every scan.

## Quick Start

### 1. Install the Scanner Engine
```bash
cd "$HOME/.openclaw/workspace"
git clone https://github.com/cisco-ai-defense/skill-scanner
cd skill-scanner
CC=gcc uv sync --all-extras
```

### 2. Manual Scan & Install
```bash
# Scan a folder and install if safe
./scripts/scan_and_add_skill.sh /path/to/skill-dir

# Install from ClawHub with a scan gate
./scripts/clawhub_scan_install.sh <slug>
```

### 3. Enable Auto-Scan
```bash
mkdir -p ~/.config/systemd/user
cp -a references/openclaw-skill-scan.* ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now openclaw-skill-scan.path
```

## Security Policy
- **Critical/High**: Installation blocked; skill quarantined (if auto-scan is enabled).
- **Medium/Low/Info**: Installation allowed with a warning summary.

## Links
- **ClawHub**: [skill-scanner-guard](https://clawhub.ai/jason-allen-oneal/skill-scanner-guard)
- **Source**: [jason-allen-oneal/openclaw-skill-scanner](https://github.com/jason-allen-oneal/openclaw-skill-scanner)
