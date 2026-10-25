#!/usr/bin/env python3
"""Keep the version of each plugin the same in every manifest that states it.

For each plugins/<name>/ folder, reads the version from these files when present:

- plugins/<name>/.claude-plugin/plugin.json
- plugins/<name>/plugin.json
- the entry for <name> in each marketplace file at the repo root, if the entry has a version

Usage, from the repo root:
  python3 .github/scripts/sync-versions.py              exit 1 if any versions differ
  python3 .github/scripts/sync-versions.py xh 1.8.0     write 1.8.0 to every xh manifest
"""

import json
import re
import sys
from pathlib import Path

PLUGIN_MANIFESTS = ['.claude-plugin/plugin.json', 'plugin.json']
VERSION = re.compile(r'"version"\s*:\s*"[^"]*"')
MARKETPLACES = [
    '.claude-plugin/marketplace.json',
    '.cursor-plugin/marketplace.json',
]


def plugin_names():
    return sorted(p.name for p in Path('plugins').iterdir() if p.is_dir())


def locations(name):
    """Yield (path, data, holder) for each JSON object that holds a version for the plugin."""
    for rel in PLUGIN_MANIFESTS:
        path = Path('plugins', name, rel)
        if path.is_file():
            data = json.loads(path.read_text())
            yield path, data, data
    for rel in MARKETPLACES:
        path = Path(rel)
        if not path.is_file():
            continue
        data = json.loads(path.read_text())
        for entry in data.get('plugins', []):
            if entry.get('name') == name and 'version' in entry:
                yield path, data, entry


def check():
    failed = False
    for name in plugin_names():
        found = {str(path): holder.get('version') for path, _, holder in locations(name)}
        if len(set(found.values())) > 1:
            failed = True
            print(f'{name}: versions differ')
            for path, version in found.items():
                print(f'  {version}  {path}')
        elif None in found.values():
            failed = True
            print(f'{name}: no version in {[p for p, v in found.items() if v is None]}')
    if failed:
        sys.exit('Run: python3 .github/scripts/sync-versions.py <plugin> <version>')
    print('Manifest versions match.')


def write(name, version):
    if name not in plugin_names():
        sys.exit(f'No plugin named {name} under plugins/.')
    pending = {}
    for path, data, holder in locations(name):
        if holder is data:
            # A plugin manifest: replace the string in place to keep the file's formatting.
            text = pending.get(path) or path.read_text()
            pending[path] = VERSION.sub(f'"version": "{version}"', text, count=1)
        else:
            holder['version'] = version
            pending[path] = json.dumps(data, indent=2, ensure_ascii=False) + '\n'
    for path, text in pending.items():
        path.write_text(text)
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
