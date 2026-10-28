# hoist-ai Plugin Development

This is the `hoist-ai` marketplace - agent plugins for AI-augmented Hoist application
development, for Claude Code, Cursor, and Codex. Maintained by Extremely Heavy Industries
(https://xh.io).

## Repository Structure

```
.claude-plugin/marketplace.json   Marketplace catalog for Claude Code
.cursor-plugin/marketplace.json   Marketplace catalog for Cursor
.agents/plugins/marketplace.json  Marketplace catalog for Codex, with its install policy
plugins/<plugin>/                 One plugin per directory
  .claude-plugin/plugin.json      Claude Code manifest: name, version, description, author
  plugin.json                     Agent Plugins manifest, read by Cursor and Codex
  CHANGELOG.md                    Per-plugin release notes
  skills/<skill>/SKILL.md         Agent Skills format
```

## Development Workflow

1. Make changes to skills, templates, or configuration files.
2. Test locally in a Hoist project, in each harness the change affects. Load the plugin with
   `claude --plugin-dir /path/to/hoist-ai/plugins/xh` or `agent --plugin-dir ...` for Cursor. For
   Codex, add the repo as a local marketplace. `docs/harness-testing.md` has the full procedure.
3. Run the checks in `.github/scripts/`. CI runs them too:
   - `check-removed-apis.py` fails when skill text teaches a hoist-react API that a major
     removed, outside text marked as version-gated.
   - `check-schemas.py` fails when a skill, plugin manifest, or marketplace file breaks a
     harness's schema. It holds the field lists for each format. Update them when a harness
     changes its format.
   - `sync-versions.py` fails when a plugin's manifests disagree on version or description, or
     when a marketplace does not list a plugin.
4. If the change ships new behavior to consumers, bump the version in every manifest with
   `python3 .github/scripts/sync-versions.py <plugin> <version>`.
5. Push to `main`. Claude Code projects that `onboard-app` set up update automatically. Cursor
   and Codex users refresh the marketplace.

## Skill Authoring Conventions

- Each skill lives in `plugins/<plugin>/skills/<skill-name>/SKILL.md`.
- Use YAML frontmatter: `name`, `description`, `allowed-tools`. Only Claude Code reads
  `allowed-tools`, so a skill must work without it.
- Set `disable-model-invocation: true` for skills that should only run on explicit invocation.
  Claude Code and Cursor honor it. Codex ignores it (openai/codex#29989) and needs
  `agents/openai.yaml` in the skill folder with `policy: allow_implicit_invocation: false`.
- Supporting files (templates, rules) go in subdirectories of the skill folder. Point to them
  relative to the SKILL.md folder, with a `**/<skill>/...` search as the fallback. Never use
  `${CLAUDE_PLUGIN_ROOT}` or a Claude Code tool name as the only way to find or copy a file.
- Name a tool by what it does. A Claude Code tool name such as `mcp__hoist-react__*` can appear
  only as an example.
- A skill can use `../<other-skill>/` files only when both skills ship in the same plugin.
- Test skills against real Hoist projects.

## Key Rules

- No absolute paths in any committed files - all paths must be relative.
- Skills describe procedure. Version-specific facts (which tools exist, what they return, API
  conventions) live in hoist-react and ship with each `@xh/hoist` version through the MCP's tool
  descriptions, server instructions, and docs. Write skill rules that branch on what a tool returns
  (for example "if the results are sections"), never on a hoist-react version number or on how much
  a tool prints. A rule that stops being true when the MCP improves is a bug in the skill.
- Prose in this repo (CHANGELOG, README, skill text, commit messages, PR descriptions) follows
  the `clear-writing` skill. Lint a draft with its script before you commit it.
- Do not hard-wrap commit bodies, PR descriptions, or issue and PR comments at a fixed column.
  Write each paragraph as one line and let GitHub and other tools wrap it. Do use line breaks for
  structure: a blank line after the subject and between paragraphs, and a bullet list for separate
  points. Keep PR descriptions short, because XH developers review them often. Bullet the key
  changes and let the diff show the rest. CHANGELOG entries are the exception: hard-wrap them at
  100 characters.
- Keep consumer-facing files generic - do not reference specific sibling repos or client projects.
- The onboarding skill configures the hoist-react MCP server in each consuming project's
  `.mcp.json` for Claude Code and `.cursor/mcp.json` for Cursor. Codex uses the CLI launchers.
- Bump the plugin's `plugin.json` version and add an entry to its `CHANGELOG.md` only when a
  change ships new behavior to consumers, such as edits to skills, templates, or scripts.
  Changes to docs, repo-only files, or files the plugin never loads do not need a release.
- Before bumping `plugin.json` for a release that touches a model-invokable skill, follow
  skill-creator best practices on the `description:` frontmatter: single paragraph with no
  blank-line breaks (the harness truncates display at blank lines); lead with a "Why this
  matters:" line citing concrete failure modes rather than an "ALWAYS use this skill when..."
  imperative (skill-creator flags ALL-CAPS imperatives as a yellow flag); concrete TRIGGER/SKIP
  blocks anchoring on real keywords/symbols the user is likely to type. The trigger eval sets
  live at `plugins/<plugin>/skills/<skill>/evals/trigger.json` and can be re-run via the
  skill-creator `run_eval.py` script for a directional sanity check (FP rate should stay near
  0%; positive recall should not regress) - but the script simulates skills as slash commands
  under `claude -p` and exhibits a measurement ceiling around 15% recall regardless of
  description quality, so it is NOT a hard pass/fail bar. Keep each description within 1024
  characters. Codex rejects a longer one, and `check-schemas.py` enforces it.
- Skills that ship executable content (launcher scripts, wrappers) MUST keep that content in
  separate files, never inline in SKILL.md fenced code blocks. Use `templates/` for content
  copied into consumer projects and `scripts/` for tools the skill runs in place.
  Nested-double-quoted shell expansions like `"$(dirname "$0")"` have been
  observed losing the `$0` literal somewhere in the skill-loading pipeline when embedded in
  fenced code blocks. The install procedure should find the template beside the SKILL.md and
  copy it byte-exact with `cp` - a file read and write round-trips through serialization layers
  that can mangle content the same way.
- CHANGELOG entries: terse. 1-3 lines per bullet, lead with the WHAT and only the essential
  WHY. Save attribution, methodology citations, metaphors, eval numbers, and detailed reasoning
  for the commit message. Avoid stale-prone specifics: don't bake in exact counts (eval query
  totals, recall percentages), command invocations, file paths within the plugin, or version
  numbers being compared - those rot as the code evolves. A reader should be able to scan
  one release's entry in ~10 seconds.

---

info@xh.io | https://xh.io
Copyright 2026 Extremely Heavy Industries Inc.
