---
name: hoist-onboard
description: Configure and verify AI setup for a Hoist project. Detects project type, generates CLAUDE.md, and verifies MCP server connectivity.
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, mcp__hoist-react__hoist-ping, mcp__hoist-react__hoist-search-docs
---

# Hoist Project Onboarding

Configure this Hoist project for AI-augmented development. Follow each phase in order.

## Phase 1: Detect Project

1. Read `package.json` in the project root. Find `@xh/hoist` in `dependencies` or `devDependencies` and extract the version number.
2. If `@xh/hoist` is NOT found, inform the user: "This does not appear to be a Hoist project -- `@xh/hoist` was not found in package.json." Then stop.
3. Check for `build.gradle` or a `grails-app/` directory at the project root -- either indicates a full-stack project.
4. If full-stack indicators are found, grep `build.gradle` for `hoist-core` to confirm the server-side framework.
5. Check for `yarn.lock` to confirm the package manager (all Hoist apps use Yarn).
6. Check for an existing `CLAUDE.md` at the project root.
7. Check for a `client-app/` subdirectory (indicates a monorepo/full-stack layout).

## Phase 2: Present Findings

Display a summary of what was detected:

```
## Project Detection Results

- **Hoist version:** [version from package.json]
- **Project type:** [Frontend-only | Full-stack (hoist-core detected)]
- **Package manager:** Yarn [confirmed | not confirmed -- yarn.lock not found]
- **Existing CLAUDE.md:** [Yes -- merge needed | No -- will create fresh]
- **Monorepo layout:** [Yes (client-app/ found) | No]

### Planned Actions
- [Create | Update] CLAUDE.md with Hoist conventions (~[N] lines)
- Verify MCP server connectivity
```

Ask the user: **"Proceed with setup? (yes/no)"**

Wait for the user to confirm before making any changes. Do NOT write any files until the user says yes.

## Phase 3: Generate CLAUDE.md

Locate the template files bundled with this skill. Use `Glob` to find the templates:
```
**/hoist-onboard/templates/claude-md-base.md
```
Read the base template from the matched path.

1. Replace all occurrences of `{{HOIST_VERSION}}` in the template with the detected version string (e.g. `v72.1.0` or the raw version number).
2. If the project is full-stack: also read `claude-md-server.md` from the same templates directory and append its content to the base template.
3. If an existing `CLAUDE.md` is present:
   - Read the existing file.
   - Check which Hoist sections are already present (look for headings like "Architecture", "Key Conventions", "Commands", "MCP Server", "Server-Side").
   - Append only sections that are missing. Do NOT overwrite or duplicate existing content.
   - Show the user what will be added before writing.
   - Preserve all existing project-specific content.
4. If no `CLAUDE.md` exists: write the complete generated template to `./CLAUDE.md`.

## Phase 4: Verify MCP Server

1. Call `mcp__hoist-react__hoist-ping`. Expect the response to contain "Hoist MCP server is running."
2. If ping succeeds: call `mcp__hoist-react__hoist-search-docs` with query `"HoistModel"` as a sample query to confirm docs are accessible.
3. If ping fails or the MCP tool is not available: inform the user that the MCP server is not currently reachable but the CLAUDE.md has been configured and works standalone. Suggest:
   - Ensure `@xh/hoist` is installed (`yarn install`)
   - Check that the hoist-react MCP server is configured (the `@xh/hoist-ai` plugin should handle this automatically)

## Phase 5: Report

Display a final summary:

```
## Onboarding Complete

- **CLAUDE.md:** [Created | Updated (added N sections) | Already up to date]
- **MCP server:** [Connected -- docs accessible | Not available (CLAUDE.md works standalone)]
- **Next steps:** Start coding with AI assistance. The MCP server tools provide
  framework documentation and API lookup when available.
```
