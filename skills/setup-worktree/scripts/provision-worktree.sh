#!/usr/bin/env bash
# hoist-ai-script: setup-worktree/v2
#
# Provision a ready-to-run git worktree for a Hoist app.
#
# The caller decides WHAT to create: the branch name, and whether it is new or already exists.
# The script detects the FACTS: base ref, destination, gitignored locals, toolchain manager,
# package manager, Gradle tooling task, and hoist-react CLI launchers. Any caller can run it:
# an agent, an editor hook, or a plain shell.
#
# The script never guesses. It detects only hard facts and stops with exit code 3 when a fact
# is ambiguous or when the request conflicts with the repo. It never prompts.
#
# Every step is idempotent. A re-run after a failure adopts the worktree at the destination
# and resumes.
#
# Usage:
#   provision-worktree.sh --branch <name> [--base <ref> | --existing-branch] [options]
#
# Output:
#   On success, stdout gets exactly one line: the absolute worktree path. All progress, all
#   child process output, and all warnings go to stderr. The one exception is --help, which
#   prints usage to stdout. Child processes get no stdin, so nothing can prompt.
#
#   Each step starts with a stable stderr line of the form `==> <step>: <detail>`, for example
#   `==> deps: pnpm install (client-app)`. Steps: fetch, plan, create, locals, toolchain,
#   plugin, deps, gradle, launchers, parity, done.
#
# Non-Hoist repos:
#   The script still creates the worktree, copies locals, activates the toolchain, and installs
#   deps. It skips the Hoist steps (the xh@hoist-ai plugin, Gradle tooling, and launchers)
#   unless their flags are passed explicitly, and says so in the plan.
#
# Environment:
#   Tools come from the caller's PATH and JAVA_HOME. A caller that skips the login shell may lack
#   tools that nvm or a shell profile provide. A missing tool fails with exit 1 and a clear
#   message. The repo does not record its Java version, so the caller must set JAVA_HOME to a
#   JDK the app builds with, unless mise or direnv set it. Steps that need the toolchain run
#   through `mise exec` and `direnv exec`, because their shell hooks do not fire in a script.
#
# Exit codes:
#   0  Success.
#   1  Failed. This includes a broken machine setup, such as a toolchain config whose tool
#      is not on PATH.
#   2  Usage error.
#   3  Needs a decision. The message names the flag that resolves it. Cases: a new branch that
#      already exists, --existing-branch on a branch that does not exist, a branch checked out
#      in another worktree, a destination that exists but is not a worktree, two lockfiles in
#      one directory, a base ref that does not resolve, or no default base.
#
# Required:
#   --branch <name>        Branch for the worktree. By default a NEW branch, created with
#                          --no-track so it never tracks a long-lived branch by accident.
#                          With --existing-branch, a branch that already exists.
#
# Branch options:
#   --base <ref>           Ref to branch a new branch from. A bare name such as `foo` resolves
#                          to `origin/foo` when that exists, else to the local `foo`. Pass
#                          `refs/heads/foo` to force the local branch. Default: `origin/develop`,
#                          else the remote default branch (`origin/HEAD`, refreshed first).
#                          Not valid with --existing-branch.
#   --existing-branch      Check out a branch that already exists. A local branch is checked
#                          out as-is. A branch only on origin gets a local branch that tracks
#                          it. Reports how far the branch is behind or ahead of its upstream.
#
# Location options:
#   --repo <path>          Absolute path to the repo. Default: the git toplevel of the current
#                          directory. A linked worktree resolves to its main checkout, which is
#                          the source of the gitignored locals. In a bare-repo layout there is
#                          no main checkout, so the given worktree is the source.
#   --dest <path>          Absolute path for the worktree.
#                          Default: <parent of repo>/<repo name>-worktrees/<branch>, with each
#                          `/` in the branch name replaced by `-`.
#
# Detection reads tracked files (lockfiles, build files, committed toolchain configs) from the
# commit the worktree gets, not from the main checkout's working tree. Gitignored files come
# from the main checkout.
#
# Detected steps, and their overrides:
#   --local <relpath>      Gitignored file to copy from the repo. Repeatable. Adds to the
#                          detected set: `.env`, `.claude/settings.local.json`, any gitignored
#                          toolchain config, and every gitignored file that matches a pattern
#                          in the repo's `.worktreeinclude` (node_modules is never searched).
#                          Absent files, files tracked on the branch, and files already in the
#                          worktree are skipped, so a re-run never overwrites edits.
#   --enable-plugin <id>   Claude Code plugin to enable in the worktree's own
#                          `.claude/settings.local.json`. Repeatable. Adds to `xh@hoist-ai`,
#                          which is enabled in every Hoist repo. An id the file already sets, true or false,
#                          is left alone.
#   --toolchain <name>     `mise` or `direnv`. Repeatable. Replaces detection, which finds mise
#                          from `mise config ls` or a mise config file, and direnv from `.envrc`.
#   --deps <dir>:<pm>      Install dependencies in <dir> with <pm> (`yarn`, `npm`, or `pnpm`).
#                          Repeatable. Replaces detection, which reads the lockfile in
#                          `client-app/`, or in the repo root when there is no `client-app/`.
#   --gradle-task <name>   Gradle task to run. Repeatable. Replaces detection, which runs
#                          `installHoistCoreTools` when the build file defines it.
#   --skip <step>          Skip a step. Repeatable. Steps: locals, plugin, toolchain, deps,
#                          gradle, launchers, parity.
#
# Other options:
#   --dry-run              Resolve everything, print the plan to stderr and the worktree path to
#                          stdout, then exit without creating anything. Still fetches origin.
#   -h, --help             Print this usage.
#
# Steps, in order. The order matters: the toolchain supplies the Node and Java that later
# steps need.
#   1. Create the worktree, or adopt the one at the destination.
#   2. Copy gitignored locals.
#   3. Trust and install mise / allow direnv. Trust is keyed to a directory path, so a new
#      worktree always starts untrusted.
#   4. Enable Claude Code plugins in the worktree's local settings.
#   5. Install dependencies with the package manager the lockfile names.
#   6. Run Gradle tasks. `installHoistCoreTools` writes launchers with an absolute JAR path, so
#      each worktree needs its own.
#   7. Install the hoist-react CLI launchers (`bin/hoist-docs`, `bin/hoist-ts`) when the repo
#      has them. They are gitignored in most apps.
#   8. Compare `node` and `java` versions with the repo. A mismatch means some activation did
#      not carry over, including from managers this script does not know (nvm, asdf, nix).
#
set -Eeuo pipefail

# A failing child command can exit with any code. Map every such failure to 1, so codes 2 and
# 3 keep their meaning. The die helpers below exit explicitly and do not trigger this trap.
trap 'exit 1' ERR

SCRIPT_NAME="provision-worktree.sh"
DEFAULT_LOCALS=(.env .claude/settings.local.json)
DEFAULT_PLUGIN="xh@hoist-ai"
STEPS="locals plugin toolchain deps gradle launchers parity"
# mise config files to look for when `mise config ls` is unavailable. `.tool-versions` is left
# out on purpose: asdf reads it too, so it does not prove the app uses mise.
MISE_FILES="mise.toml .mise.toml mise.local.toml .mise.local.toml .config/mise.toml
            .config/mise/config.toml mise/config.toml .mise/config.toml"

REPO=""
DEST=""
BRANCH=""
BASE=""
EXISTING_BRANCH=0
DRY_RUN=0
LOCALS=()
PLUGINS=()
TOOLCHAINS=()
DEPS=()
GRADLE_TASKS=()
SKIPS=" "
TOOLCHAINS_SET=0
DEPS_SET=0
GRADLE_SET=0

TREF=""        # commit the worktree gets. Tracked facts are read from here.
BASE_REF=""    # resolved base, create mode only
BASE_SHA=""
BASE_DATE=""
BASE_NOTE=""
ADOPT=0        # 1 when a worktree already exists at --dest
UPSTREAM=""
LAUNCHERS=0
NOTES=()

die()     { echo "${SCRIPT_NAME}: error: $*" >&2; exit 1; }
usage_die() { echo "${SCRIPT_NAME}: usage error: $*" >&2; exit 2; }
decide()  { echo "${SCRIPT_NAME}: needs a decision: $*" >&2; exit 3; }

usage() {
    sed -n '2,/^set -Eeuo/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//; $d'
}

skipped() { [[ "$SKIPS" == *" $1 "* ]]; }

# Resolve this script's real directory through symlinks, so a symlink such as
# ~/.local/bin/xh-provision-worktree still finds the files bundled next to the script.
self_dir() {
    local src="${BASH_SOURCE[0]}" target
    while [[ -L "$src" ]]; do
        target="$(readlink "$src")"
        if [[ "$target" == /* ]]; then src="$target"; else src="$(dirname "$src")/$target"; fi
    done
    cd "$(dirname "$src")" && pwd -P
}

# Append to LOCALS unless already present.
add_local() {
    local rel="$1" existing
    if [[ ${#LOCALS[@]} -gt 0 ]]; then
        for existing in "${LOCALS[@]}"; do [[ "$existing" == "$rel" ]] && return 0; done
    fi
    LOCALS+=("$rel")
}

# A failed fetch is not fatal. Offline, VPN down, or no credentials should not block
# provisioning when the refs are already present locally. The plan shows the base commit date
# and the ahead/behind counts, so a stale ref is visible.
fetch_remote() {
    local remote="$1"
    git -C "$REPO" remote | grep -xF "$remote" >/dev/null || return 0
    echo "==> fetch: $remote"
    # No credential or passphrase prompts: a hook or editor caller has no terminal to answer.
    if ! GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o BatchMode=yes}" \
            git -C "$REPO" fetch --quiet "$remote"; then
        echo "    WARNING: fetch of '$remote' failed. Continuing from the last-fetched refs." >&2
        echo "    Check the base date or ahead/behind counts before relying on them." >&2
    fi
}

ref_exists() { git -C "$REPO" show-ref --verify --quiet "$1"; }

# Print the worktree path that has <branch> checked out, if any.
worktree_with_branch() {
    git -C "$REPO" worktree list --porcelain | awk -v ref="branch refs/heads/$1" '
        /^worktree / { path = substr($0, 10) }
        $0 == ref    { print path; exit }'
}

# ---------------------------------------------------------------------------
# Detection. Tracked facts (lockfiles, build files, committed toolchain configs) are read from
# TREF, the commit the worktree gets. The main checkout can sit on another branch or hold
# stray files. Gitignored facts (locals, launchers) come from the main checkout's working tree.
# ---------------------------------------------------------------------------

in_ref() { git -C "$REPO" cat-file -e "$TREF:$1" 2>/dev/null; }

# grep without -q reads all input, so `git show` never takes a SIGPIPE that pipefail would
# report as a failure.
ref_grep() {
    in_ref "$2" && git -C "$REPO" show "$TREF:$2" 2>/dev/null | grep -E "$1" >/dev/null
}

is_ignored() { [[ -f "$REPO/$1" ]] && git -C "$REPO" check-ignore -q -- "$1"; }

detect_locals() {
    local rel f
    for rel in "${DEFAULT_LOCALS[@]}"; do add_local "$rel"; done

    # A gitignored toolchain config exists only in the main checkout, so copy it.
    for f in $MISE_FILES .envrc; do
        if is_ignored "$f"; then add_local "$f"; fi
    done

    # .worktreeinclude uses gitignore syntax. Like Claude Code, copy only files that match a
    # pattern AND are gitignored. The pathspec keeps git out of node_modules, which is slow to
    # walk and holds files that match common patterns such as `.env`.
    if [[ -f "$REPO/.worktreeinclude" ]]; then
        while IFS= read -r f; do
            if [[ -n "$f" ]]; then add_local "$f"; fi
        done < <(git -C "$REPO" ls-files --others --ignored --exclude-from="$REPO/.worktreeinclude" \
                     -- . ':(exclude,glob)**/node_modules/**' \
                     | git -C "$REPO" check-ignore --stdin || true)
    fi
}

detect_toolchains() {
    local f mise_found=0 line path

    for f in $MISE_FILES; do
        if in_ref "$f" || is_ignored "$f"; then mise_found=1; fi
    done

    # `mise config ls` also finds configs with custom names (MISE_DEFAULT_CONFIG_FILENAME,
    # override_config_filenames, .mise.<env>.toml). Project-scoped entries are paths inside
    # the repo. Global configs and configs in parent directories already apply to the
    # worktree, because it lives under the same parent. `.tool-versions` does not count,
    # because asdf reads it too.
    if [[ $mise_found -eq 0 ]] && command -v mise >/dev/null 2>&1; then
        while IFS= read -r line; do
            path="${line%%[[:space:]]*}"
            path="${path/#\~/$HOME}"
            [[ "$path" == */.tool-versions ]] && continue
            if [[ "$path" == "$REPO"/* ]]; then mise_found=1; break; fi
        done < <(cd "$REPO" && mise config ls 2>/dev/null || true)
    fi

    if [[ $mise_found -eq 1 ]]; then TOOLCHAINS+=(mise); fi
    if in_ref .envrc || is_ignored .envrc; then TOOLCHAINS+=(direnv); fi
    return 0
}

detect_deps() {
    local dir=. prefix="" found="" pm lock
    if in_ref client-app; then dir=client-app; prefix=client-app/; fi
    for pm in yarn npm pnpm; do
        case "$pm" in
            yarn) lock=yarn.lock ;;
            npm)  lock=package-lock.json ;;
            pnpm) lock=pnpm-lock.yaml ;;
        esac
        if in_ref "$prefix$lock"; then
            [[ -z "$found" ]] \
                || decide "'$dir/' has more than one lockfile ($found, $pm). Pass --deps $dir:<pm> to pick one, or --skip deps."
            found="$pm"
        fi
    done
    if [[ -n "$found" ]]; then
        DEPS+=("$dir:$found")
    else
        NOTES+=("no lockfile in '$dir/', so no dependency install")
    fi
}

detect_gradle() {
    if ref_grep installHoistCoreTools build.gradle || ref_grep installHoistCoreTools build.gradle.kts; then
        GRADLE_TASKS+=(installHoistCoreTools)
    fi
    return 0
}

# The launchers are gitignored, so read the main checkout. If the dev uses them there, the
# worktree needs them too.
detect_launchers() {
    if [[ -f "$REPO/bin/hoist-docs" || -f "$REPO/bin/hoist-ts" ]]; then LAUNCHERS=1; fi
    return 0
}

# A Hoist app, or hoist-react / hoist-core itself: a package.json that names @xh/hoist, or a
# Gradle build that names the io.xh group or hoist-core.
detect_hoist() {
    ref_grep '"@xh/hoist"' client-app/package.json && return 0
    ref_grep '"@xh/hoist"' package.json && return 0
    ref_grep 'io\.xh|hoist-core' build.gradle && return 0
    ref_grep 'io\.xh|hoist-core' build.gradle.kts && return 0
    return 1
}

# Make an absolute path canonical: resolve symlinks in the deepest part that exists, and keep
# the rest. Dry runs and real runs then print the same path, and the path matches what
# `git worktree list` reports.
canon_path() {
    local p="${1%/}" rest="" base
    while [[ -n "$p" && ! -d "$p" ]]; do
        rest="/$(basename "$p")$rest"
        p="$(dirname "$p")"
    done
    base="$(cd "${p:-/}" && pwd -P)"
    [[ "$base" == / ]] && base=""
    echo "$base$rest"
}

has_toolchain() {
    local tc
    [[ ${#TOOLCHAINS[@]} -gt 0 ]] || return 1
    for tc in "${TOOLCHAINS[@]}"; do [[ "$tc" == "$1" ]] && return 0; done
    return 1
}

# Run a command in <dir> with that directory's toolchain active. mise and direnv activate
# through shell hooks that fire only at an interactive prompt, never on a `cd` inside a
# script. So wrap the command in `mise exec` and `direnv exec`, or it gets the caller's tools
# instead of the pinned ones.
in_env() {
    local dir="$1"
    shift
    local cmd=("$@")
    if has_toolchain mise; then cmd=(mise exec -- "${cmd[@]}"); fi
    if has_toolchain direnv; then cmd=(direnv exec "$dir" "${cmd[@]}"); fi
    (cd "$dir" && "${cmd[@]}")
}

# shellcheck disable=SC2016 # $1 expands in the inner sh
has_cmd() { in_env "$2" sh -c 'command -v "$1"' _ "$1" >/dev/null 2>&1; }

# Fail with exit 1 and a clear message when a tool the plan needs is not on PATH. Callers that
# don't load the login shell (editor exec, hooks) often lack tools that nvm or a shell profile
# provide.
require_tool() {
    local tool="$1" why="$2" cwd="$3"
    has_cmd "$tool" "$cwd" && return 0
    die "'$tool' is not on PATH ($why). If nvm or a shell profile provides it, add it to PATH before you call this script."
}

# Gradle needs java from JAVA_HOME or PATH. The app's required Java version is not in the
# repo, so a wrong JAVA_HOME surfaces as a Gradle error.
require_java() {
    local cwd="$1"
    # shellcheck disable=SC2016 # JAVA_HOME expands in the inner sh
    in_env "$cwd" sh -c '[ -n "$JAVA_HOME" ] && [ -x "$JAVA_HOME/bin/java" ]' >/dev/null 2>&1 && return 0
    require_tool java "needed by Gradle, and JAVA_HOME is not set" "$cwd"
}

# ---------------------------------------------------------------------------
# Branch and base resolution.
# ---------------------------------------------------------------------------

resolve_base() {
    local remote
    if [[ -n "$BASE" ]]; then
        if [[ "$BASE" != refs/* ]] && ref_exists "refs/remotes/origin/$BASE"; then
            BASE_REF="origin/$BASE"
            ref_exists "refs/heads/$BASE" \
                && BASE_NOTE="resolved '$BASE' to origin/$BASE. Pass --base refs/heads/$BASE for the local branch."
        else
            BASE_REF="$BASE"
            # A base on another remote, such as upstream/foo, needs that remote fetched too.
            remote="${BASE%%/*}"
            [[ "$BASE" == */* && "$remote" != origin ]] && fetch_remote "$remote"
        fi
    elif ref_exists refs/remotes/origin/develop; then
        BASE_REF="origin/develop"
    else
        # origin/HEAD is a cached snapshot of the host's default branch, so refresh it first.
        # It ranks below origin/develop because Hoist repos integrate on develop.
        GIT_TERMINAL_PROMPT=0 git -C "$REPO" remote set-head origin --auto >/dev/null 2>&1 || true
        BASE_REF="$(git -C "$REPO" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
        [[ -n "$BASE_REF" ]] \
            || decide "no origin/develop and no origin/HEAD to default to. Pass --base <ref>."
    fi

    git -C "$REPO" rev-parse --verify --quiet "$BASE_REF^{commit}" >/dev/null \
        || decide "base ref '$BASE_REF' does not resolve to a commit. Pass a different --base."
    BASE_SHA="$(git -C "$REPO" rev-parse --short "$BASE_REF^{commit}")"
    BASE_DATE="$(git -C "$REPO" log -1 --format=%cs "$BASE_REF")"
}

check_branch() {
    local where="" other
    ref_exists "refs/heads/$BRANCH" && where="locally"
    ref_exists "refs/remotes/origin/$BRANCH" && where="${where:+$where and }on origin"

    if [[ $EXISTING_BRANCH -eq 1 ]]; then
        [[ -n "$where" ]] \
            || decide "branch '$BRANCH' exists neither locally nor on origin. Drop --existing-branch to create it."
        other="$(worktree_with_branch "$BRANCH")"
        [[ -z "$other" ]] \
            || decide "branch '$BRANCH' is already checked out at $other. Use that worktree, or pick another branch."
    else
        [[ -z "$where" ]] \
            || decide "branch '$BRANCH' already exists $where. Pass --existing-branch to check it out, or choose a new name."
    fi
}

# ---------------------------------------------------------------------------
# Main. Runs with stdout redirected to stderr, so only the final path reaches stdout.
# ---------------------------------------------------------------------------

main() {
    local self tc spec id rel step dir pm task result counts src dst tool templates

    self="$(self_dir)"

    # --- Validate inputs before touching anything -------------------------
    [[ -n "$BRANCH" ]] || usage_die "--branch is required (try --help)"
    git check-ref-format --branch "$BRANCH" >/dev/null 2>&1 \
        || usage_die "'$BRANCH' is not a valid branch name"
    if [[ $EXISTING_BRANCH -eq 1 && -n "$BASE" ]]; then
        usage_die "--base is not valid with --existing-branch (the branch already has its own history)"
    fi

    if [[ ${#TOOLCHAINS[@]} -gt 0 ]]; then
        for tc in "${TOOLCHAINS[@]}"; do
            case "$tc" in mise|direnv) ;; *) usage_die "unknown --toolchain '$tc' (expected mise or direnv)" ;; esac
        done
    fi
    if [[ ${#DEPS[@]} -gt 0 ]]; then
        for spec in "${DEPS[@]}"; do
            [[ "$spec" == ?*:?* ]] || usage_die "--deps expects <dir>:<pm>, got '$spec'"
            case "${spec##*:}" in
                yarn|npm|pnpm) ;;
                *) usage_die "unknown package manager in --deps '$spec' (expected yarn, npm, or pnpm)" ;;
            esac
        done
    fi
    if [[ ${#PLUGINS[@]} -gt 0 ]]; then
        for id in "${PLUGINS[@]}"; do
            [[ "$id" == ?*@?* ]] || usage_die "--enable-plugin expects <plugin>@<marketplace>, got '$id'"
        done
    fi
    if [[ ${#LOCALS[@]} -gt 0 ]]; then
        for rel in "${LOCALS[@]}"; do
            [[ "$rel" != /* && "/$rel/" != */../* ]] \
                || usage_die "--local expects a path inside the repo, got '$rel'"
        done
    fi
    for step in $SKIPS; do
        [[ " $STEPS " == *" $step "* ]] || usage_die "unknown --skip '$step' (expected one of: $STEPS)"
    done

    # --- Resolve the repo to its main checkout -----------------------------
    if [[ -z "$REPO" ]]; then
        REPO="$(git rev-parse --show-toplevel 2>/dev/null)" \
            || usage_die "not inside a git repository. Pass --repo <absolute path>."
    fi
    [[ "$REPO" == /* ]] || usage_die "--repo must be an absolute path, got '$REPO'"
    [[ -d "$REPO" ]] || die "--repo '$REPO' does not exist"
    REPO="$(git -C "$REPO" rev-parse --show-toplevel 2>/dev/null)" \
        || die "--repo is not inside a git checkout"
    local common
    common="$(cd "$REPO" && cd "$(git rev-parse --git-common-dir)" && pwd -P)"
    if [[ "$(basename "$common")" == .git ]]; then
        REPO="$(dirname "$common")"
    fi
    REPO="$(cd "$REPO" && pwd -P)"

    # --- Resolve the destination ------------------------------------------
    if [[ -z "$DEST" ]]; then
        DEST="$(dirname "$REPO")/$(basename "$REPO")-worktrees/${BRANCH//\//-}"
    fi
    [[ "$DEST" == /* ]] || usage_die "--dest must be an absolute path, got '$DEST'"
    [[ "$DEST/" != */../* && "$DEST/" != */./* ]] \
        || usage_die "--dest must not contain '.' or '..' parts, got '$DEST'"
    DEST="$(canon_path "$DEST")"

    if git -C "$REPO" worktree list --porcelain | grep -xF "worktree $DEST" >/dev/null; then
        [[ -d "$DEST" ]] \
            || decide "git still lists a worktree at $DEST, but the directory is gone. Run 'git -C $REPO worktree prune', or pass a different --dest."
        ADOPT=1
        local current
        current="$(git -C "$DEST" symbolic-ref --quiet HEAD 2>/dev/null || true)"
        current="${current#refs/heads/}"
        [[ "$current" == "$BRANCH" ]] \
            || decide "the worktree at $DEST is on '${current:-a detached HEAD}', not '$BRANCH'. Pass a different --dest."
        TREF="$(git -C "$DEST" rev-parse HEAD)"
    elif [[ -e "$DEST" ]]; then
        decide "'$DEST' exists but is not a worktree of $REPO. Pass a different --dest."
    else
        fetch_remote origin
        check_branch
        if [[ $EXISTING_BRANCH -eq 1 ]]; then
            if ref_exists "refs/heads/$BRANCH"; then TREF="refs/heads/$BRANCH"; else TREF="refs/remotes/origin/$BRANCH"; fi
        else
            resolve_base
            TREF="$BASE_REF"
        fi
    fi

    # --- Detect facts -----------------------------------------------------
    # Outside a Hoist repo the script is a plain worktree provisioner: locals, toolchain, and
    # deps still apply. The Hoist steps (plugin, Gradle tooling, launchers) are skipped unless
    # the caller passes them explicitly.
    local hoist=1
    detect_hoist || hoist=0
    skipped locals    || detect_locals
    if [[ $hoist -eq 1 ]]; then
        PLUGINS=("$DEFAULT_PLUGIN" ${PLUGINS[@]+"${PLUGINS[@]}"})
    fi
    if ! skipped toolchain && [[ $TOOLCHAINS_SET -eq 0 ]]; then detect_toolchains; fi
    if ! skipped deps      && [[ $DEPS_SET -eq 0 ]];       then detect_deps; fi
    if [[ $hoist -eq 1 ]]; then
        if ! skipped gradle && [[ $GRADLE_SET -eq 0 ]]; then detect_gradle; fi
        skipped launchers || detect_launchers
    else
        NOTES+=("not a Hoist repo, so the $DEFAULT_PLUGIN plugin, Gradle tooling, and launchers are skipped")
    fi

    # The skip list wins over explicit overrides too.
    skipped locals    && LOCALS=()
    skipped plugin    && PLUGINS=()
    skipped toolchain && TOOLCHAINS=()
    skipped deps      && DEPS=()
    skipped gradle    && GRADLE_TASKS=()

    # A toolchain config without its tool is a broken machine setup. Fail now, before any
    # work, rather than let Gradle or the install fail later with an unrelated-looking error.
    if [[ ${#TOOLCHAINS[@]} -gt 0 ]]; then
        for tc in "${TOOLCHAINS[@]}"; do
            command -v "$tc" >/dev/null 2>&1 \
                || die "the app is ${tc}-managed but '$tc' is not on PATH. Install it, or pass --skip toolchain."
        done
    fi

    # Without a toolchain manager, the tools the plan needs must already be on PATH. Check now,
    # so a missing tool fails before anything is created. With mise or direnv, the tools may
    # appear only after activation, so the steps below check again just before use.
    if [[ ${#TOOLCHAINS[@]} -eq 0 ]]; then
        if [[ ${#DEPS[@]} -gt 0 ]]; then
            for spec in "${DEPS[@]}"; do require_tool "${spec##*:}" "needed to install ${spec%%:*}" "$REPO"; done
        fi
        [[ ${#GRADLE_TASKS[@]} -eq 0 ]] || require_java "$REPO"
    fi

    # Check what the steps need in the target commit, so these fail before anything exists.
    if [[ ${#DEPS[@]} -gt 0 ]]; then
        for spec in "${DEPS[@]}"; do
            dir="${spec%%:*}"
            [[ "$dir" == . ]] || in_ref "$dir" \
                || die "--deps directory '$dir' does not exist in $TREF"
        done
    fi
    if [[ ${#GRADLE_TASKS[@]} -gt 0 ]]; then
        [[ "$(git -C "$REPO" ls-tree "$TREF" gradlew 2>/dev/null)" == 100755* ]] \
            || die "Gradle task requested but gradlew is missing or not executable in $TREF"
    fi

    templates="$self/../../using-hoist-react-reference/templates"
    if [[ $LAUNCHERS -eq 1 && ! ( -f "$templates/hoist-docs" && -f "$templates/hoist-ts" ) ]]; then
        NOTES+=("hoist-react launcher templates not found next to this script, so launchers are skipped")
        LAUNCHERS=0
    fi

    # --- Print the plan ---------------------------------------------------
    echo "==> plan"
    echo "    repo:       $REPO"
    echo "    worktree:   $DEST"
    if [[ $ADOPT -eq 1 ]]; then
        echo "    branch:     $BRANCH (adopting the existing worktree)"
    elif [[ $EXISTING_BRANCH -eq 1 ]]; then
        echo "    branch:     $BRANCH (existing)"
    else
        echo "    branch:     $BRANCH (new, off $BASE_REF @ $BASE_SHA, committed $BASE_DATE)"
    fi
    echo "    locals:     ${LOCALS[*]:-none}"
    echo "    plugins:    ${PLUGINS[*]:-none}"
    echo "    toolchain:  ${TOOLCHAINS[*]:-none}"
    echo "    deps:       ${DEPS[*]:-none}"
    echo "    gradle:     ${GRADLE_TASKS[*]:-none}"
    if [[ $LAUNCHERS -eq 1 ]]; then echo "    launchers:  bin/hoist-docs bin/hoist-ts"; else echo "    launchers:  none"; fi
    [[ -z "$BASE_NOTE" ]] || echo "    note: $BASE_NOTE"
    if [[ ${#NOTES[@]} -gt 0 ]]; then
        for rel in "${NOTES[@]}"; do echo "    note: $rel"; done
    fi
    if [[ ${#DEPS[@]} -gt 0 ]]; then
        for spec in "${DEPS[@]}"; do
            case "${spec##*:}" in
                yarn|npm) echo "    note: ${spec##*:} writes a full node_modules copy, often 1-2 GB per worktree" ;;
            esac
        done
    fi

    if [[ $DRY_RUN -eq 1 ]]; then
        echo "==> done: dry run, nothing created"
        return 0
    fi

    # --- Step 1: create or adopt the worktree -----------------------------
    if [[ $ADOPT -eq 1 ]]; then
        echo "==> create: adopting the existing worktree at $DEST"
    elif [[ $EXISTING_BRANCH -eq 1 ]]; then
        mkdir -p "$(dirname "$DEST")"
        echo "==> create: $DEST (existing branch $BRANCH)"
        if ref_exists "refs/heads/$BRANCH"; then
            echo "    checking out existing local branch '$BRANCH'..."
            # A local branch keeps whatever upstream it already had.
            git -C "$REPO" worktree add "$DEST" "$BRANCH"
        else
            echo "    creating local '$BRANCH' tracking origin/$BRANCH..."
            # Track the branch's own remote counterpart, so push and pull behave. This is
            # unlike create mode's --no-track, which stops a new feature branch from tracking
            # a long-lived integration branch.
            git -C "$REPO" worktree add --track -b "$BRANCH" "$DEST" "origin/$BRANCH"
        fi
    else
        mkdir -p "$(dirname "$DEST")"
        echo "==> create: $DEST (new branch $BRANCH off $BASE_REF)"
        git -C "$REPO" worktree add "$DEST" -b "$BRANCH" --no-track "$BASE_REF"
    fi
    DEST="$(cd "$DEST" && pwd -P)"

    # An existing branch can be behind its remote. Report the divergence, as create mode
    # reports the base date.
    if [[ $EXISTING_BRANCH -eq 1 ]]; then
        UPSTREAM="$(git -C "$DEST" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
        if [[ -n "$UPSTREAM" ]]; then
            counts="$(git -C "$DEST" rev-list --left-right --count "$UPSTREAM...HEAD" 2>/dev/null || true)"
            if [[ -n "$counts" ]]; then
                # shellcheck disable=SC2086 # split "behind ahead" into $1 $2
                set -- $counts
                if [[ "${1:-0}" == 0 && "${2:-0}" == 0 ]]; then
                    echo "    branch is level with $UPSTREAM"
                else
                    echo "    branch is ${1:-0} behind / ${2:-0} ahead of $UPSTREAM"
                fi
            fi
        else
            echo "    note: '$BRANCH' has no upstream configured"
        fi
    fi

    # --- Step 2: copy gitignored locals -----------------------------------
    if [[ ${#LOCALS[@]} -gt 0 ]]; then
        echo "==> locals: copying gitignored files"
        for rel in "${LOCALS[@]}"; do
            if [[ ! -f "$REPO/$rel" ]]; then
                echo "    skip   $rel (absent in the repo)"
                continue
            fi
            if git -C "$DEST" ls-files --error-unmatch -- "$rel" >/dev/null 2>&1; then
                echo "    skip   $rel (tracked on this branch)"
                continue
            fi
            # Never overwrite. On a re-run, the worktree's copy may hold edits.
            if [[ -e "$DEST/$rel" ]]; then
                echo "    kept   $rel (already in the worktree)"
                continue
            fi
            mkdir -p "$DEST/$(dirname "$rel")"
            cp -p "$REPO/$rel" "$DEST/$rel"
            echo "    copied $rel"
        done
    fi

    # --- Step 3: activate path-scoped toolchain managers ------------------
    # Runs before the install and Gradle, so the pinned Node and Java are on PATH.
    if [[ ${#TOOLCHAINS[@]} -gt 0 ]]; then
        for tc in "${TOOLCHAINS[@]}"; do
            case "$tc" in
                mise)
                    echo "==> toolchain: mise trust + mise install"
                    # `mise trust` with no argument finds the config in the current directory.
                    (cd "$DEST" && mise trust && mise install)
                    ;;
                direnv)
                    echo "==> toolchain: direnv allow"
                    (cd "$DEST" && direnv allow)
                    ;;
            esac
        done
    fi

    # --- Step 4: enable Claude Code plugins -------------------------------
    # A plugin enabled only in the committed .claude/settings.json drops out on any branch
    # older than that commit. A local entry keeps it on whatever the branch. A missing node
    # is a warning: the worktree still works, and the fix is one line.
    if [[ ${#PLUGINS[@]} -gt 0 ]]; then
        echo "==> plugin: enabling in .claude/settings.local.json"
        local settings="$DEST/.claude/settings.local.json"
        for id in "${PLUGINS[@]}"; do
            if ! has_cmd node "$DEST"; then
                echo "    WARNING: node is not on PATH. Add \"enabledPlugins\": {\"$id\": true}" >&2
                echo "    to $settings by hand." >&2
                continue
            fi
            mkdir -p "$DEST/.claude"
            # Prints "enabled", or "kept" when the file already sets this id either way. Plain
            # ES2015 syntax, so an old system node can run it. A failure is a warning, like a
            # missing node.
            if ! result="$(in_env "$DEST" node -e '
                const fs = require("fs");
                const [file, id] = process.argv.slice(1);
                let data = {};
                try {
                    if (fs.existsSync(file)) data = JSON.parse(fs.readFileSync(file, "utf8"));
                } catch (e) {
                    console.log("skipped (invalid JSON in settings.local.json)");
                    process.exit(0);
                }
                const plugins = data.enabledPlugins = data.enabledPlugins || {};
                if (id in plugins) {
                    console.log("kept");
                } else {
                    plugins[id] = true;
                    fs.writeFileSync(file, JSON.stringify(data, null, 2) + "\n");
                    console.log("enabled");
                }' "$settings" "$id" 2>&1)"; then
                echo "    WARNING: could not update $settings: $result" >&2
                echo "    Add \"enabledPlugins\": {\"$id\": true} by hand." >&2
                continue
            fi
            echo "    $result $id"
        done
    fi

    # --- Step 5: install dependencies -------------------------------------
    # The lockfile names the package manager. npm in a yarn app writes a competing lockfile.
    if [[ ${#DEPS[@]} -gt 0 ]]; then
        for spec in "${DEPS[@]}"; do
            dir="${spec%%:*}"
            pm="${spec##*:}"
            [[ -d "$DEST/$dir" ]] || die "--deps directory '$dir' does not exist in the worktree"
            require_tool "$pm" "needed to install $dir" "$DEST/$dir"
            echo "==> deps: $pm install ($dir)"
            in_env "$DEST/$dir" "$pm" install
        done
    fi

    # --- Step 6: run Gradle tasks -----------------------------------------
    if [[ ${#GRADLE_TASKS[@]} -gt 0 ]]; then
        for task in "${GRADLE_TASKS[@]}"; do
            [[ -x "$DEST/gradlew" ]] || die "Gradle task '$task' requested but $DEST/gradlew is not executable"
            require_java "$DEST"
            echo "==> gradle: ./gradlew $task"
            in_env "$DEST" ./gradlew "$task"
        done
    fi

    # --- Step 7: install the hoist-react CLI launchers --------------------
    # Copy the plugin's canonical templates byte for byte, not the repo's copies, which may be
    # stamped at an older launcher version.
    if [[ $LAUNCHERS -eq 1 ]]; then
        echo "==> launchers: bin/hoist-docs bin/hoist-ts"
        mkdir -p "$DEST/bin"
        for tool in hoist-docs hoist-ts; do
            cp "$templates/$tool" "$DEST/bin/$tool"
            chmod +x "$DEST/bin/$tool"
            # shellcheck disable=SC2016
            grep -qF '$0' "$DEST/bin/$tool" || die "bin/$tool lost its \$0 literal during the copy"
            echo "    installed bin/$tool"
        done
    fi

    # --- Step 8: verify toolchain parity ----------------------------------
    # Warn rather than fail: the worktree is usable and the fix is environmental.
    if ! skipped parity; then
        echo "==> parity: node and java versus the repo"
        for tool in node java; do
            has_cmd "$tool" "$DEST" || continue
            case "$tool" in
                node) src="$(in_env "$REPO" node --version 2>&1 | head -1 || true)"
                      dst="$(in_env "$DEST" node --version 2>&1 | head -1 || true)" ;;
                java) src="$(in_env "$REPO" java -version 2>&1 | head -1 || true)"
                      dst="$(in_env "$DEST" java -version 2>&1 | head -1 || true)" ;;
            esac
            if [[ "$src" == "$dst" ]]; then
                echo "    ok      $tool: $dst"
            else
                echo "    WARNING $tool differs. Repo: $src / worktree: $dst" >&2
            fi
        done
    fi

    echo "==> done: $DEST"
    if [[ $EXISTING_BRANCH -eq 1 ]]; then
        echo "  branch: $BRANCH (existing${UPSTREAM:+, tracking $UPSTREAM})"
    elif [[ $ADOPT -eq 0 ]]; then
        echo "  branch: $BRANCH (off $BASE_REF @ $BASE_SHA, --no-track)"
    fi
}

# ---------------------------------------------------------------------------
# Argument parsing.
# ---------------------------------------------------------------------------

need_val() { [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || usage_die "$1 needs a value"; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo)            need_val "$@"; REPO="$2"; shift 2 ;;
        --dest)            need_val "$@"; DEST="$2"; shift 2 ;;
        --branch)          need_val "$@"; BRANCH="$2"; shift 2 ;;
        --base)            need_val "$@"; BASE="$2"; shift 2 ;;
        --local)           need_val "$@"; LOCALS+=("$2"); shift 2 ;;
        --enable-plugin)   need_val "$@"; PLUGINS+=("$2"); shift 2 ;;
        --toolchain)       need_val "$@"; TOOLCHAINS+=("$2"); TOOLCHAINS_SET=1; shift 2 ;;
        --deps)            need_val "$@"; DEPS+=("$2"); DEPS_SET=1; shift 2 ;;
        --gradle-task)     need_val "$@"; GRADLE_TASKS+=("$2"); GRADLE_SET=1; shift 2 ;;
        --skip)            need_val "$@"; SKIPS="$SKIPS$2 "; shift 2 ;;
        --existing-branch) EXISTING_BRANCH=1; shift ;;
        --dry-run)         DRY_RUN=1; shift ;;
        --verify-parity)   shift ;;  # v1 flag. The parity check now always runs.
        -h|--help)         usage; exit 0 ;;
        *)                 usage_die "unknown argument '$1' (try --help)" ;;
    esac
done

# Children get no stdin, so no tool can stop and wait for an answer.
main >&2 </dev/null
echo "$DEST"
