#!/usr/bin/env python3
"""Fail when a skill, plugin manifest, or marketplace file breaks a harness's schema.

Checks, from the repo root:

- plugins/*/skills/*/SKILL.md: `name` matches the folder, and `description` is at most 1024
  characters, which Codex enforces.
- plugins/*/plugin.json: the Agent Plugins schema, which allows no other fields. `author` takes
  only `name` and `email`, because Cursor's manifest allows no more.
- plugins/*/.claude-plugin/plugin.json: a kebab-case `name`.
- .claude-plugin/, .cursor-plugin/, and .agents/plugins/ marketplace.json: required fields, the
  fields Cursor documents, and the Codex policy values. Codex rejects its whole marketplace file
  over one bad value.

Usage:
  python3 .github/scripts/check-schemas.py
"""

import json
import re
import sys
from pathlib import Path

MAX_DESCRIPTION = 1024
KEBAB = re.compile(r'^[a-z0-9]+([.-][a-z0-9]+)*$')
AUTHOR = {'name', 'email'}
AGENT_PLUGIN = {'$schema', 'name', 'version', 'description', 'author', 'homepage', 'repository',
                'license', 'keywords', 'extensions'}
CURSOR_MARKETPLACE = {'name', 'owner', 'plugins', 'metadata'}
CURSOR_ENTRY = {'name', 'source', 'description', 'version', 'author', 'homepage', 'repository',
                'license', 'keywords', 'logo', 'category', 'tags', 'skills', 'rules', 'agents',
                'commands', 'hooks', 'mcpServers', 'variables'}
CODEX_MARKETPLACE = {'name', 'interface', 'plugins'}
CODEX_ENTRY_REQUIRED = {'name', 'source', 'policy', 'category'}
CODEX_POLICY = {
    'installation': {'AVAILABLE', 'INSTALLED_BY_DEFAULT', 'NOT_AVAILABLE'},
    'authentication': {'ON_INSTALL', 'ON_USE'},
}

problems = []


def report(path, message):
    problems.append(f'{path}: {message}')


def check_fields(path, label, data, allowed=None, required=()):
    for key in sorted(set(required) - set(data)):
        report(path, f'{label} is missing {key!r}')
    if allowed is not None:
        for key in sorted(set(data) - allowed):
            report(path, f'{label} has {key!r}, which the schema does not allow')


def check_name(path, label, name):
    if not isinstance(name, str) or not KEBAB.match(name):
        report(path, f'{label} name {name!r} is not kebab-case')


def frontmatter(path):
    """Return the top-level frontmatter keys as strings. Handles plain and `|` / `>` values."""
    match = re.match(r'---\n(.*?)\n---\n', path.read_text(), re.S)
    if not match:
        return {}
    fields, key = {}, None
    for line in match.group(1).splitlines():
        top = re.match(r'([\w-]+):\s*(.*)', line)
        if top and not line.startswith(' '):
            key, value = top.groups()
            fields[key] = '' if value in ('|', '>', '|-', '>-') else value
        elif key:
            fields[key] = f'{fields[key]} {line.strip()}'.strip()
    return fields


def check_skill(path):
    fields = frontmatter(path)
    if fields.get('name') != path.parent.name:
        report(path, f'name {fields.get("name")!r} does not match folder {path.parent.name!r}')
    length = len(fields.get('description', ''))
    if not length or length > MAX_DESCRIPTION:
        report(path, f'description is {length} characters, limit {MAX_DESCRIPTION}')


def check_agent_plugin(path, data):
    check_fields(path, 'manifest', data, AGENT_PLUGIN, {'$schema', 'name'})
    check_name(path, 'plugin', data.get('name'))
    check_fields(path, 'author', data.get('author', {}), AUTHOR, {'name'})
    for key in ('version', 'description', 'homepage', 'repository', 'license'):
        if key in data and not isinstance(data[key], str):
            report(path, f'{key} is not a string')
    keywords = data.get('keywords', [])
    if not isinstance(keywords, list) or not all(isinstance(k, str) for k in keywords):
        report(path, 'keywords is not a list of strings')


def check_marketplace(path, data):
    check_fields(path, 'marketplace', data, required={'name', 'plugins'})
    check_name(path, 'marketplace', data.get('name'))
    cursor, codex = path.parts[0] == '.cursor-plugin', path.parts[0] == '.agents'
    if codex:
        check_fields(path, 'marketplace', data, CODEX_MARKETPLACE)
    else:
        check_fields(path, 'owner', data.get('owner', {}), AUTHOR, {'name'})
        if cursor:
            check_fields(path, 'marketplace', data, CURSOR_MARKETPLACE, {'owner'})
    for entry in data.get('plugins', []):
        label = f'entry {entry.get("name")!r}'
        check_fields(path, label, entry, CURSOR_ENTRY if cursor else None,
                     CODEX_ENTRY_REQUIRED if codex else {'name', 'source'})
        check_name(path, label, entry.get('name'))
        if codex:
            for key, allowed in CODEX_POLICY.items():
                value = entry.get('policy', {}).get(key)
                if value not in allowed:
                    report(path, f'{label} policy.{key} {value!r} is not one of {sorted(allowed)}')


def main():
    if not Path('plugins').is_dir():
        sys.exit('Run from the repo root: plugins/ not found.')
    for path in sorted(Path('plugins').glob('*/skills/*/SKILL.md')):
        check_skill(path)
    for path in sorted(Path('plugins').glob('*/plugin.json')):
        check_agent_plugin(path, json.loads(path.read_text()))
    for path in sorted(Path('plugins').glob('*/.claude-plugin/plugin.json')):
        check_name(path, 'plugin', json.loads(path.read_text()).get('name'))
    for rel in ('.claude-plugin/marketplace.json', '.cursor-plugin/marketplace.json',
                '.agents/plugins/marketplace.json'):
        if Path(rel).is_file():
            check_marketplace(Path(rel), json.loads(Path(rel).read_text()))
    if problems:
        sys.exit('\n'.join(problems))
    print('Skills, manifests, and marketplaces match their schemas.')


if __name__ == '__main__':
    main()
