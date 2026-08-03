---
name: setup-worktree
description: |
  Create a ready-to-run git worktree for a Hoist app -- new branch off the right base, gitignored locals restored, toolchain trusted, dependencies installed with the app's own package manager, server-side AI tooling regenerated. Why this matters: `git worktree add` checks out tracked files only, so a fresh Hoist worktree has no `.env` and no `.claude/settings.local.json` and the app won't start; the `bin/hoist-core-*` launchers embed an absolute JAR path, so copying them from the main checkout points them at the wrong tree; `mise` and `direnv` trust is keyed to a directory path and never transfers to a new one; running `npm install` in a yarn app writes a competing lockfile; and defaulting the base ref to the repo's default branch silently bases feature work on `master`/`main` when the integration branch is `develop`. TRIGGER when the user asks for a worktree ("worktree", "git worktree", "new worktree", "worktree off develop", "worktree for AS-1234"), for a separate or isolated checkout to work on something without disturbing the current one, or for a parallel workspace for a ticket or branch. SKIP when the user wants a branch in place (`git checkout -b`, `git switch -c`, "make a branch", "switch to branch") with no second directory -- provisioning a worktree there means an unwanted multi-GB dependency install. SKIP for removing, pruning, or listing existing worktrees.
allowed-tools: Read, Glob, Grep, Bash, Edit
---

# Setup Worktree

Create a git worktree for a Hoist app that is immediately runnable -- not just checked out.

Division of labor: **you resolve every decision, a bundled script does the mechanical work.**
The script never guesses and never prompts. Work through Phase 1 to gather the flags, then
hand off.

## Phase 0: Establish an absolute repo root

Do this first and use it everywhere. Your working directory is not guaranteed to be the app
root -- a skill can run from the plugin's install directory or any subdirectory -- so every
probe, `grep`, and flag below must use an absolute path rather than relying on cwd.

    git rev-parse --show-toplevel

If that fails, you're not in a git repository: stop and say so. Refer to the result as
`<repo>` throughout. The provisioning script rejects relative paths outright for this reason.

## Phase 1: Resolve inputs

Probe the **main checkout** for all of these -- the worktree doesn't exist yet. Do every bit
of detection before anything is created.

### 1. Per-app overrides

Read `<repo>/CLAUDE.md` and look for a `## Worktree provisioning` section. If present it is
authoritative -- it may name extra locals to copy, a toolchain, or post-install steps that
detection can't infer. Use it and let the steps below fill only what it doesn't specify.

### 2. New branch name and base ref

The user may supply one name, two, or none. "off of" / "from" / "based on" marks a **base**;
a bare name is the **new branch**. If only a base is given, ask what to call the new branch --
don't invent one.

Resolve the base ref in this order:

1. What the user asked for. A bare name like `foo` is ambiguous: prefer `origin/foo` (fetched,
   current) over a local `foo` that may be stale or ahead. If only a local branch exists, use
   it and say so.
2. `origin/develop` if it exists -- the integration branch in Hoist repos.
3. Otherwise refresh and use the repo's default: `git remote set-head origin --auto`, then
   `git symbolic-ref --short refs/remotes/origin/HEAD`. This ref is a cached snapshot of what
   the host reports and can be stale, which is why it ranks below `origin/develop`.
4. If neither resolves, stop and ask.

Report the resolved ref and its short SHA before creating anything. Basing off the wrong
branch is expensive to discover later.

A failed fetch is not fatal -- the script warns and proceeds from the last-fetched ref, which
keeps offline and VPN-down provisioning working. If you see that warning, surface it to the
user along with the base's commit date; don't let a silently stale base pass as current.

### 3. Destination

`<parent-of-repo>/<repo-name>-worktrees/<slug>`, an absolute path, where `<slug>` is the
branch name with `/` replaced by `-` (so `feature/foo` and `bugfix/foo` don't collide).
Worktrees live outside the repo -- nothing to gitignore, and `git worktree list` still tracks
them all.

### 4. Gitignored locals

Default set, copied from the main checkout:

- `.env`
- `.claude/settings.local.json`

Absent files are skipped with a notice, so it's safe to pass both unconditionally. Add
anything the `## Worktree provisioning` block names.

### 5. Toolchain manager

Detect against the main checkout. Both of these key trust to a directory path, so the new
worktree starts untrusted:

- **mise** -- if `mise` is on PATH, run `mise config ls` with cwd `<repo>`. Project-scoped
  entries mean the app is mise-managed. Probe this way rather than testing for `mise.toml`:
  the filename is configurable (`.mise.local.toml`, `.mise.<env>.toml`,
  `MISE_DEFAULT_CONFIG_FILENAME`, `override_config_filenames`), so a literal filename check
  can miss.
- **direnv** -- `<repo>/.envrc` exists.

If a config is present but the tool isn't on PATH, that's a broken machine setup: stop and say
which tool is missing. Don't skip silently -- Gradle will fail later with a confusing Java
error instead.

When you activate mise, mention once that per-worktree `mise trust` can be retired by adding
the worktrees parent to mise's `trusted_config_paths` (or `MISE_TRUSTED_CONFIG_PATHS`).
Note the tradeoff plainly: it auto-trusts any mise config appearing anywhere under that path,
including one arriving in a branch they just checked out.

### 6. Package manager

Dictated by the lockfile, never assumed:

- `<repo>/client-app/yarn.lock` → `client-app:yarn`
- `<repo>/client-app/package-lock.json` → `client-app:npm`
- No `<repo>/client-app/` (e.g. hoist-react itself): apply the same lockfile check at the repo
  root and use `.:yarn` / `.:npm`.
- Neither → skip dependency install and say so.

### 7. Gradle tooling task

`grep` `<repo>/build.gradle` for `installHoistCoreTools`. Pass the task **only** if the app
defines it -- not every Hoist app has installed the hoist-core tooling, and an undefined task
aborts the run after the multi-GB dependency install has already completed.

### 8. Warn about cost

Before starting, tell the user this creates a full dependency tree -- a Hoist app's
`client-app/node_modules` is a couple of GB per worktree.

## Phase 2: Provision

Locate the bundled script with `Glob`, pattern `**/setup-worktree/templates/provision-worktree.sh`,
and run it in place. Don't copy it into the app -- executing from the plugin means it upgrades
with the plugin, and avoids the content-mangling risk that copying executable text carries.

    bash "<script-path>" \
        --repo "<main-checkout>" \
        --dest "<destination>" \
        --branch "<new-branch>" \
        --base "<resolved-base-ref>" \
        --local .env \
        --local .claude/settings.local.json \
        --toolchain mise \
        --deps client-app:yarn \
        --gradle-task installHoistCoreTools \
        --verify-parity

`--repo` and `--dest` must be absolute -- the script rejects relative paths, because it runs
from the plugin directory and a relative path would resolve against that.

Include only the flags Phase 1 actually resolved. `--toolchain`, `--deps`, `--gradle-task` and
`--local` are all repeatable and all optional. Pass `--verify-parity` always -- it compares
`node` and `java` between the two checkouts and catches an activation that didn't carry over,
including from managers this skill doesn't detect (nvm, fnm, volta, asdf, nix).

Read the script's header comment if you need the full flag contract.

## Phase 3: hoist-react CLI launchers

`bin/hoist-docs` and `bin/hoist-ts` are gitignored in most apps, so the worktree won't have
them. If `<repo>/bin/hoist-docs` exists, the dev uses that surface and the worktree needs it
too.

Install them via the **Installing the CLI launchers** procedure in the
`using-hoist-react-reference` skill -- a `Glob` for the canonical templates plus `Bash cp`.
Don't copy the main checkout's copies: they may be stamped at an older
`# hoist-ai-launcher: hoist-react/v<N>` version, and copying propagates the drift.

The hoist-core launchers (`bin/hoist-core-*`) need nothing here -- `installHoistCoreTools` in
Phase 2 regenerates them with this worktree's absolute JAR path.

## When bash isn't available

On Windows without bash, don't improvise. `Read` the script, follow its numbered steps in
order, and translate each to the local shell. The step ordering is load-bearing: toolchain
before dependency install before Gradle, because mise supplies the Node and Java the later
steps need.

## If it fails partway

Every step is idempotent and the script adopts an existing worktree at `--dest`, so fix the
cause and re-run the same command -- it resumes rather than starting over. Report what
completed and what didn't; never leave a half-provisioned worktree described as ready.

## Out of scope

Removing or cleaning up worktrees. If the user asks, use `git worktree remove` directly and
confirm before deleting anything with uncommitted work.
