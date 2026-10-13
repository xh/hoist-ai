#!/usr/bin/env bash
# hoist-ai-script: setup-hoist-dev-worktree/v1
#
# Configure a provisioned Hoist framework-dev task directory so toolbox runs against the
# sibling hoist-react / hoist-core worktrees inside it, on ports unique to this task.
#
# Run AFTER each repo has been provisioned by setup-worktree's provision-worktree.sh. Safe to
# re-run, e.g. after adding hoist-core to an existing task.
#
# Usage:
#   configure-dev-worktree.sh --task-dir <abs-path>
#
# Expects <task-dir>/toolbox, plus optionally <task-dir>/hoist-react and <task-dir>/hoist-core.
# Every task dir sharing <task-dir>'s parent is scanned to pick a free port slot.
#
# Side effects, all in <task-dir>/toolbox:
#   .env                   SERVER_PORT, APP_TOOLBOX_MULTI_INSTANCE_ENABLED=false (unique
#                          cluster name, no joining other local instances).
#   client-app/.env.local  XH_DEV_PORT, XH_DEV_GRAILS_PORT, and XH_INLINE_HOIST=true if
#                          hoist-react is present.
#   client-app/tsconfig.json  `paths` to ../../hoist-react uncommented if hoist-react present.
#   gradle.properties      runHoistInline=true if hoist-core present.
# Tracked files edited above are marked --skip-worktree in this worktree's index only.
#
# Prints the slot, ports, and run commands.
#
set -euo pipefail

SCRIPT_NAME="configure-dev-worktree.sh"
BASE_CLIENT_PORT=3000
BASE_SERVER_PORT=8080

die() {
    echo "${SCRIPT_NAME}: error: $*" >&2
    exit 1
}

TASK_DIR=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --task-dir) TASK_DIR="${2:-}"; shift 2 ;;
        -h|--help)  sed -n '2,/^set -euo/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//; $d'; exit 0 ;;
        *)          die "unknown argument '$1' (try --help)" ;;
    esac
done

[[ "$TASK_DIR" == /* ]] || die "--task-dir must be an absolute path, got '$TASK_DIR'"
TASK_DIR="$(cd "$TASK_DIR" && pwd -P)"
TB="$TASK_DIR/toolbox"
[[ -d "$TB/client-app" ]] || die "no toolbox worktree at $TB"

HAS_REACT=0; [[ -d "$TASK_DIR/hoist-react" ]] && HAS_REACT=1
HAS_CORE=0;  [[ -d "$TASK_DIR/hoist-core" ]] && HAS_CORE=1

ENV_FILE="$TB/.env"
ENV_LOCAL="$TB/client-app/.env.local"
TSCONFIG="$TB/client-app/tsconfig.json"
GRADLE_PROPS="$TB/gradle.properties"

set_env_var() {
    local file="$1" key="$2" val="$3"
    touch "$file"
    if grep -q "^${key}=" "$file"; then
        sed -i.bak "s|^${key}=.*|${key}=${val}|" "$file" && rm -f "$file.bak"
    else
        [[ -s "$file" && -n "$(tail -c1 "$file")" ]] && echo >> "$file"
        echo "${key}=${val}" >> "$file"
    fi
}

read_env_var() {
    [[ -f "$1" ]] && sed -n "s/^$2=//p" "$1" | tail -1
}

skip_worktree() {
    git -C "$TB" update-index --skip-worktree "$1"
}

# ---------------------------------------------------------------------------
# Port slot: reuse this task's slot on re-run, else lowest slot >= 1 no sibling task holds.
# ---------------------------------------------------------------------------
existing_port="$(read_env_var "$ENV_LOCAL" XH_DEV_PORT || true)"
if [[ -n "$existing_port" ]]; then
    SLOT=$((existing_port - BASE_CLIENT_PORT))
else
    used=" "
    for f in "$(dirname "$TASK_DIR")"/*/toolbox/client-app/.env.local; do
        [[ -f "$f" ]] || continue
        p="$(read_env_var "$f" XH_DEV_PORT || true)"
        [[ -n "$p" ]] && used+="$((p - BASE_CLIENT_PORT)) "
    done
    SLOT=1
    while [[ "$used" == *" $SLOT "* ]]; do SLOT=$((SLOT + 1)); done
fi
CLIENT_PORT=$((BASE_CLIENT_PORT + SLOT))
SERVER_PORT=$((BASE_SERVER_PORT + SLOT))

echo "==> Port slot $SLOT: client $CLIENT_PORT, server $SERVER_PORT"
set_env_var "$ENV_LOCAL" XH_DEV_PORT "$CLIENT_PORT"
set_env_var "$ENV_LOCAL" XH_DEV_GRAILS_PORT "$SERVER_PORT"
set_env_var "$ENV_FILE" SERVER_PORT "$SERVER_PORT"

echo "==> Disabling multi-instance clustering"
set_env_var "$ENV_FILE" APP_TOOLBOX_MULTI_INSTANCE_ENABLED false

# ---------------------------------------------------------------------------
# hoist-react inline
# ---------------------------------------------------------------------------
if [[ $HAS_REACT -eq 1 ]]; then
    echo "==> Enabling inline hoist-react"
    set_env_var "$ENV_LOCAL" XH_INLINE_HOIST true

    perl -0pi -e 's#// "paths": \{\n(\s*)//   ("\@xh/hoist/\*": \[[^\]\n]*\])\n(\s*)// \}#"paths": {\n$1  $2\n$3}#' "$TSCONFIG"
    grep -qE '^\s*"paths": \{' "$TSCONFIG" \
        || die "could not enable \"paths\" in $TSCONFIG -- its commented-out block has changed shape"
    skip_worktree client-app/tsconfig.json
fi

# ---------------------------------------------------------------------------
# hoist-core inline
# ---------------------------------------------------------------------------
if [[ $HAS_CORE -eq 1 ]]; then
    echo "==> Enabling inline hoist-core"
    grep -q '^runHoistInline=' "$GRADLE_PROPS" || die "no runHoistInline property in $GRADLE_PROPS"
    sed -i.bak 's/^runHoistInline=.*/runHoistInline=true/' "$GRADLE_PROPS" && rm -f "$GRADLE_PROPS.bak"
    skip_worktree gradle.properties
fi

echo
echo "Task ready: $TASK_DIR"
echo "  hoist-react: $([[ $HAS_REACT -eq 1 ]] && echo inline || echo published)"
echo "  hoist-core:  $([[ $HAS_CORE -eq 1 ]] && echo inline || echo published)"
echo
echo "Run:"
echo "  server:  (cd $TB && ./gradlew bootRun)"
echo "  client:  (cd $TB/client-app && pnpm start)"
echo "  app:     http://localhost:$CLIENT_PORT/app"
