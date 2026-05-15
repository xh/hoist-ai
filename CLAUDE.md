# hoist-ai Plugin Development

This is the `xh` Claude Code plugin (from the `hoist-ai` marketplace) -- AI augmentation for
Hoist application development. Maintained by Extremely Heavy Industries (https://xh.io).

## Repository Structure

```
.claude-plugin/          Plugin manifest and marketplace catalog
  plugin.json            Name, version, description, author
  marketplace.json       Marketplace entry for team installation
skills/                  Plugin skills (invoked via /xh:skill-name)
  onboard-app/           Project setup and AI configuration
  hoist-upgrade/         Guided @xh/hoist version upgrade
  using-hoist-core-reference/    Authoritative reference + install for hoist-core MCP/CLI tools
  using-hoist-react-reference/   Authoritative reference for the @xh/hoist React framework
settings.json            Default MCP tool permission allowlist
```

## Development Workflow

1. Make changes to skills, templates, or configuration files.
2. Test locally: install from local path in a Hoist project.
   - In Claude Code: `/plugin install /path/to/hoist-ai --scope project`
   - Verify skills run correctly and MCP server starts.
3. Bump the version in `.claude-plugin/plugin.json` before pushing.
4. Push to `main` -- marketplace consumers pick up updates automatically.

## Skill Authoring Conventions

- Each skill lives in `skills/<skill-name>/SKILL.md`.
- Use YAML frontmatter: `name`, `description`, `allowed-tools`.
- Set `disable-model-invocation: true` for skills that should only run on explicit invocation.
- Supporting files (templates, rules) go in subdirectories of the skill folder.
- Test skills against real Hoist projects.

## Key Rules

- No absolute paths in any committed files -- all paths must be relative.
- Keep consumer-facing files generic -- do not reference specific sibling repos or client projects.
- The onboarding skill configures the hoist-react MCP server in each consuming project's `.mcp.json`.
- Always bump `plugin.json` version before pushing changes.
- Before bumping `plugin.json` for a release that touches a model-invokable skill, follow
  skill-creator best practices on the `description:` frontmatter: single paragraph with no
  blank-line breaks (the harness truncates display at blank lines); lead with a "Why this
  matters:" line citing concrete failure modes rather than an "ALWAYS use this skill when..."
  imperative (skill-creator flags ALL-CAPS imperatives as a yellow flag); concrete TRIGGER/SKIP
  blocks anchoring on real keywords/symbols the user is likely to type. The trigger eval sets
  live at `skills/<skill>/evals/trigger.json` and can be re-run via the skill-creator
  `run_eval.py` script for a directional sanity check (FP rate should stay near 0%; positive
  recall should not regress) -- but the script simulates skills as slash commands under
  `claude -p` and exhibits a measurement ceiling around 15% recall regardless of description
  quality, so it is NOT a hard pass/fail bar.
- Skills that ship executable content (launcher scripts, wrappers) MUST keep that content in
  separate template files under the skill's `templates/` directory, never inline in SKILL.md
  fenced code blocks. Nested-double-quoted shell expansions like `"$(dirname "$0")"` have been
  observed losing the `$0` literal somewhere in the skill-loading pipeline when embedded in
  fenced code blocks. The install procedure should `Glob` for the template and `Bash cp` it
  byte-exact -- `Read`+`Write` round-trips through serialization layers that can mangle
  content the same way.
- CHANGELOG entries: terse. 1-3 lines per bullet, lead with the WHAT and only the essential
  WHY. Save attribution, methodology citations, metaphors, eval numbers, and detailed reasoning
  for the commit message. Avoid stale-prone specifics: don't bake in exact counts (eval query
  totals, recall percentages), command invocations, file paths within the plugin, or version
  numbers being compared -- those rot as the code evolves. A reader should be able to scan
  one release's entry in ~10 seconds.

---

info@xh.io | https://xh.io
Copyright 2026 Extremely Heavy Industries Inc.
