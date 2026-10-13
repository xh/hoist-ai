---
name: setup-hoist-dev-worktree
description: Create a multi-repo worktree set for Hoist framework development -- toolbox plus sibling hoist-react (default) and optionally hoist-core worktrees on one branch, with toolbox wired to run them inline on ports unique to the task.
allowed-tools: Read, Glob, Grep, Bash
disable-model-invocation: true
---

# Setup Hoist Dev Worktree

Recreate the sibling layout of the main checkouts under one task directory, so toolbox's
existing `../../hoist-react` and `../hoist-core` references resolve with no path edits:

    <xh-root>/worktrees/<slug>/
      toolbox/       always
      hoist-react/   default, omitted only for a toolbox-only task
      hoist-core/    only when the user asks for it

An omitted repo means toolbox uses the published artifact for it.

`setup-worktree`'s script provisions each repo, then one configure script wires up
toolbox. **Read `setup-worktree`'s SKILL.md** (`Glob` for `**/setup-worktree/SKILL.md`) - the per-repo
steps below reference its Phase 1 sections rather than repeating them.

## Phase 1: Resolve inputs

### 1. xh-root

Find the main checkout of the repo you are in, even from inside a worktree:

    dirname "$(git rev-parse --path-format=absolute --git-common-dir)"

If its basename is `toolbox`, `hoist-react`, or `hoist-core`, `<xh-root>` is its parent.
Otherwise ask. Every selected repo must exist as `<xh-root>/<repo>` - stop if one does not.

### 2. Repos

`toolbox` + `hoist-react` unless the user says otherwise. Add `hoist-core` only on request.

### 3. Branch

One branch name across all selected repos. If the user gives only a base, ask for the name.
Resolve new-vs-existing and the base ref **per repo**, following `setup-worktree`'s **Branch: new
or existing?** section. A branch can already exist on origin in hoist-react and be new in
toolbox. Report each repo's resolved ref and short SHA before creating anything.

`<slug>` is the branch with `/` replaced by `-`. Task dir: `<xh-root>/worktrees/<slug>`.

### 4. Adding a repo to an existing task

If the task dir already exists, provision only the repos missing from it, on the same branch,
then re-run Phase 3. Never re-provision a repo already present - that re-copies its `.env` over
the task's port and cluster settings.

Git refuses if the branch is checked out in that repo's main checkout or in another worktree.
If that happens, stop and tell the user. Do not pick another branch name.

### 5. Per-repo flags

Resolve each repo's flags against `<xh-root>/<repo>` with these `setup-worktree` Phase 1
sections: **Gitignored locals**, **Toolchain manager**, **Package manager**, and **Gradle
tooling task**. One exception: do not pass `--enable-plugin` for hoist-core. That repo does not
enable the plugin.

Warn the user that each JS repo gets its own full `node_modules` (a couple of GB each).

## Phase 2: Provision each repo

Run the provisioning script once per repo, as `setup-worktree`'s **Provision** phase describes.
Pass `--repo <xh-root>/<repo>`, `--dest <task-dir>/<repo>`, and the flags Phase 1 resolved.

Then, if `<xh-root>/toolbox/bin/hoist-docs` exists, install the hoist-react CLI launchers into
the toolbox worktree per `setup-worktree`'s **hoist-react CLI launchers** phase.

## Phase 3: Configure toolbox

`Glob` for `**/setup-hoist-dev-worktree/scripts/configure-dev-worktree.sh` and run it in place:

    bash "<script-path>" --task-dir "<task-dir>"

It detects which repos are present and, in the toolbox worktree only:

- Assigns a port slot unique among sibling task dirs (client `3000+N`, server `8080+N`).
- Disables multi-instance clustering, which also gives the instance a unique cluster name.
- Enables inline hoist-react (`XH_INLINE_HOIST`, tsconfig `paths`) and inline hoist-core
  (`runHoistInline`) for the repos present.

## Report

Relay the script's summary: slot, ports, run commands. Then tell the user:

- The script edits `client-app/tsconfig.json` and/or `gradle.properties` and marks them
  `--skip-worktree`, so they never show as changed. To commit a real change to one, first run
  `git update-index --no-skip-worktree <file>` and revert the inline toggle.
- Plain `pnpm start` runs inline - `startWithHoist` is not needed here.
- If `.env` sets an OAuth provider other than `NONE`, the callback for
  `localhost:<client-port>` may need registering with the provider.

## If it fails partway

Both scripts are idempotent. Fix the cause and re-run the failed step. Report what completed
and what did not.

`Cannot find a Java installation ... matching: {languageVersion=N}` means Gradle cannot see a
required JDK. Inline hoist-core adds hoist-core's own toolchain (`JavaLanguageVersion.of(N)` in
its `build.gradle`) on top of toolbox's `majorJavaVersion`, and Gradle does not auto-detect
mise-installed JDKs. Tell the user which JDK versions the build needs. The fix is theirs, for example
`org.gradle.java.installations.paths` in `~/.gradle/gradle.properties`.

## Out of scope

Teardown, and `@xh/hoist-dev-utils` inline development.
