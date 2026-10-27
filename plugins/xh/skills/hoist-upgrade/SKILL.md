---
name: hoist-upgrade
description: Upgrade a Hoist app's `@xh/hoist` dependency across one or more major versions. Reads per-version upgrade guides, auto-applies mechanical code migrations, flags judgment calls, checks the hoist-react version-compatibility matrix and bumps `@xh/hoist-dev-utils` when the target version requires or recommends it, bumps `hoistCoreVersion` (and refreshes the hoist-core MCP+CLI launchers if previously installed), and produces a comprehensive upgrade report.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, mcp__hoist-react__hoist-ping, mcp__hoist-react__hoist-search-docs, mcp__hoist-react__hoist-list-docs, mcp__hoist-react__hoist-read-doc, mcp__hoist-react__hoist-get-symbol, mcp__hoist-react__hoist-search-symbols, mcp__hoist-react__hoist-get-members
---

# Hoist Version Upgrade

Upgrade this Hoist project's `@xh/hoist` dependency between versions. Follow each phase in order.

## Phase 1: Detect

Gather project information needed to plan and execute the upgrade.

### 1. Parse arguments

Check `$ARGUMENTS` for an optional target version (e.g. `81.0.0` or `v81`). If present, normalize
it: strip any leading `v`, store as the target version for Phase 2. If no argument is provided,
the skill will prompt the developer to choose a target in Phase 2.

### 2. Detect package manager

Check which lockfile exists in `client-app/`:
- `yarn.lock` -- use `yarn` (e.g. `yarn install`, `yarn why`, `yarn lint`)
- `package-lock.json` -- use `npm` (e.g. `npm install`, `npm ls`, `npm run lint`)
- `pnpm-lock.yaml` -- use `pnpm` (e.g. `pnpm install`, `pnpm why`, `pnpm lint`). Note that pnpm
  apps require `@xh/hoist-dev-utils` >= 14 (see Phase 3f).

Store the detected package manager. All frontend commands in subsequent phases should be run
from `client-app/` using this package manager.

### 3. Detect current @xh/hoist version

Read `client-app/package.json`. Find `@xh/hoist` in `dependencies` and extract the current
version. Handle version strings like `^82.0.0-SNAPSHOT` -- extract the numeric portion
(e.g. `82.0.0`).

The spec can be an npm dist-tag such as `next` instead of a version range. Then the app is in
**canary mode**: it tracks hoist-react SNAPSHOTs, which publish under the `next` tag. The spec
has no version to extract. Read the installed version from
`client-app/node_modules/@xh/hoist/package.json`. If dependencies are not installed, use the
lockfile's resolved version (for pnpm, `importers` -> `.` -> `dependencies` -> `'@xh/hoist'` ->
`version`). Record canary mode for Phase 2.

If `@xh/hoist` is not a direct dependency, it may be pulled in transitively via a client plugin.
Run from `client-app/`:
- Yarn: `yarn why @xh/hoist`
- npm: `npm ls @xh/hoist`
- pnpm: `pnpm why @xh/hoist`

If neither approach finds `@xh/hoist`, inform the user:
> "This does not appear to be a Hoist project -- `@xh/hoist` was not found as a direct or
> transitive dependency."

Then stop.

### 4. Detect current @xh/hoist-dev-utils version

From the same `client-app/package.json`, find `@xh/hoist-dev-utils` in `devDependencies` and
extract the current version. This is the app's build tooling and it is version-paired with
hoist-react -- some hoist-react releases require or recommend a newer dev-utils, and a mismatch
fails at build / dev-server time rather than runtime. Store the version for the compatibility
check in Phase 2.

### 5. Check for dirty working tree

Run:
```bash
git status --porcelain
```

If output is non-empty, warn the developer:
> "Your working tree has uncommitted changes. Please commit or stash them before running the
> upgrade to ensure a clean rollback point if needed."

Do NOT proceed with any modifications until the working tree is clean.

### 6. Read hoist-core version

Read `gradle.properties` at the project root. Extract the `hoistCoreVersion` value.

If the version is not set directly (e.g. it is inherited from a client-specific Grails plugin
dependency), check `build.gradle` for the plugin dependency and note the transitive hoist-core
version if determinable.

**Assess server-side significance:** Check `CLAUDE.md` for notes about server-side complexity.
Also scan the Grails app package (e.g. `grails-app/controllers/`, `grails-app/services/`) for
custom controllers and services. If extensive custom server code is present, note this -- it
means hoist-core version bumps warrant extra attention in the upgrade report.

### 7. Detect client plugins

Scan `client-app/package.json` dependencies for packages that are NOT `@xh/hoist` but appear to
be Hoist-related client plugins (e.g. `@client/hoist-plugin`, `@client/hoist-*`).

Also read `CLAUDE.md` for any documented plugin-to-Hoist version mapping or plugin notes.

When a client plugin is detected, note the package name, current version, and any version
mapping information for use in Phase 2 planning.


## Phase 2: Plan

Present the upgrade plan for developer confirmation. Do NOT make any changes until the developer
confirms.

### 1. Determine target version

If a target version was provided via arguments in Phase 1, use it.

**Canary mode.** A dist-tag spec is a deliberate choice to track SNAPSHOTs. Do not treat it as
a version string to bump. Run `npm view @xh/hoist dist-tags` to see where `next` and `latest`
point, then ask the developer which path they want:
- **Stay on canary:** re-resolve `next` to its current SNAPSHOT and apply the migrations for
  every major it crosses. The spec stays `next`.
- **Move to a stable release:** pick a target from the list below. The spec becomes a caret
  range. If the target is older than the installed SNAPSHOT, warn that this is a downgrade.

Wait for the developer to choose before continuing.

If no target version was specified, query npm for available versions:
```bash
npm view @xh/hoist versions --json
```

`npm view` is a registry-query command -- it works in any Node.js environment regardless of
which package manager the project uses, since `npm` ships with Node itself. No need to route
through the project's detected manager here.

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

On the canary path, the target is the version `next` resolves to. The tag cannot install
intermediate majors, so Phase 3 installs once and applies each hop's guide in order. The
installed package carries the upgrade notes for every earlier major. A SNAPSHOT may ship a
partial guide for its own major, or none yet. If `next` resolves within the installed major,
there is one hop. Read the breaking changes for that major at the top of the installed
`CHANGELOG.md`.

### 3. Check version compatibility (hoist-core AND hoist-dev-utils)

hoist-react ships a compatibility reference, `docs/version-compatibility.md`, with matrices
pairing each hoist-react release with its required/recommended **hoist-core** and
**hoist-dev-utils** versions. Retrieve it via either path:

- MCP: `hoist-read-doc` with id `docs/version-compatibility.md` (`@xh/hoist` v86+)
- Filesystem: Read `client-app/node_modules/@xh/hoist/docs/version-compatibility.md`

At plan time both paths serve the *currently installed* hoist-react's copy, which may not yet
include rows for the target version -- re-check from `node_modules` after each hop's install
(Phase 3f), when the target's copy is on disk. Apps on older hoist-react may not have the doc
at all (it first shipped in the v82 era), or may have a copy that predates its dev-utils
tables. If the doc or its dev-utils section is missing at plan time, note that in the plan
and rely on the per-hop post-install check in Phase 3f.

For the target version (and each intermediate hop), note:
- **hoist-core:** Min Core Required / Recommended Core vs the current `hoistCoreVersion`.
- **hoist-dev-utils:** Min Dev-Utils Required / Recommended Dev-Utils vs the app's current
  `@xh/hoist-dev-utils` (Phase 1). Also check the doc's reverse-lookup table -- each dev-utils
  major sets its own minimum hoist-react and may raise the minimum Node version.

Record any required or recommended bumps for the plan display below.

### 4. Check guide availability

For each hop in the sequence, check if a dedicated upgrade guide exists. Use Glob to look for:
```
client-app/node_modules/@xh/hoist/docs/upgrade-notes/v*-upgrade-notes.md
```

Match each hop's target version against the available files. If a guide does NOT exist for a
particular hop's target version (versions before v73 will not have one), note that hop as
"CHANGELOG-only" and alert the developer:
> "Note: No dedicated upgrade guide exists for v{target}. This hop will use CHANGELOG entries
> only, and guidance may be less thorough."

### 5. Client plugin confirmation

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

### 6. Display the upgrade plan

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
- **hoist-dev-utils:** {current} -> {planned bump per compatibility matrix, or "no change required"}
- **Server complexity:** {Minimal (stock) | Significant (custom controllers/services)}
- **Client plugins:** {Detected plugins, or "None detected"}
- **Package manager:** {detected package manager}
```

### 7. Confirm with developer

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

Update the `@xh/hoist` version in `client-app/package.json` `dependencies` to the hop's target
version (e.g. `"@xh/hoist": "^{target}"`). Never write a caret range on a SNAPSHOT version.
Under pnpm it freezes to an exact pin that later updates cannot move. If the app tracks
SNAPSHOTs, the spec is `next`.

On the canary path, do this step for the first hop only. Leave the spec as `next` and
re-resolve it with the package manager's update command for the package:
- pnpm: `pnpm update @xh/hoist`
- yarn 1: `yarn upgrade @xh/hoist`
- yarn 2+: `yarn up @xh/hoist`
- npm: `npm update @xh/hoist`

Then confirm `package.json` still reads `next`, and restore it if the command rewrote it.

Run the detected package manager's install command from `client-app/` to update the lockfile
and install the new version.

Then remove duplicate packages. An in-place upgrade can leave an old copy of a package that the
new Hoist version needs at a newer version. `tsc` then fails inside Hoist with conflicting types.
- pnpm: `pnpm dedupe`, then `pnpm dedupe --check` to confirm.
- npm: `npm dedupe`.
- yarn 2+: `yarn dedupe`. Yarn 1 has no dedupe command. Use `npx yarn-deduplicate`, then
  `yarn install`.

**Important:** The upgrade notes for version N ship with version N. They are only available on
the filesystem after installing the target version. A guide may ask for its `package.json` and
build-config edits before the install. Because you already installed to read it, apply those
edits next, then re-run the install and dedupe.

### 3c. Read upgrade guide for this hop

Use the `Read` tool to read upgrade notes directly from the filesystem:
```
client-app/node_modules/@xh/hoist/docs/upgrade-notes/v{TARGET}-upgrade-notes.md
```

**Do NOT use the MCP doc tools for upgrade notes.** The MCP server may still be serving
the previous version's content after install. The `Read` tool always reflects the installed
version.

For versions WITHOUT upgrade notes (pre-v73): Read `client-app/node_modules/@xh/hoist/CHANGELOG.md` and
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
before/after code examples in the upgrade guide. For other lookups, use the hoist-react CLI from
`client-app/`: `npx hoist-ts search|symbol|members` and `npx hoist-docs search|read`. The CLI
reads the installed version on each call. The MCP server reads it only at startup, so until it
is reconnected in Phase 4, its docs and symbols describe the pre-upgrade version. Do not use
the MCP tools between the first install and that reconnect.

### 3e. Check and bump hoist-core version

Parse the upgrade guide's "Prerequisites" section for hoist-core version requirements (e.g.
"hoist-core >= v36.1"). Cross-check against the compatibility matrix rows noted in Phase 2 --
the guide and the matrix should agree; if they differ, honor the stricter requirement.

If a requirement is found, compare against the current `hoistCoreVersion` from
`gradle.properties` (read in Phase 1).

If the current version is below the requirement:
1. Bump `hoistCoreVersion` in `gradle.properties` to the required version.
2. Prominently note this change for the upgrade report.
3. If the project has significant server-side code (detected in Phase 1), add a prominent
   warning that the hoist-core upgrade may require additional server-side review.
4. **Refresh the hoist-core MCP+CLI launchers if they were previously installed.** Check
   whether `bin/hoist-core-mcp` exists at the project root. If it does, the launchers embed an
   absolute path to a version-suffixed JAR (e.g. `hoist-core-mcp-{old}-all.jar`) and are now
   stale. Re-run:
   ```bash
   ./gradlew installHoistCoreTools
   ```
   This refreshes the launchers to point at the new version's JAR. Verify with
   `./bin/hoist-core-docs ping` (returns `hoist-core CLI is running.`). Note the refresh in
   the upgrade report.
5. **Surface the install-eligibility transition** if relevant. If the bumped `hoistCoreVersion`
   is `>= 39.0` AND `bin/hoist-core-mcp` does NOT exist (i.e., the install task was never run
   here), the user is now eligible for the hoist-core MCP server + `hoist-core-docs` /
   `hoist-core-symbols` CLI tools (introduced in v39.0). Add a "Next Steps" item to the upgrade
   report: "Install the hoist-core MCP+CLI tools by running `/xh:onboard-app` -- onboarding
   will detect the new eligibility and offer to install."

### 3f. Check and bump hoist-dev-utils version

Read `client-app/node_modules/@xh/hoist/docs/version-compatibility.md` -- it now reflects this
hop's just-installed target version -- and compare the target's Min/Recommended Dev-Utils
against the app's current `@xh/hoist-dev-utils`. The upgrade guide's "Prerequisites" section
may also state a dev-utils requirement; honor the stricter of the two.

If a bump is required or recommended:
1. Update `@xh/hoist-dev-utils` in `client-app/package.json` `devDependencies` and re-run the
   install command from `client-app/`. The bump belongs in this hop's change -- package.json
   and lockfile land together in the hop commit.
2. Review breaking changes for the dev-utils versions being crossed. The published dev-utils
   package does NOT include its CHANGELOG, so use the version-compatibility doc's dev-utils
   reverse-lookup table -- it lists each major's minimum hoist-react, Node floor, and headline
   breaking changes. For full detail, fetch the CHANGELOG from GitHub if network access allows:
   `curl -s https://raw.githubusercontent.com/xh/hoist-dev-utils/develop/CHANGELOG.md`.
   dev-utils majors carry their own breaking changes: Node version floors, build-config
   changes up to a change of bundler, script and CI flag changes, and eslint-config migrations.
   Verify the local Node version satisfies any new floor (`node --version`) and record
   anything requiring app-side action as a judgment call.
3. If the app uses pnpm (or is adopting it as part of this upgrade): dev-utils >= 14 is
   required, and pnpm additionally requires the app to declare every package it imports
   directly -- phantom dependencies that yarn's hoisting concealed will fail to resolve.
4. Prominently note the bump for the upgrade report.

If the current dev-utils already satisfies the target's requirements, no action is needed.

### 3g. Handle client plugin version (if applicable)

If a client plugin was detected and the developer confirmed a version strategy in Phase 2:
1. Bump the client plugin version in `client-app/package.json` according to the confirmed strategy
2. Run the install command again from `client-app/` after the plugin version bump

### 3h. Commit this hop

```bash
git add -A
git commit -m "Upgrade @xh/hoist v{FROM} -> v{TO}"
```

On the canary path, the first hop's commit carries the `package.json` and lockfile changes.

### 3i. Progress reporting

After each hop, display a brief status showing progress through the sequence:

```
## Upgrade Progress: v{start} -> v{end}

[completed] v77 -> v78 (TRIVIAL) -- N changes applied, M judgment calls
[in progress] v78 -> v79 -- in progress...
[pending] v79 -> v80 -- pending
```

### 3j. Refresh agent docs (after the last hop)

The app's agent docs can still teach APIs that the upgrade removed. `CLAUDE.md` is the main
one. Also check `AGENTS.md`, `.claude/rules/`, and other docs written for agents.

1. Re-run the "find affected files" greps from each hop's guide against these docs. Fix each
   hit, or record it as a judgment call if the text is project-specific.
<!-- legacy-api:start -->
2. If `CLAUDE.md` holds the Hoist primer from `/xh:onboard-app` (an "Architecture Primer"
   heading), check that it matches the app's decorator style. The style is legacy if
   `client-app/tsconfig.json`, or a config it extends, sets `experimentalDecorators: true`.
   Otherwise it is TC39. Judge the primer by its HoistModel code example. If the example uses
   the other style, regenerate the "Architecture Primer" and "Models and Decorators" sections. `Glob` for
   `**/onboard-app/templates/claude-md-base.md`, and follow the merge rules in that skill's
   Phase 4 for an existing `CLAUDE.md`. Keep project-specific text, and show the developer the
   diff before writing.
<!-- legacy-api:end -->
3. Commit any changes on their own:
   ```bash
   git commit -am "Refresh agent docs for @xh/hoist v{TO}"
   ```

## Phase 4: Verify

After ALL hops are complete, run verification. The CLI surface is the always-on baseline (it
reads from `node_modules` and always reflects the upgraded version); MCP reconnect is
opportunistic and safe to skip in environments that block MCP.

### 1. Verify the upgraded developer-tools surfaces

**hoist-react CLI (universal, always run).** From `client-app/`, run:

```bash
npx hoist-docs index
```

This reads from `client-app/node_modules/@xh/hoist/...` and always reflects the just-installed
version. A clean docs index print confirms the upgraded surface is reachable. Surface any
errors before continuing.

**hoist-react MCP reconnect (only if MCP is part of your workflow).** The MCP server is still
serving the pre-upgrade version's types and docs. Prompt the developer:

> "If you use MCP in this environment, please run `/mcp` in Claude Code to reconnect the
> hoist-react server, then say 'continue'. If you don't use MCP (for example, in MCP-blocked
> enterprise environments), say 'skip' -- the CLI surface above is the working path and
> already reflects the upgrade."

After 'continue': call `mcp__hoist-react__hoist-ping` to confirm. After 'skip', or if the ping
fails or the tool isn't in your context, proceed without error -- the CLI verification above is
sufficient.

**hoist-core CLI (only if launchers were refreshed in Phase 3e).** If Phase 3e re-ran
`installHoistCoreTools`, run:

```bash
./bin/hoist-core-docs ping
```

Expect `hoist-core CLI is running.` This confirms the refresh produced working launchers
pointing at the new JAR. Surface any errors before continuing.

### 2. TypeScript compilation

Run from `client-app/`:
```bash
npx tsc --noEmit
```
Report pass/fail.

### 3. Lint

Run the project's lint command from `client-app/` using the detected package manager.
Report pass/fail.

### 4. Build, dev server, and tests

`tsc` and lint miss problems that only show up when the app builds, boots, or runs its tests.
Run these when any hop crossed a major version, or when `@xh/hoist-dev-utils` changed:

- **Production build.** Run the app's build script from `client-app/` (for example `pnpm build`).
  Report pass/fail.
- **Dev server.** Start the app's start script in the background. Wait until it reports a
  successful compile, or an error. Then stop it. Report pass/fail. If the developer can open
  the app, ask them to check the browser console for errors at startup.
- **Tests.** If the app has a unit or E2E test suite (for example a `test` or `test:e2e`
  script, or a Playwright config), run it. E2E tests may need the running app and server. Ask
  the developer before you start them. Report pass/fail per suite.

### 5. Guided verification

If the final version's upgrade guide includes a verification checklist, present it to the
developer and work through each item.

If verification fails, present the errors and work with the developer to resolve them before
proceeding to the report phase. If the dev server or a production build fails after the upgrade
(bundler or loader errors, dev-server startup failures), suspect a missed hoist-dev-utils
pairing first. dev-utils mismatches surface at build / dev-server time, not runtime. Re-check
the version-compatibility doc (Phase 2.3) and the app's build config before debugging app code.

### Verification cadence

For multi-hop upgrades where all hops are LOW or TRIVIAL difficulty, batch all verification at
the end. For hops rated MEDIUM or higher, consider running intermediate TypeScript compilation
checks after those hops to catch issues before they compound. Use your judgment based on the
difficulty ratings read from the upgrade guides.

## Phase 5: Report

Render a structured upgrade summary directly in the chat. Do NOT write a report file --
the conversation is the artifact. If the developer wants it persisted, they can copy it
or ask you to save it somewhere specific.

### 1. Render the summary

Print the following as a single Markdown response. Use short prose and lists; lean on
tables only where they genuinely help (e.g. the hop overview). Skip optional sections
when they don't apply.

```markdown
## Hoist Upgrade Complete: @xh/hoist v{FROM} -> v{TO}

- **Hops:** {N} ({comma-separated hop list, e.g. v77 -> v78, v78 -> v79})
- **Branch:** {branch name}
- **Package manager:** {yarn | npm | pnpm}
- **Spec:** {`^{TO}` | `next` (canary)}

### Hop Overview

| Hop | Difficulty | Changes | Judgment Calls | Status |
|-----|------------|---------|----------------|--------|
| v{a} -> v{b} | {TRIVIAL/LOW/MEDIUM/HIGH} | {n} | {n} | {ok / failed} |
| ...

### Per-Hop Detail

#### v{a} -> v{b} ({difficulty}, guide: {upgrade-notes | CHANGELOG})

**Mechanical changes applied:**
- `{file}` -- {what changed}
- ...

**Judgment calls (require your review):**
- **{item}** -- {one-line description}
  - Files: {comma-separated}
  - Guide recommendation: {recommendation}

{Repeat per hop. Omit empty subsections.}

### Verification

- TypeScript (`tsc --noEmit`): {pass | fail with brief detail}
- Lint: {pass | fail with brief detail}
- Production build: {pass | fail | not run}
- Dev server startup: {pass | fail | not run}
- Tests: {pass | fail per suite | no suite | not run}
- hoist-react CLI (`npx hoist-docs index`): {ok | error}
- hoist-react MCP reconnect: {reconnected | skipped | failed}
- hoist-core CLI (if launchers refreshed): {ok | error | N/A}

### hoist-core Changes
{Include only if hoistCoreVersion was bumped.}

- {old} -> {new} (required by {hop or guide reference})
- Launchers: {refreshed via installHoistCoreTools, ping verified | not previously installed -- skipped}
- {If significant server-side code was detected in Phase 1, add a one-line note that
  server-side review is recommended.}

### hoist-dev-utils Changes
{Include only if @xh/hoist-dev-utils was bumped.}

- {old} -> {new} (required/recommended for hoist-react v{version} per the compatibility matrix)
- {Note any new Node version floor or config changes from the dev-utils CHANGELOG.}

### Agent Docs
{Include only if Phase 3j changed anything.}

- {file}: {what changed, e.g. "regenerated the Hoist primer for TC39 decorators"}

### Client Plugin Notes
{Include only if client plugins were detected.}

- `{plugin}`: {old} -> {new or unchanged} -- {notes}

### Next Steps
- [ ] Review the judgment calls above and apply as appropriate
- [ ] Test affected features (especially anything in judgment calls)
- [ ] Run the app and verify core functionality
{Include if hoist-core was bumped:}
- [ ] Review hoist-core release notes if this project has significant server-side code
{Include if hoist-dev-utils was bumped across a major with a new Node floor:}
- [ ] Confirm CI / build agents meet the new minimum Node version
{Include if hoistCoreVersion >= 39.0 AND bin/hoist-core-mcp does NOT exist:}
- [ ] Install the hoist-core MCP+CLI tools now that you're eligible (>= v39.0):
      run `/xh:onboard-app` -- it will detect the new eligibility and offer to install
{Include if client plugins were detected:}
- [ ] Verify client plugin compatibility with the upgraded Hoist version
- [ ] Open / merge the pull request for this upgrade branch
```

Be honest in the verification section -- if `tsc` or lint failed and you and the developer
worked through the failures, summarize what was resolved. If something is still broken at
report time, say so plainly so the developer doesn't merge a half-green branch.
