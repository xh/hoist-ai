---
name: onboard-app
description: Configure and verify AI setup for a Hoist project. Detects project type, generates CLAUDE.md, and verifies MCP server connectivity.
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, mcp__hoist-react__hoist-ping, mcp__hoist-react__hoist-search-docs
---

# Hoist Project Onboarding

Configure this Hoist project for AI-augmented development. Follow each phase in order.

## Hoist Project Structure

All Hoist applications share the same layout: a Grails/Groovy backend at the project root and
a React/TypeScript frontend in `client-app/`. Key locations:

- `client-app/package.json` -- frontend dependencies, including `@xh/hoist`
- `client-app/yarn.lock` or `client-app/package-lock.json` -- package manager lockfile
- `client-app/src/` -- frontend application source
- `build.gradle` -- Gradle build config with `hoist-core` dependency
- `gradle.properties` -- app metadata (`hoistCoreVersion`, `xhAppCode`, etc.)
- `grails-app/` -- Grails controllers, services, domain classes

## Phase 1: Detect Project

1. **Detect package manager.** Check which lockfile exists in `client-app/`:
   - `yarn.lock` -- use `yarn` (e.g. `yarn install`, `yarn why`)
   - `package-lock.json` -- use `npm` (e.g. `npm install`, `npm ls`)
   Store the detected package manager for use throughout this skill.
2. Determine the installed `@xh/hoist` version. Read `client-app/package.json` and check
   `dependencies` for `@xh/hoist`.
   - **Direct dependency:** If `@xh/hoist` appears in `dependencies`, extract the version.
   - **Transitive dependency:** If not found directly, `@xh/hoist` may be pulled in via a
     client-specific plugin. Run (from `client-app/`):
     - Yarn: `yarn why @xh/hoist`
     - npm: `npm ls @xh/hoist`
     Parse the output to find the resolved version and note which package depends on it.
   - If neither approach finds `@xh/hoist`, inform the user: "This does not appear to be a
     Hoist project -- `@xh/hoist` was not found as a direct or transitive dependency." Then stop.
3. Confirm standard project structure: check that `build.gradle`, `grails-app/`, and
   `gradle.properties` exist at the project root.
4. Read `gradle.properties` and extract `hoistCoreVersion`.
5. Check for an existing `CLAUDE.md` at the project root.
6. Query npm for the latest stable `@xh/hoist` version:
   ```bash
   npm view @xh/hoist dist-tags.latest
   ```
   Compare the installed version (from step 1) to the latest available. Store both values for
   use in Phase 2.

## Phase 2: Present Findings

Display a summary of what was detected:

```
## Project Detection Results

- **@xh/hoist version:** [version] ([up to date | upgrade available: v[latest]])
- **hoist-core version:** [version from gradle.properties]
- **Existing CLAUDE.md:** [Yes -- merge needed | No -- will create fresh]

### Planned Actions
- [Create | Update] CLAUDE.md with Hoist conventions (~[N] lines)
- Verify MCP server connectivity
```

If the installed `@xh/hoist` version is behind the latest stable release, add this section after
the detection summary and BEFORE the "Proceed with setup?" confirmation:

```
### Hoist Upgrade Available

Your project is on @xh/hoist v[installed], but v[latest] is available.
The MCP server and AI tooling work best with a recent Hoist version.

**Recommendation:** Run `/hoist-upgrade` to upgrade before completing onboarding.
```

Then ask: **"Would you like to upgrade first? (yes = run /hoist-upgrade, no = continue with current version)"**

- If yes: Tell the developer to run `/hoist-upgrade` (or `/xh:hoist-upgrade`). The
  onboarding skill should stop here and instruct the developer to re-run `/onboard-app` after
  the upgrade completes. (Skills cannot invoke other skills directly -- this is a handoff.)
- If no: Continue with onboarding as normal using the current version.

If the installed version is already up to date, skip the upgrade recommendation and proceed
directly to:

Ask the user: **"Proceed with setup? (yes/no)"**

Wait for the user to confirm before making any changes. Do NOT write any files until the user says yes.

## Phase 3: Generate CLAUDE.md

Locate the template files bundled with this skill. Use `Glob` to find the templates:
```
**/onboard-app/templates/claude-md-base.md
```
Read the base template from the matched path.

1. Replace all occurrences of `{{HOIST_VERSION}}` in the template with the detected version
   string (e.g. `v72.1.0` or the raw version number).
2. Also read `claude-md-server.md` from the same templates directory and append its content
   to the base template (all Hoist apps have a server side).
3. If an existing `CLAUDE.md` is present:
   - Read the existing file.
   - Check which Hoist sections are already present (look for headings like "Architecture",
     "Key Conventions", "Commands", "MCP Server", "Server-Side").
   - Append only sections that are missing. Do NOT overwrite or duplicate existing content.
   - Show the user what will be added before writing.
   - Preserve all existing project-specific content.
4. If no `CLAUDE.md` exists: write the complete generated template to `./CLAUDE.md`.

## Phase 4: Verify MCP Server

1. Call `mcp__hoist-react__hoist-ping`. Expect the response to contain "Hoist MCP server is running."
2. If ping succeeds: call `mcp__hoist-react__hoist-search-docs` with query `"HoistModel"` as a
   sample query to confirm docs are accessible.
3. If ping fails or the MCP tool is not available: inform the user that the MCP server is not
   currently reachable but the CLAUDE.md has been configured and works standalone. Suggest:
   - Ensure `@xh/hoist` is installed (run the project's package manager install from `client-app/`)
   - Check that the hoist-react MCP server is configured (the `xh` plugin should handle this
     automatically)

## Phase 5: Report

Display a final summary:

```
## Onboarding Complete

- **CLAUDE.md:** [Created | Updated (added N sections) | Already up to date]
- **MCP server:** [Connected -- docs accessible | Not available (CLAUDE.md works standalone)]
- **Next steps:** Start coding with AI assistance. The MCP server tools provide
  framework documentation and API lookup when available.
```
