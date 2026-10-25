# Phase 3: Execute

For each version hop in the sequence, apply the upgrade. Never commit directly to main or
develop.

## 3a. Branch setup (first hop only)

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

## 3b. Bump version and install

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

## 3c. Read upgrade guide for this hop

Read the upgrade notes directly from the filesystem:
```
client-app/node_modules/@xh/hoist/docs/upgrade-notes/v{TARGET}-upgrade-notes.md
```

**Do NOT use the MCP doc tools for upgrade notes.** The MCP server may still be serving
the previous version's content after install. A file read always reflects the installed
version.

For versions WITHOUT upgrade notes (pre-v73): Read `client-app/node_modules/@xh/hoist/CHANGELOG.md` and
parse the `Breaking Changes` section for the target version. Alert the developer:
> "No dedicated upgrade guide exists for this version. Using CHANGELOG breaking changes section.
> Guidance may be less thorough for this hop."

## 3d. Apply migrations

Read the upgrade guide carefully. For each migration step:

**Mechanical changes** (renames, import updates, CSS class changes):
1. Use the grep commands from the upgrade guide to find affected files in the project
2. Apply the changes to each file
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

## 3e. Check and bump hoist-core version

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
   report: "Install the hoist-core MCP+CLI tools by running the `onboard-app` skill --
   onboarding will detect the new eligibility and offer to install."

## 3f. Check and bump hoist-dev-utils version

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

## 3g. Handle client plugin version (if applicable)

If a client plugin was detected and the developer confirmed a version strategy in Phase 2:
1. Bump the client plugin version in `client-app/package.json` according to the confirmed strategy
2. Run the install command again from `client-app/` after the plugin version bump

## 3h. Commit this hop

```bash
git add -A
git commit -m "Upgrade @xh/hoist v{FROM} -> v{TO}"
```

On the canary path, the first hop's commit carries the `package.json` and lockfile changes.

## 3i. Progress reporting

After each hop, display a brief status showing progress through the sequence:

```
## Upgrade Progress: v{start} -> v{end}

[completed] v77 -> v78 (TRIVIAL) -- N changes applied, M judgment calls
[in progress] v78 -> v79 -- in progress...
[pending] v79 -> v80 -- pending
```

## 3j. Refresh agent docs (after the last hop)

The app's agent docs can still teach APIs that the upgrade removed. `AGENTS.md` and `CLAUDE.md`
are the main ones. Also check `.claude/rules/`, `.cursor/rules/`, and other docs written for
agents.

1. Re-run the "find affected files" greps from each hop's guide against these docs. Fix each
   hit, or record it as a judgment call if the text is project-specific.
<!-- legacy-api:start -->
2. If `AGENTS.md` or `CLAUDE.md` holds the Hoist primer from the `onboard-app` skill (an
   "Architecture Primer" heading), check that it matches the app's decorator style. The style is legacy if
   `client-app/tsconfig.json`, or a config it extends, sets `experimentalDecorators: true`.
   Otherwise it is TC39. Judge the primer by its HoistModel code example. If the example uses
   the other style, regenerate the "Architecture Primer" and "Models and Decorators" sections.
   From the hoist-upgrade skill folder, build them with `../onboard-app/scripts/build-agents-md.mjs`
   and follow the merge rules in `../onboard-app/reference/agent-docs.md`. Keep project-specific
   text, and show the developer the diff before writing.
<!-- legacy-api:end -->
3. Commit any changes on their own:
   ```bash
   git commit -am "Refresh agent docs for @xh/hoist v{TO}"
   ```
