#!/usr/bin/env python3
"""Fail when a change to main ships plugin files without a new version.

Claude Code detects a plugin update by its version, so a change that reaches main under a version
consumers already have never reaches them. If any changed file is outside REPO_ONLY, the
plugin.json version in HEAD must be higher than in the base.

CI runs it for pull requests into main and for pushes to main. Pull requests into a staging
branch skip it, so several changes can share one version that ships when staging merges to main.

Run from the repo root: python3 .github/scripts/check-version-bump.py <base-ref> [<head-ref>]
Before a pull request or a direct push, pass origin/main as the base.
"""

import json
import re
import subprocess
import sys

PLUGIN_JSON = '.claude-plugin/plugin.json'

# Paths the plugin never loads. A change limited to these needs no release.
REPO_ONLY = re.compile(
    r'^(\.github/|\.claude/|skills/[^/]+/evals/'
    r'|\.gitignore$|CHANGELOG\.md$|CLAUDE\.md$|README\.md$)'
)


def git(*args):
    return subprocess.run(['git', *args], check=True, capture_output=True, text=True).stdout


def version_at(ref):
    version = json.loads(git('show', f'{ref}:{PLUGIN_JSON}'))['version']
    return tuple(int(part) for part in version.split('.')), version


def main():
    base = sys.argv[1]
    head = sys.argv[2] if len(sys.argv) > 2 else 'HEAD'

    # Without --no-renames, a file moved out of a shipped path lists only its new path.
    changed = git('diff', '--no-renames', '--name-only', f'{base}...{head}').splitlines()
    shipped = [path for path in changed if not REPO_ONLY.match(path)]
    if not shipped:
        print('Only repo-only files changed. No new version needed.')
        return

    (base_key, base_version), (head_key, head_version) = version_at(base), version_at(head)
    if head_key <= base_key:
        print('These files ship to consumers:')
        for path in shipped:
            print(f'  {path}')
        sys.exit(
            f'ERROR: {PLUGIN_JSON} version is {head_version}, but {base} is already at '
            f'{base_version}. Consumers only get a change under a new version. '
            f'Bump it above {base_version}.'
        )
    print(f'Ships version {head_version} (was {base_version}).')


if __name__ == '__main__':
    main()
