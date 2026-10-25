# Phase 1: Detect

Gather project information needed to plan and execute the upgrade. Step 1, parsing the
arguments, is in SKILL.md.

## 2. Detect package manager

Check which lockfile exists in `client-app/`:
- `yarn.lock` -- use `yarn` (e.g. `yarn install`, `yarn why`, `yarn lint`)
- `package-lock.json` -- use `npm` (e.g. `npm install`, `npm ls`, `npm run lint`)
- `pnpm-lock.yaml` -- use `pnpm` (e.g. `pnpm install`, `pnpm why`, `pnpm lint`). Note that pnpm
  apps require `@xh/hoist-dev-utils` >= 14 (see Phase 3f).

Store the detected package manager. All frontend commands in subsequent phases should be run
from `client-app/` using this package manager.

## 3. Detect current @xh/hoist version

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

## 4. Detect current @xh/hoist-dev-utils version

From the same `client-app/package.json`, find `@xh/hoist-dev-utils` in `devDependencies` and
extract the current version. This is the app's build tooling and it is version-paired with
hoist-react -- some hoist-react releases require or recommend a newer dev-utils, and a mismatch
fails at build / dev-server time rather than runtime. Store the version for the compatibility
check in Phase 2.

## 5. Check for dirty working tree

Run:
```bash
git status --porcelain
```

If output is non-empty, warn the developer:
> "Your working tree has uncommitted changes. Please commit or stash them before running the
> upgrade to ensure a clean rollback point if needed."

Do NOT proceed with any modifications until the working tree is clean.

## 6. Read hoist-core version

Read `gradle.properties` at the project root. Extract the `hoistCoreVersion` value.

If the version is not set directly (e.g. it is inherited from a client-specific Grails plugin
dependency), check `build.gradle` for the plugin dependency and note the transitive hoist-core
version if determinable.

**Assess server-side significance:** Check `AGENTS.md` and `CLAUDE.md` for notes about
server-side complexity.
Also scan the Grails app package (e.g. `grails-app/controllers/`, `grails-app/services/`) for
custom controllers and services. If extensive custom server code is present, note this -- it
means hoist-core version bumps warrant extra attention in the upgrade report.

## 7. Detect client plugins

Scan `client-app/package.json` dependencies for packages that are NOT `@xh/hoist` but appear to
be Hoist-related client plugins (e.g. `@client/hoist-plugin`, `@client/hoist-*`).

Also read `AGENTS.md` and `CLAUDE.md` for any documented plugin-to-Hoist version mapping or
plugin notes.

When a client plugin is detected, note the package name, current version, and any version
mapping information for use in Phase 2 planning.
