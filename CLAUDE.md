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
  feedback/              GitHub issue filing for feedback
  hoist-upgrade/         Guided @xh/hoist version upgrade
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
- Before bumping `plugin.json` for a release that touches a model-invokable skill, run
  `skill-creator` evals against both reference skills (`using-hoist-react-reference` and
  `using-hoist-core-reference`) and confirm the acceptance bars (>=90% positive recall,
  <=10% false-positive rate) are met. The eval suites live under each skill's `evals/` directory.
