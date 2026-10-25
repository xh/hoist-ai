#!/usr/bin/env node
// Builds the Hoist sections of AGENTS.md from the templates beside this script and prints them.
//
// Usage: node build-agents-md.mjs --pkg <yarn|npm|pnpm> --decorators <tc39|legacy>
//            [--plugin "<name>|<npm|Grails>|<version>|<what it provides>"]... [--plugin-note "<text>"]...
//
// --plugin adds a row to the Client Plugins section, and --plugin-note adds a line below the table.
// The section is included only when at least one --plugin is given.

import {readFileSync} from 'node:fs';
import {dirname, join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {parseArgs} from 'node:util';

const COMMANDS = {
    yarn: {install: 'yarn install', start: 'yarn start', lint: 'yarn lint'},
    npm: {install: 'npm install', start: 'npm start', lint: 'npm run lint'},
    pnpm: {install: 'pnpm install', start: 'pnpm start', lint: 'pnpm lint'}
};

const templatesDir = join(dirname(fileURLToPath(import.meta.url)), '..', 'templates'),
    read = name => readFileSync(join(templatesDir, name), 'utf8'),
    fail = msg => {
        console.error(`build-agents-md: ${msg}`);
        process.exit(1);
    };

const {values} = parseArgs({
    options: {
        pkg: {type: 'string'},
        decorators: {type: 'string'},
        plugin: {type: 'string', multiple: true, default: []},
        'plugin-note': {type: 'string', multiple: true, default: []}
    }
});

const cmds = COMMANDS[values.pkg];
if (!cmds) fail('--pkg must be yarn, npm, or pnpm');
if (!['tc39', 'legacy'].includes(values.decorators)) fail('--decorators must be tc39 or legacy');

let out = read('agents-md-base.md')
    .replace('{{MODEL_PRIMER}}', read(`agents-md-models-${values.decorators}.md`).trimEnd())
    .replace('{{PKG_MGR_INSTALL}}', cmds.install)
    .replace('{{PKG_MGR_START}}', cmds.start)
    .replace('{{PKG_MGR_LINT}}', cmds.lint);

if (values.plugin.length) {
    const rows = values.plugin.map(spec => {
        const cells = spec.split('|').map(s => s.trim());
        if (cells.length !== 4) fail(`--plugin needs 4 fields separated by "|": ${spec}`);
        return `| ${cells.join(' | ')} |`;
    });
    const section = read('agents-md-client-plugins.md')
        .replace('{{PLUGIN_TABLE}}', rows.join('\n'))
        .replace('{{PLUGIN_NOTES}}', values['plugin-note'].join('\n\n'));
    out = `${out.trimEnd()}\n\n${section}`;
}

process.stdout.write(out.endsWith('\n') ? out : `${out}\n`);
