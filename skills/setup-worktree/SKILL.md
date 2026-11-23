---
name: setup-worktree
description: |
  Create a ready-to-run git worktree for a Hoist app: a new branch off the right base, gitignored locals restored, toolchain trusted, dependencies installed with the app's own package manager, and server-side AI tooling regenerated. Why this matters: `git worktree add` checks out tracked files only, so a fresh Hoist worktree has no `.env` and no `.claude/settings.local.json`, and the app won't start. The `bin/hoist-core-*` launchers embed an absolute JAR path, so copies from the main checkout point at the wrong tree. `mise` and `direnv` trust is keyed to a directory path and never transfers. `npm install` in a yarn app writes a competing lockfile. A base taken from the repo's default branch silently puts feature work on `master` or `main` when the integration branch is `develop`. TRIGGER when the user asks for a worktree ("worktree", "git worktree", "new worktree", "worktree off develop", "worktree for AS-1234"), for a separate or isolated checkout to work on something without disturbing the current one, or for a parallel workspace for a ticket or branch. SKIP when the user wants a branch in place (`git checkout -b`, `git switch -c`, "make a branch", "switch to branch") with no second directory, because a worktree there means an unwanted full dependency install. SKIP for removing, pruning, or listing existing worktrees.
allowed-tools: Read, Glob, Grep, Bash, Edit
---

# Setup Worktree

Create a git worktree for a Hoist app that runs right away, not just a checkout.

A bundled script does the work. It detects every fact: the base ref, the destination, the
gitignored locals, the toolchain manager, the package manager, the Gradle tooling task, and the
hoist-react CLI launchers. Your job is to read the request: which branch, and whether it is new
or already exists.

## Step 1: Find the repo

Run `git rev-parse --show-toplevel` and use the result as `<repo>`. If it fails, you are not in
a git repository: stop and say so.

Your working directory can be the plugin folder or a subdirectory, so always pass `<repo>` to
the script as an absolute path. The script resolves a linked worktree to its main checkout.

## Step 2: Read the request

- "off of", "from", and "based on" mark a **base**. A bare name is the **branch** for the
  worktree.
- If the user gives only a base, ask what to call the new branch. Do not invent a name.
- If the user wants to work on a branch that already exists, pass `--existing-branch`. Typical
  cases: resume a ticket, pick up a pushed branch, review a colleague's work. The script
  fast-forwards a stale local branch to its remote before it installs anything.
- Otherwise the branch is new. Pass `--base <ref>` only when the user named a base. The script
  resolves the default: `origin/develop`, else the remote default branch.

You do not need to check whether the branch exists. The script checks, and it stops with exit
code 3 when the request conflicts with the repo.

## Step 3: Dry run

Find the script with `Glob`, pattern `**/setup-worktree/scripts/provision-worktree.sh`. Run it
in place. Do not copy it into the app.

    bash "<script>" --repo "<repo>" --branch "<branch>" [--base "<ref>" | --existing-branch] --dry-run

The dry run fetches origin, prints the plan to stderr, and creates nothing. Act on the exit
code:

| Code | Meaning | Action |
|------|---------|--------|
| 0 | Plan resolved | Show the user the base ref, its SHA and date, and the destination. Continue. |
| 3 | Needs a decision | Relay the message and ask the user. Re-run with their answer. |
| 1 | Failed | Report the error. A tool missing from PATH is the usual cause. |
| 2 | Usage error | Fix the command. |

On exit 3, never decide for the user. For example, if the new branch already exists, do not
check it out silently and do not invent a variant name.

If the output has a fetch WARNING, tell the user the base may be stale and give its commit date.
If the plan has a `note:` about disk use, relay it.

## Step 4: Provision

Run the same command without `--dry-run`. The install and Gradle steps take minutes. On success,
stdout holds only the worktree path.

Report the path, the branch, and the base. Also report every WARNING line, such as a node or
java version mismatch, or a plugin entry the script could not write. A branch WARNING means the
script did not update an existing branch that is behind its remote. The branch diverged, or the
worktree has uncommitted changes. Tell the user the install ran on the older code.

A WARNING that `settings.local.json` enables `xh@hoist-ai` means the main checkout's local
settings carried that entry into the worktree. Offer to remove the entry from both files.

## Step 5: Check the plugin install

A session in the new worktree loads the `xh` plugin only from a user-scope install. A project or
local install covers one path, so it does not reach the worktree. Run `claude plugin list --json`
and look for a record with `id` `xh@hoist-ai` and `scope` `user`. If there is none, tell the user
that sessions in the worktree will not have the `xh` skills. Give them
`claude plugin install xh@hoist-ai --scope user` and offer to run it for them. If `claude` is not
on the `PATH`, give the command and skip the check.

## Overrides

Detection covers most apps. Pass an override only when the user asks for something else or the
plan shows a wrong fact. Run the script with `--help` for the full contract.

| Flag | Effect |
|------|--------|
| `--dest <abs path>` | Use another destination. Default: `<repo>-worktrees/<branch>` next to the repo. |
| `--local <relpath>` | Copy one more gitignored file. Adds to the detected set. |
| `--enable-plugin <id>` | Enable a plugin in the worktree's `.claude/settings.local.json`. None by default. The `xh@hoist-ai` plugin comes from its user-scope install. |
| `--toolchain`, `--deps`, `--gradle-task` | Replace detection for that step. |
| `--skip <step>` | Skip a step: `locals`, `plugin`, `toolchain`, `deps`, `gradle`, `launchers`, or `parity`. |

If a repo always needs extra locals, suggest a `.worktreeinclude` file in the repo root. It uses
gitignore syntax. The script copies each gitignored file that matches it, as Claude Code does.

The script runs `mise trust` in each new worktree. If the user wants to skip that trust for
worktrees made some other way, they can add the worktrees folder to mise's
`trusted_config_paths`. Name the tradeoff: mise then trusts any config under that folder,
including one that arrives on a branch they check out.

## If it fails partway

Fix the cause and re-run the same command. Every step is idempotent, and the script adopts the
worktree at the destination, so it resumes. Report what completed and what did not. Never call a
half-provisioned worktree ready.

## Out of scope

Removing worktrees. If the user asks, use `git worktree remove` directly. Confirm before you
delete anything with uncommitted work.
