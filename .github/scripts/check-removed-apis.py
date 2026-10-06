#!/usr/bin/env python3
"""Fail when skill or template text teaches hoist-react APIs that v88 removed.

Scans every file under skills/. Text that must name a removed API on purpose, such as a
pre-v88 primer or a rule that detects stale docs, can opt out in two ways:

- Put "legacy" in the file name, for example claude-md-models-legacy.md.
- Wrap the lines in "legacy-api:start" and "legacy-api:end" markers. Any comment syntax works,
  for example <!-- legacy-api:start --> in Markdown.

Run from the repo root: python3 .github/scripts/check-removed-apis.py
"""

import re
import sys
from pathlib import Path

PATTERNS = [
    ('makeObservable', re.compile(r'makeObservable')),
    ('@observable.ref', re.compile(r'@observable\.ref\b')),
    ('@bindable.ref', re.compile(r'@bindable\.ref\b')),
    ('@computed.struct', re.compile(r'@computed\.struct\b')),
    ('experimentalDecorators', re.compile(r'experimentalDecorators')),
    ('configureWebpack', re.compile(r'configureWebpack')),
    ('--env build flag', re.compile(r'--env [A-Za-z]')),
]

START, END = 'legacy-api:start', 'legacy-api:end'


def scan(path):
    hits = []
    gated = False
    for num, line in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
        if START in line:
            gated = True
            continue
        if END in line:
            gated = False
            continue
        if gated:
            continue
        for name, pattern in PATTERNS:
            if pattern.search(line):
                hits.append(f'{path}:{num}: {name}: {line.strip()}')
    if gated:
        hits.append(f'{path}: unclosed {START} marker')
    return hits


def main():
    root = Path('skills')
    if not root.is_dir():
        sys.exit('Run from the repo root: skills/ not found.')
    hits = []
    for path in sorted(root.rglob('*')):
        if not path.is_file() or 'legacy' in path.name:
            continue
        try:
            hits.extend(scan(path))
        except UnicodeDecodeError:
            continue
    if hits:
        print('Removed hoist-react APIs found outside version-gated text:')
        print('\n'.join(hits))
        print(f'\nGate intentional mentions with {START} / {END} markers, '
              'or move them to a file named *legacy*.')
        sys.exit(1)
    print('No removed hoist-react APIs found.')


if __name__ == '__main__':
    main()
