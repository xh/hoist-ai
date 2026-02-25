# hoist-ai Plugin Development

This is the `@xh/hoist-ai` Claude Code plugin -- AI augmentation for Hoist application
development. Maintained by Extremely Heavy Industries (https://xh.io).

## Repository Structure

```
.claude-plugin/          Plugin manifest and marketplace catalog
  plugin.json            Name, version, description, author
  marketplace.json       Marketplace entry for team installation
skills/                  Plugin skills (invoked via /hoist-ai:skill-name)
  hoist-onboard/         Project setup and AI configuration
  hoist-feedback/        GitHub issue filing for feedback
.mcp.json                Auto-configures hoist-react MCP server
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
- Test skills against both frontend-only and full-stack Hoist projects.

## Key Rules

- No absolute paths in any committed files -- all paths must be relative.
- Keep consumer-facing files generic -- do not reference specific sibling repos or client projects.
- The `.mcp.json` launches the MCP server via the `hoist-mcp.mjs` wrapper in `client-app/node_modules/@xh/hoist/bin/`.
- Always bump `plugin.json` version before pushing changes.
