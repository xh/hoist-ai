#!/usr/bin/env bash
# hoist-ai-script: setup-worktree/v1
#
# Provision a ready-to-run git worktree for a Hoist app.
#
# This script performs only MECHANICAL work. All judgment -- which base ref to use,
# how to interpret an ambiguous branch name, which package manager the app uses,
# whether the app defines the hoist-core tooling task -- is resolved by the calling
# agent and passed in as explicit flags. The script never guesses and never prompts.
#
# It is also the canonical SPEC for what worktree provisioning means in a Hoist app.
# On a platform where it can't run (Windows without bash), read it and perform the
# equivalent steps directly rather than inventing a procedure.
#
# Every step is idempotent, so a re-run after a mid-way failure resumes rather than
# starting over: an existing worktree at --dest is adopted, and locals/deps/tooling
# are re-applied harmlessly.
#
# Usage:
#   provision-worktree.sh --repo <path> --dest <path> --branch <name> --base <ref> [options]
#
# Both --repo and --dest must be ABSOLUTE paths. The script is executed from wherever the
# caller happens to be -- typically the plugin's install directory, not the app -- and a
# relative path would resolve against that unrelated cwd. `git -C <repo> worktree add` would
# additionally resolve a relative dest against the repo rather than the cwd, and
# `git worktree list` reports absolute paths, so relative input silently breaks the
# already-exists check. Relative paths are rejected rather than guessed at.
#
# Required:
#   --repo <path>          Absolute path to the main checkout to provision from (source of
#                          the gitignored locals).
#   --dest <path>          Absolute path to create the worktree at. Must not be an existing
#                          non-worktree directory.
#   --branch <name>        Branch for the worktree. By default a NEW branch, created with
#                          --no-track so it never auto-tracks a long-lived branch (which
#                          would risk a surprise push or merge onto it). With
#                          --existing-branch, a branch that already exists instead.
#   --base <ref>           Fully-resolved ref to branch from, e.g. `origin/develop`. The
#                          caller resolves this; the script uses it verbatim. Required
#                          unless --existing-branch is passed, and rejected when it is.
#
# Options:
#   --existing-branch      Check out a branch that already exists rather than creating one.
#                          A local branch is checked out as-is and keeps whatever upstream
#                          it already had. A branch that exists only on origin gets a local
#                          branch tracking it -- the point of checking out an existing
#                          branch is to work on that branch, so push/pull should behave.
#                          Reports how far the branch is behind/ahead of its upstream.
#                          Errors if the branch exists in neither place; git itself errors
#                          (before any other work) if it's checked out in another worktree.
#   --local <relpath>      Gitignored file to copy from --repo into the worktree.
#                          Repeatable. `git worktree add` populates only TRACKED files,
#                          so without this a Hoist app has no .env and will not start.
#                          Absent files are skipped with a notice (not an error).
#   --toolchain <name>     Path-scoped toolchain manager to activate in the new
#                          directory: `mise` or `direnv`. Repeatable. Trust in both
#                          tools is keyed to the config file's PATH, so a new worktree
#                          is untrusted by construction. If the named tool is not on
#                          PATH this is a hard error -- a missing toolchain manager
#                          means Java/Node resolve wrongly and later steps fail
#                          confusingly.
#   --deps <dir>:<pm>      Install dependencies in <dir> (relative to the worktree)
#                          using <pm> (`yarn` or `npm`). Typically `client-app:yarn`.
#                          Repeatable. Runs AFTER --toolchain so the pinned Node is
#                          already active.
#   --gradle-task <name>   Gradle task to run in the worktree, e.g.
#                          `installHoistCoreTools`. Repeatable. Runs after --toolchain
#                          so Gradle finds the pinned Java. Only pass a task the caller
#                          has confirmed the app actually defines.
#   --verify-parity        After provisioning, compare `node`/`java` versions between
#                          --repo and --dest and warn on mismatch. Catches a toolchain
#                          manager that silently failed to activate in the new path.
#   -h, --help             Print this usage.
#
set -euo pipefail

SCRIPT_NAME="provision-worktree.sh"

REPO=""
DEST=""
BRANCH=""
BASE=""
BASE_SHA=""   # set only when we create the worktree; empty on the adopt-existing path
UPSTREAM=""   # set only in --existing-branch mode, when the branch has one
EXISTING_BRANCH=0
LOCALS=()
TOOLCHAINS=()
DEPS=()
GRADLE_TASKS=()
VERIFY_PARITY=0

die() {
    echo "${SCRIPT_NAME}: error: $*" >&2
    exit 1
}

usage() {
    sed -n '2,/^set -euo/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//; $d'
}

# A failed fetch is NOT fatal. Offline, VPN down, or missing credentials for this remote
# shouldn't block provisioning when the refs we need are already present locally -- it only
# means they may be behind. Warn loudly; the base commit date (create mode) and ahead/behind
# counts (existing-branch mode) printed later show how stale things actually are.
fetch_remote() {
    local remote="$1"
    git -C "$REPO" remote | grep -qxF "$remote" || return 0
    echo "==> Fetching $remote..."
    if ! git -C "$REPO" fetch "$remote"; then
        echo "    WARNING: fetch of '$remote' failed (offline, or no credentials for this" >&2
        echo "    remote). Continuing from last-fetched refs -- check the SHA/date or" >&2
        echo "    ahead/behind counts below before relying on them." >&2
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo)         REPO="${2:-}"; shift 2 ;;
        --dest)         DEST="${2:-}"; shift 2 ;;
        --branch)       BRANCH="${2:-}"; shift 2 ;;
        --base)         BASE="${2:-}"; shift 2 ;;
        --local)        LOCALS+=("${2:-}"); shift 2 ;;
        --toolchain)    TOOLCHAINS+=("${2:-}"); shift 2 ;;
        --deps)         DEPS+=("${2:-}"); shift 2 ;;
        --gradle-task)  GRADLE_TASKS+=("${2:-}"); shift 2 ;;
        --existing-branch) EXISTING_BRANCH=1; shift ;;
        --verify-parity) VERIFY_PARITY=1; shift ;;
        -h|--help)      usage; exit 0 ;;
        *)              die "unknown argument '$1' (try --help)" ;;
    esac
done

[[ -n "$REPO"   ]] || die "--repo is required"
[[ -n "$DEST"   ]] || die "--dest is required"
[[ -n "$BRANCH" ]] || die "--branch is required"

if [[ $EXISTING_BRANCH -eq 1 ]]; then
    [[ -z "$BASE" ]] \
        || die "--base is not valid with --existing-branch (the branch already has its own history)"
else
    [[ -n "$BASE" ]] \
        || die "--base is required (or pass --existing-branch to check out a branch that already exists)"
fi

# Reject relative paths outright -- see the header note. The cwd this script runs in is not
# related to the app, so resolving against it would silently target the wrong tree.
[[ "$REPO" == /* ]] || die "--repo must be an absolute path, got '$REPO'"
[[ "$DEST" == /* ]] || die "--dest must be an absolute path, got '$DEST'"

[[ -d "$REPO/.git" || -f "$REPO/.git" ]] || die "--repo '$REPO' is not a git checkout"

# Validate every repeatable flag's VALUE before creating anything. Step 1 below creates the
# worktree, and a typo in a flag consumed by a later step must not leave a half-created
# worktree behind for the caller to clean up.
if [[ ${#TOOLCHAINS[@]} -gt 0 ]]; then
    for tc in "${TOOLCHAINS[@]}"; do
        case "$tc" in
            mise|direnv)
                # A config present but the tool missing means a broken machine setup. Fail
                # loudly here rather than skipping, or Node/Java resolve wrongly and the
                # dependency install or Gradle fails later with an unrelated-looking error.
                command -v "$tc" >/dev/null 2>&1 \
                    || die "app is ${tc}-managed but '${tc}' is not on PATH -- fix the machine setup" ;;
            *)
                die "unknown --toolchain '$tc' (expected 'mise' or 'direnv')" ;;
        esac
    done
fi

if [[ ${#DEPS[@]} -gt 0 ]]; then
    for spec in "${DEPS[@]}"; do
        [[ "$spec" == *:* ]] || die "--deps expects <dir>:<pm>, got '$spec'"
        case "${spec##*:}" in
            yarn|npm) ;;
            *) die "unknown package manager '${spec##*:}' in --deps '$spec' (expected 'yarn' or 'npm')" ;;
        esac
    done
fi

# Collapse any symlinks/`..` so `git worktree list` comparisons below are meaningful.
REPO="$(cd "$REPO" && pwd -P)"

# ---------------------------------------------------------------------------
# Step 1: create the worktree (or adopt an existing one, so re-runs resume).
# ---------------------------------------------------------------------------

# Resolve --dest through any symlinks BEFORE comparing it against `git worktree list`, which
# reports fully-resolved paths. On macOS /tmp is a symlink to /private/tmp, so an unresolved
# spelling of an existing worktree would fail to match and then get misreported as a foreign
# directory we refuse to touch -- breaking resume. Only possible once the directory exists; a
# not-yet-created dest has nothing to match against anyway.
if [[ -d "$DEST" ]]; then
    DEST="$(cd "$DEST" && pwd -P)"
fi
if git -C "$REPO" worktree list --porcelain | grep -qxF "worktree $DEST"; then
    echo "==> Worktree already present at $DEST -- adopting it and continuing."
elif [[ -e "$DEST" ]]; then
    die "'$DEST' exists but is not a worktree of $REPO -- refusing to touch it"
elif [[ $EXISTING_BRANCH -eq 1 ]]; then
    # Check out a branch that already exists rather than creating one. Fetch first, so a
    # branch that so far exists only on the remote is visible, and so the ahead/behind
    # report below reflects the current remote state rather than the last sync.
    fetch_remote origin
    mkdir -p "$(dirname "$DEST")"

    if git -C "$REPO" show-ref --verify --quiet "refs/heads/$BRANCH"; then
        echo "==> Creating worktree $DEST"
        echo "    checking out existing local branch '$BRANCH'..."
        # An existing local branch keeps whatever upstream it already had. The --no-track
        # guard below applies only to branches this script creates.
        git -C "$REPO" worktree add "$DEST" "$BRANCH"
    elif git -C "$REPO" show-ref --verify --quiet "refs/remotes/origin/$BRANCH"; then
        echo "==> Creating worktree $DEST"
        echo "    creating local '$BRANCH' tracking origin/$BRANCH..."
        # No local branch to inherit tracking from, so set it explicitly. Tracking the
        # branch's OWN counterpart is right here: the reason to check out an existing branch
        # is to work on that branch, so push/pull should behave. Deliberately unlike the
        # create path's --no-track, which exists to stop a brand-new feature branch from
        # tracking a long-lived integration branch.
        git -C "$REPO" worktree add --track -b "$BRANCH" "$DEST" "origin/$BRANCH"
    else
        die "branch '$BRANCH' exists neither locally nor on origin -- drop --existing-branch to create it from a base ref"
    fi
else
    # Only fetch when basing off a remote-tracking ref, so the branch starts from the latest
    # origin state. A purely local base ref needs no network round-trip.
    if [[ "$BASE" == */* && "$BASE" != .* ]]; then
        fetch_remote "${BASE%%/*}"
    fi

    git -C "$REPO" rev-parse --verify --quiet "$BASE^{commit}" >/dev/null \
        || die "base ref '$BASE' does not resolve to a commit"

    BASE_SHA="$(git -C "$REPO" rev-parse --short "$BASE")"
    BASE_DATE="$(git -C "$REPO" log -1 --format=%cs "$BASE")"
    echo "==> Creating worktree $DEST on new branch '$BRANCH'"
    echo "    off $BASE ($BASE_SHA, committed $BASE_DATE)..."
    mkdir -p "$(dirname "$DEST")"
    git -C "$REPO" worktree add "$DEST" -b "$BRANCH" --no-track "$BASE"
fi

DEST="$(cd "$DEST" && pwd -P)"

# In existing-branch mode the branch carries history that may already be behind its remote.
# Checking out a stale branch silently is the same class of mistake as basing new work on a
# stale ref, so report the divergence rather than leaving it to be discovered later.
if [[ $EXISTING_BRANCH -eq 1 ]]; then
    UPSTREAM="$(git -C "$DEST" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
    if [[ -n "$UPSTREAM" ]]; then
        COUNTS="$(git -C "$DEST" rev-list --left-right --count "$UPSTREAM...HEAD" 2>/dev/null || true)"
        if [[ -n "$COUNTS" ]]; then
            set -- $COUNTS
            if [[ "${1:-0}" == "0" && "${2:-0}" == "0" ]]; then
                echo "    branch is level with $UPSTREAM"
            else
                echo "    branch is ${1:-0} behind / ${2:-0} ahead of $UPSTREAM"
            fi
        fi
    else
        echo "    note: '$BRANCH' has no upstream configured"
    fi
fi

# ---------------------------------------------------------------------------
# Step 2: restore gitignored locals.
#
# `git worktree add` checks out tracked content only. Anything gitignored -- app
# secrets in .env, per-machine Claude settings -- has to be brought over by hand or
# the app won't start. A missing file is a notice, not a failure: not every app has
# every local.
# ---------------------------------------------------------------------------
if [[ ${#LOCALS[@]} -gt 0 ]]; then
    echo "==> Copying gitignored locals: $REPO -> $DEST"
    for rel in "${LOCALS[@]}"; do
        if [[ ! -f "$REPO/$rel" ]]; then
            echo "    skip   $rel (absent in main checkout)"
            continue
        fi
        mkdir -p "$DEST/$(dirname "$rel")"
        cp "$REPO/$rel" "$DEST/$rel"
        echo "    copied $rel"
    done
fi

# ---------------------------------------------------------------------------
# Step 3: activate path-scoped toolchain managers.
#
# Both mise and direnv key trust to the config file's absolute path, so a brand-new
# worktree directory is untrusted no matter how long the main checkout has been
# trusted. Trust it, then materialize the pinned tools. This runs BEFORE dependency
# installs and Gradle so the pinned Node and Java are already on PATH.
# ---------------------------------------------------------------------------
# Note the `${#ARR[@]} -gt 0` guards on this and the loops below: under `set -u`, bash 3.2
# (still the system bash on macOS) treats expanding an empty array as an unbound variable and
# aborts. Newer bash tolerates it, so an unguarded loop passes on a homebrew bash and fails on
# a stock macOS shell.
if [[ ${#TOOLCHAINS[@]} -gt 0 ]]; then
    for tc in "${TOOLCHAINS[@]}"; do
        case "$tc" in
            mise)
                echo "==> Trusting + installing mise toolchain..."
                # `mise trust` with no argument resolves the config in the current (or a
                # parent) directory -- the form the mise docs specify. Passing a bare
                # directory is not a documented invocation, so cd instead.
                (cd "$DEST" && mise trust && mise install)
                ;;
            direnv)
                echo "==> Allowing direnv in the new worktree..."
                (cd "$DEST" && direnv allow)
                ;;
        esac
    done
fi

# ---------------------------------------------------------------------------
# Step 4: install dependencies.
#
# The package manager is dictated by the app's lockfile and is passed in by the
# caller -- running npm in a yarn app writes a competing lockfile and re-resolves the
# dependency tree. Expect this step to dominate wall-clock time and disk: a Hoist
# app's client-app/node_modules runs to a couple of GB per worktree.
# ---------------------------------------------------------------------------
if [[ ${#DEPS[@]} -gt 0 ]]; then
    for spec in "${DEPS[@]}"; do
        dir="${spec%%:*}"
        pm="${spec##*:}"
        [[ -d "$DEST/$dir" ]] || die "--deps directory '$dir' does not exist in the worktree"

        case "$pm" in
            yarn) echo "==> Installing $dir dependencies with yarn..."; (cd "$DEST/$dir" && yarn install) ;;
            npm)  echo "==> Installing $dir dependencies with npm...";  (cd "$DEST/$dir" && npm install)  ;;
        esac
    done
fi

# ---------------------------------------------------------------------------
# Step 5: run Gradle tasks.
#
# Typically `installHoistCoreTools`, which regenerates the server-side AI tooling
# launchers. Those launchers embed an ABSOLUTE path to this worktree's JAR, so they
# are worktree-specific and must be regenerated here -- copying them from the main
# checkout produces launchers pointing at the wrong tree.
# ---------------------------------------------------------------------------
if [[ ${#GRADLE_TASKS[@]} -gt 0 ]]; then
    for task in "${GRADLE_TASKS[@]}"; do
        [[ -x "$DEST/gradlew" ]] || die "--gradle-task '$task' requested but $DEST/gradlew is not executable"
        echo "==> Running ./gradlew $task..."
        (cd "$DEST" && ./gradlew "$task")
    done
fi

# ---------------------------------------------------------------------------
# Step 6: verify toolchain parity.
#
# Outcome check rather than a step check: if the interpreters differ between the two
# checkouts, some path-scoped activation didn't carry over -- including from a manager
# this script doesn't know about (nvm, fnm, volta, asdf, nix). Warn rather than fail;
# the worktree is otherwise usable and the fix is environmental.
# ---------------------------------------------------------------------------
if [[ $VERIFY_PARITY -eq 1 ]]; then
    echo "==> Verifying toolchain parity with the main checkout..."
    for tool in node java; do
        command -v "$tool" >/dev/null 2>&1 || continue
        case "$tool" in
            node) src="$(cd "$REPO" && node --version 2>&1 | head -1)"
                  dst="$(cd "$DEST" && node --version 2>&1 | head -1)" ;;
            java) src="$(cd "$REPO" && java -version 2>&1 | head -1)"
                  dst="$(cd "$DEST" && java -version 2>&1 | head -1)" ;;
        esac
        if [[ "$src" == "$dst" ]]; then
            echo "    ok      $tool: $dst"
        else
            echo "    WARNING $tool differs -- main checkout: $src / worktree: $dst" >&2
        fi
    done
fi

echo
echo "Worktree ready: $DEST"
if [[ $EXISTING_BRANCH -eq 1 ]]; then
    echo "  branch: $BRANCH (existing${UPSTREAM:+, tracking $UPSTREAM})"
else
    echo "  branch: $BRANCH (off $BASE${BASE_SHA:+ @ $BASE_SHA}, --no-track)"
fi
