#!/usr/bin/env python3
"""Fail when a change to main ships plugin files without a new version.

Claude Code detects a plugin update by its version, so a change that reaches main under a version
consumers already have never reaches them. This check compares HEAD with a base commit:

- If every changed file is repo-only (see REPO_ONLY), it passes.
- Otherwise the plugin.json version in HEAD must be higher than in the base.
- The top CHANGELOG.md heading must name that version with a date: "## 1.2.0 - 2026-01-31".

CI runs it for pull requests into main, with main as the base, and for pushes to main, with the
previous tip as the base. Pull requests into a staging branch skip it, so several changes can
share one version that ships when staging merges to main.

Run from the repo root: python3 .github/scripts/check-version-bump.py <base-ref> [<head-ref>]
Before you open a pull request, pass origin/main as the base.
"""

import json
import re
import subprocess
import sys

PLUGIN_JSON = '.claude-plugin/plugin.json'
CHANGELOG = 'CHANGELOG.md'

# Paths the plugin never loads. A change limited to these needs no release.
REPO_ONLY = [
    re.compile(r'^\.github/'),
    re.compile(r'^\.claude/'),
    re.compile(r'^\.gitignore$'),
    re.compile(r'^CHANGELOG\.md$'),
    re.compile(r'^CLAUDE\.md$'),
    re.compile(r'^README\.md$'),
    re.compile(r'^skills/[^/]+/evals/'),
]


def git(*args):
    result = subprocess.run(['git', *args], capture_output=True, text=True)
    if result.returncode:
        sys.exit(
            f'git {" ".join(args)} failed:\n{result.stderr.strip()}\n'
            'The base commit may be missing, for example after a force push. '
            'Run the check locally against origin/main.'
        )
    return result.stdout


def version_at(ref):
    return json.loads(git('show', f'{ref}:{PLUGIN_JSON}'))['version']


def parse(version):
    match = re.fullmatch(r'(\d+)\.(\d+)\.(\d+)', version)
    if not match:
        sys.exit(f'{PLUGIN_JSON} version "{version}" is not in X.Y.Z form.')
    return tuple(int(part) for part in match.groups())


def main():
    if len(sys.argv) not in (2, 3):
        sys.exit(__doc__)
    base = sys.argv[1]
    head = sys.argv[2] if len(sys.argv) == 3 else 'HEAD'
    if not base.strip('0'):
        sys.exit(f'No base commit to compare with: "{base}".')

    # Without --no-renames, a file moved out of a shipped path lists only its new path.
    changed = git('diff', '--no-renames', '--name-only', f'{base}...{head}').splitlines()
    shipped = [path for path in changed if not any(p.search(path) for p in REPO_ONLY)]
    if not shipped:
        print('Only repo-only files changed. No new version needed.')
        return

    base_version, head_version = version_at(base), version_at(head)
    errors = []
    if parse(head_version) <= parse(base_version):
        errors.append(
            f'{PLUGIN_JSON} version is {head_version}, but {base} is already at {base_version}. '
            f'Consumers only get a change under a new version. Bump it above {base_version}.'
        )

    changelog = git('show', f'{head}:{CHANGELOG}').splitlines()
    heading = next((line for line in changelog if line.startswith('## ')), '(none)')
    if heading == f'## {head_version} - unreleased':
        errors.append(
            f'The top {CHANGELOG} heading is "{heading}". This is expected during review. '
            'Replace "unreleased" with the date just before you merge.'
        )
    elif not re.fullmatch(rf'## {re.escape(head_version)} - \d{{4}}-\d{{2}}-\d{{2}}', heading):
        errors.append(
            f'The top {CHANGELOG} heading is "{heading}". '
            f'Expected "## {head_version} - YYYY-MM-DD", dated for the release.'
        )

    if errors:
        print('These files ship to consumers:')
        for path in shipped:
            print(f'  {path}')
        for error in errors:
            print(f'ERROR: {error}')
        sys.exit(1)
    print(f'Ships version {head_version} (was {base_version}).')


if __name__ == '__main__':
    main()
