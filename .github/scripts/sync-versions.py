#!/usr/bin/env python3
"""Keep each plugin's version and description the same in every manifest that states them.

For each plugins/<name>/ folder, reads these files when present:

- plugins/<name>/.claude-plugin/plugin.json: version and description
- plugins/<name>/plugin.json: version and description
- the entry for <name> in each marketplace file: description

Each marketplace must also list every plugin, with the source ./plugins/<name>.

Usage, from the repo root:
  python3 .github/scripts/sync-versions.py              exit 1 if any value differs
  python3 .github/scripts/sync-versions.py xh 1.8.0     write 1.8.0 to every xh plugin manifest
"""

import json
import re
import sys
from pathlib import Path

PLUGIN_MANIFESTS = ['.claude-plugin/plugin.json', 'plugin.json']
MARKETPLACES = [
    '.claude-plugin/marketplace.json',
    '.cursor-plugin/marketplace.json',
    '.agents/plugins/marketplace.json',
]
VERSION = re.compile(r'"version"\s*:\s*"[^"]*"')


def plugin_names():
    return sorted(p.name for p in Path('plugins').iterdir() if p.is_dir())


def manifests(name):
    """Yield (path, data) for each plugin manifest of the plugin."""
    for rel in PLUGIN_MANIFESTS:
        path = Path('plugins', name, rel)
        if path.is_file():
            yield path, json.loads(path.read_text())


def marketplace_entries(name):
    """Yield (path, entry) for each marketplace entry of the plugin."""
    for rel in MARKETPLACES:
        path = Path(rel)
        if path.is_file():
            for entry in json.loads(path.read_text()).get('plugins', []):
                if entry.get('name') == name:
                    yield path, entry


def source_path(entry):
    source = entry.get('source')
    return source.get('path') if isinstance(source, dict) else source


def mismatch(name, field, found):
    if len(set(found.values())) <= 1 and None not in found.values():
        return False
    print(f'{name}: {field} differs')
    for path, value in found.items():
        print(f'  {value!r}  {path}')
    return True


def check():
    failed = False
    for name in plugin_names():
        plugins = list(manifests(name))
        versions = {str(p): d.get('version') for p, d in plugins}
        descriptions = {str(p): d.get('description') for p, d in plugins}
        entries = list(marketplace_entries(name))
        descriptions.update({str(p): e.get('description') for p, e in entries})
        for rel in sorted(set(MARKETPLACES) - {str(p) for p, _ in entries}):
            if Path(rel).is_file():
                failed = True
                print(f'{name}: missing from {rel}')
        for path, entry in entries:
            if source_path(entry) != f'./plugins/{name}':
                failed = True
                print(f'{name}: source {source_path(entry)!r} is not ./plugins/{name} in {path}')
        failed |= mismatch(name, 'version', versions)
        failed |= mismatch(name, 'description', descriptions)
    if failed:
        sys.exit('Fix other fields by hand. For versions, run: '
                 'python3 .github/scripts/sync-versions.py <plugin> <version>')
    print('Manifests and marketplaces agree.')


def write(name, version):
    if name not in plugin_names():
        sys.exit(f'No plugin named {name} under plugins/.')
    for path, _ in manifests(name):
        # Replace the string in place to keep the file's formatting.
        path.write_text(VERSION.sub(f'"version": "{version}"', path.read_text(), count=1))
        print(f'{version}  {path}')


def main():
    if not Path('plugins').is_dir():
        sys.exit('Run from the repo root: plugins/ not found.')
    if len(sys.argv) == 1:
        check()
    elif len(sys.argv) == 3:
        write(sys.argv[1], sys.argv[2])
    else:
        sys.exit(__doc__)


if __name__ == '__main__':
    main()
