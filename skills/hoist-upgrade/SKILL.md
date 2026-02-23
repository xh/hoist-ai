---
name: hoist-upgrade
description: Upgrade a Hoist app between versions. Reads per-version upgrade guides, auto-applies mechanical code migrations, flags judgment calls, and produces a comprehensive upgrade report.
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, mcp__hoist-react__hoist-search-docs, mcp__hoist-react__hoist-get-symbol, mcp__hoist-react__hoist-search-symbols
---

# Hoist Version Upgrade

Upgrade this Hoist project's `@xh/hoist` dependency between versions. Follow each phase in order.

## Phase 1: Detect

Gather project information needed to plan and execute the upgrade.

### 1. Parse arguments

Check `$ARGUMENTS` for an optional target version (e.g. `81.0.0` or `v81`). If present, normalize
it: strip any leading `v`, store as the target version for Phase 2. If no argument is provided,
the skill will prompt the developer to choose a target in Phase 2.

### 2. Detect current @xh/hoist version

Read `package.json` in the project root. If a `client-app/` subdirectory exists (monorepo layout),
read `client-app/package.json` instead. Find `@xh/hoist` in `dependencies` and extract the current
version. Handle version strings like `^82.0.0-SNAPSHOT` -- extract the numeric portion
(e.g. `82.0.0`).

If `@xh/hoist` is NOT found in `dependencies`, inform the user:
> "This does not appear to be a Hoist project -- `@xh/hoist` was not found in package.json."

Then stop.

### 3. Check for dirty working tree

Run:
```bash
git status --porcelain
```

If output is non-empty, warn the developer:
> "Your working tree has uncommitted changes. Please commit or stash them before running the
> upgrade to ensure a clean rollback point if needed."

Do NOT proceed with any modifications until the working tree is clean.

### 4. Read hoist-core version

All Hoist apps have a server side. Read `gradle.properties` at the project root (or parent
directory for monorepo layouts). Extract the `hoistCoreVersion` value.

If the version is not set directly (e.g. it is inherited from a client-specific Grails plugin
dependency), check `build.gradle` for the plugin dependency and note the transitive hoist-core
version if determinable.

**Assess server-side significance:** Check `CLAUDE.md` for notes about server-side complexity.
Also scan the Grails app package (e.g. `grails-app/controllers/`, `grails-app/services/`) for
custom controllers and services. If extensive custom server code is present, note this -- it
means hoist-core version bumps warrant extra attention in the upgrade report.

### 5. Detect client plugins

Scan `package.json` dependencies for packages that are NOT `@xh/hoist` but appear to be
Hoist-related client plugins (e.g. `@client/hoist-plugin`, `@client/hoist-*`, or packages
referenced alongside `@xh/hoist` in a monorepo).

Also read `CLAUDE.md` for any documented plugin-to-Hoist version mapping or plugin notes.

When a client plugin is detected, note the package name, current version, and any version
mapping information for use in Phase 2 planning.

### 6. Detect package manager

Check which lockfile exists in the project root (or `client-app/` for monorepos):
- `yarn.lock` -- use `yarn install` for installs and `yarn lint` for linting
- `package-lock.json` -- use `npm install` for installs and `npm run lint` for linting

If both or neither lockfile exists, ask the developer which package manager to use.

Store the detected install command and run command for use throughout Phases 3-4.

## Phase 2: Plan

Present the upgrade plan for developer confirmation. Do NOT make any changes until the developer
confirms.

### 1. Determine target version

If a target version was provided via arguments in Phase 1, use it.

If no target version was specified, query npm for available versions:
```bash
npm view @xh/hoist versions --json
```

Filter the results to **stable releases only** -- versions matching `x.y.z` with no prerelease
suffix. Exclude versions with `-SNAPSHOT`, `-alpha`, `-beta`, `-rc`, or any other prerelease tag.
XH publishes many SNAPSHOT versions to npm during development -- these should never be suggested
as upgrade targets.

Filter to versions newer than the currently installed version and present a structured list:
```
Available @xh/hoist versions (you have v{current}):

  v79.0.0
  v80.0.0
  v80.1.0
  v81.0.0  <- latest

What version would you like to upgrade to?
```

Wait for the developer to choose before continuing.

### 2. Determine version hop sequence

Each major version between current and target is a separate hop. Example: v77 -> v81 produces
the sequence [v77->v78, v78->v79, v79->v80, v80->v81].

For minor version jumps within the same major version (e.g. v80.0.0 -> v80.1.0), treat that as
a single hop.

### 3. Check guide availability

For each hop in the sequence, check if a dedicated upgrade guide exists. Use Glob to look for:
```
node_modules/@xh/hoist/docs/upgrade-notes/v*-upgrade-notes.md
```

Match each hop's target version against the available files. If a guide does NOT exist for a
particular hop's target version (versions before v78 will not have one), note that hop as
"CHANGELOG-only" and alert the developer:
> "Note: No dedicated upgrade guide exists for v{target}. This hop will use CHANGELOG entries
> only, and guidance may be less thorough."

### 4. Client plugin confirmation

If client plugins were detected in Phase 1, present the detection:
```
### Client Plugins Detected

| Plugin | Current Version | Hoist Version Mapping |
|--------|----------------|----------------------|
| {plugin name} | {version} | {mapping from CLAUDE.md, or "No mapping found"} |

How should I handle the plugin version during this upgrade?
- Bump to a specific version?
- Leave unchanged?
- Other guidance?
```

Do not proceed until the developer confirms the plugin approach.

### 5. Display the upgrade plan

```
## Upgrade Plan: @xh/hoist v{current} -> v{target}

| Hop | Guide Available | Difficulty |
|-----|-----------------|------------|
| v77 -> v78 | Yes (upgrade notes) | TBD (read during execution) |
| v78 -> v79 | Yes (upgrade notes) | TBD |
| ...

- **Branch:** upgrade/hoist-v{current}-to-v{target} (or existing branch if found)
- **Commits:** One per version hop
- **hoist-core:** {current version from gradle.properties}
- **Server complexity:** {Minimal (stock) | Significant (custom controllers/services)}
- **Client plugins:** {Detected plugins, or "None detected"}
- **Package manager:** {yarn | npm}
```

### 6. Confirm with developer

Ask: **"Proceed with this upgrade plan? (yes/no)"**

Wait for confirmation before making any changes.

## Phase 3: Execute

For each version hop in the sequence, apply the upgrade. Never commit directly to main or
develop.

### 3a. Branch setup (first hop only)

Check for existing branches matching `upgrade/hoist-*` or `hoist-upgrade-*` patterns:
```bash
git branch --list "upgrade/hoist-*" "hoist-upgrade-*"
```

If a matching branch exists, ask the developer if they want to reuse it.

If no match (or developer declines reuse), create a new branch:
```bash
git checkout -b upgrade/hoist-v{current}-to-v{target}
```

Verify the current branch is NOT main or develop before any commits.

### 3b. Bump version and install

Update the `@xh/hoist` version in `package.json` `dependencies` to the hop's target version
(e.g. `"@xh/hoist": "^{target}"`).

Run the detected install command (e.g. `yarn install` or `npm install`) to update the lockfile
and install the new version.

**Important:** The upgrade notes for version N ship with version N. They are only available on
the filesystem after installing the target version.

### 3c. Read upgrade guide for this hop

Use the `Read` tool to read upgrade notes directly from the filesystem:
```
node_modules/@xh/hoist/docs/upgrade-notes/v{TARGET}-upgrade-notes.md
```

**Do NOT use MCP `hoist-search-docs` for upgrade notes.** The MCP server may still be serving
the previous version's content after install. The `Read` tool always reflects the installed
version.

For versions WITHOUT upgrade notes (pre-v78): Read `node_modules/@xh/hoist/CHANGELOG.md` and
parse the `Breaking Changes` section for the target version. Alert the developer:
> "No dedicated upgrade guide exists for this version. Using CHANGELOG breaking changes section.
> Guidance may be less thorough for this hop."

### 3d. Apply migrations

Read the upgrade guide carefully. For each migration step:

**Mechanical changes** (renames, import updates, CSS class changes):
1. Use the grep commands from the upgrade guide to find affected files in the project
2. Apply changes using the Edit tool
3. Verify with a second grep that the old patterns are gone

**Judgment calls** (behavior changes, multiple replacement options, architectural decisions):
1. Do NOT apply automatically
2. Use grep to find affected files
3. Record the item with: description, affected files, and the guide's recommendation
4. These will be included in the upgrade report for developer review

When migration involves API changes and you need to verify new API shapes, prefer the
before/after code examples in the upgrade guide. MCP API lookups (`hoist-get-symbol`,
`hoist-search-symbols`) may reflect the previous version until the MCP server is reconnected.

### 3e. Check and bump hoist-core version

Parse the upgrade guide's "Prerequisites" section for hoist-core version requirements (e.g.
"hoist-core >= v36.1").

If a requirement is found, compare against the current `hoistCoreVersion` from
`gradle.properties` (read in Phase 1).

If the current version is below the requirement:
1. Bump `hoistCoreVersion` in `gradle.properties` to the required version
2. Prominently note this change for the upgrade report
3. If the project has significant server-side code (detected in Phase 1), add a prominent
   warning that the hoist-core upgrade may require additional server-side review

### 3f. Handle client plugin version (if applicable)

If a client plugin was detected and the developer confirmed a version strategy in Phase 2:
1. Bump the client plugin version in `package.json` according to the confirmed strategy
2. Run the install command again after the plugin version bump

### 3g. Commit this hop

```bash
git add -A
git commit -m "Upgrade @xh/hoist v{FROM} -> v{TO}"
```

### 3h. Progress reporting

After each hop, display a brief status showing progress through the sequence:

```
## Upgrade Progress: v{start} -> v{end}

[completed] v77 -> v78 (TRIVIAL) -- N changes applied, M judgment calls
[in progress] v78 -> v79 -- in progress...
[pending] v79 -> v80 -- pending
```

## Phase 4: Verify

After ALL hops are complete, run verification.

### 1. Reconnect MCP server

The Hoist MCP server is still serving the pre-upgrade version's types and docs. Prompt the
developer:

> "All version hops are complete. The Hoist MCP server needs to reconnect to load the updated
> @xh/hoist v{target} types and documentation.
>
> Please run `/mcp` in Claude Code to reconnect, then confirm when ready."

After the developer confirms, verify with `hoist-ping` that the server is responsive and
serving the target version.

### 2. TypeScript compilation

Run:
```bash
npx tsc --noEmit
```
Report pass/fail.

### 3. Lint

Run the project's lint command (detected in Phase 1, e.g. `yarn lint` or `npm run lint`).
Report pass/fail.

### 4. Guided verification

If the final version's upgrade guide includes a verification checklist, present it to the
developer and work through each item.

If verification fails, present the errors and work with the developer to resolve them before
proceeding to the report phase.

### Verification cadence

For multi-hop upgrades where all hops are LOW or TRIVIAL difficulty, batch all verification at
the end. For hops rated MEDIUM or higher, consider running intermediate TypeScript compilation
checks after those hops to catch issues before they compound. Use your judgment based on the
difficulty ratings read from the upgrade guides.

## Phase 5: Report

### 1. Locate the upgrade report template

Use `Glob` to find the template:
```
**/hoist-upgrade/templates/upgrade-report.md
```

Read the template from the matched path.

### 2. Generate the upgrade report

Fill in the template with all data collected during the upgrade:
- Version hops completed with difficulty ratings
- Changes applied per hop (files modified, what was changed)
- Judgment calls flagged per hop (description, affected files, recommendation)
- Verification results (tsc, lint, any other checks)
- hoist-core changes (if version was bumped)
- Client plugin notes (if plugins were detected and handled)

Write the completed report to:
```
docs/upgrade-reports/upgrade-v{FROM}-to-v{TO}-{YYYY-MM-DD}.md
```

Create the `docs/upgrade-reports/` directory if it does not exist.

### 3. Display terminal summary

Show a condensed summary in the terminal:

```
## Upgrade Complete: @xh/hoist v{FROM} -> v{TO}

- **Versions upgraded:** {hop count}
- **Changes applied:** {total count}
- **Judgment calls:** {count} items requiring your review
- **Verification:** {tsc status}, {lint status}
- **hoist-core:** {bumped to vXX | unchanged | N/A}
- **Full report:** docs/upgrade-reports/upgrade-v{FROM}-to-v{TO}-{YYYY-MM-DD}.md
```

### 4. Offer PR creation

Check if the `gh` CLI is available:
```bash
gh --version
```

If available, offer to create a pull request:
> "Would you like me to create a pull request for this upgrade? (yes/no)"

If yes, use `gh pr create` with a title like "Upgrade @xh/hoist v{FROM} -> v{TO}" and include
the terminal summary as the PR body.

If `gh` is not available, skip this step silently.
