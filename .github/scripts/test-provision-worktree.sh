#!/usr/bin/env bash
# Sandbox tests for skills/setup-worktree/scripts/provision-worktree.sh. Stubs stand in for
# the package managers, mise, and direnv, so nothing real installs.
# Usage: test-provision-worktree.sh [bash-binary]   (run with /bin/bash on macOS for bash 3.2)
set -u
BASH_BIN="${1:-bash}"
SCRIPT="$(cd "$(dirname "$0")/../.." && pwd -P)/skills/setup-worktree/scripts/provision-worktree.sh"
T="$(cd "$(mktemp -d)" && pwd -P)/sandbox"
mkdir -p "$T/stubbin"
trap 'rm -rf "$(dirname "$T")"' EXIT
PASS=0; FAIL=0
ok()   { echo "PASS: $1"; PASS=$((PASS+1)); }
bad()  { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

# Stub package managers and gradle-free java so nothing real installs.
for pm in pnpm yarn npm; do
    printf '#!/bin/sh\necho "stub %s $*" >&1\ntouch node_modules.stub\n' "$pm" > "$T/stubbin/$pm"
    chmod +x "$T/stubbin/$pm"
done
# A java stub too: the Gradle precheck needs java, and only macOS ships one at /usr/bin/java.
printf '#!/bin/sh\necho "openjdk version \\"21.0.0\\"" >&2\n' > "$T/stubbin/java"
chmod +x "$T/stubbin/java"
export PATH="$T/stubbin:$PATH"
printf "[user]\n name = t\n email = t@t\n[init]\n defaultBranch = main\n" > "$T/gitconfig"; export GIT_CONFIG_GLOBAL="$T/gitconfig" GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

# Origin with develop + main, a hoist app layout.
git init -q --bare "$T/origin.git"
git init -q -b main "$T/seed"
(
  cd "$T/seed"
  mkdir -p client-app .claude
  echo '{"dependencies":{"@xh/hoist":"88.0.0"}}' > client-app/package.json
  echo 'lock' > client-app/pnpm-lock.yaml
  printf '.env\n.claude/settings.local.json\nsecrets/\nbin/\n' > .gitignore
  echo 'secrets/*.key' > .worktreeinclude
  printf '#!/bin/sh\necho gradle "$@"\n' > gradlew; chmod +x gradlew
  echo "tasks.register('installHoistCoreTools')" > build.gradle
  git add -A; git commit -qm init
  git push -q "$T/origin.git" main
  git checkout -qb develop; echo d > d.txt; git add -A; git commit -qm dev
  git push -q "$T/origin.git" develop
  git checkout -qb pushed; echo p > p.txt; git add -A; git commit -qm pushed
  git push -q "$T/origin.git" pushed
)
git clone -q "$T/origin.git" "$T/app"
(
  cd "$T/app"
  git checkout -q develop
  echo 'SECRET=1' > .env
  echo '{"permissions":{}}' > .claude/settings.local.json 2>/dev/null || { mkdir -p .claude; echo '{"permissions":{}}' > .claude/settings.local.json; }
  mkdir -p secrets bin; echo k > secrets/a.key; echo x > secrets/b.txt
  printf '#!/usr/bin/env bash\nold $0\n' > bin/hoist-docs
)

run() { # run <args...>; sets OUT ERR RC
    OUT="$("$BASH_BIN" "$SCRIPT" "$@" 2>"$T/err")"; RC=$?; ERR="$(cat "$T/err")"
}

# 1. dry-run: path on stdout, nothing created, plan correct.
run --repo "$T/app" --branch feature/foo --dry-run
WT="$T/app-worktrees/feature-foo"
[[ $RC -eq 0 && "$OUT" == "$WT" && ! -e "$WT" ]] && ok "dry-run prints path, creates nothing" || bad "dry-run rc=$RC out=$OUT"
grep -q 'off origin/develop' <<<"$ERR" && ok "default base origin/develop" || bad "default base: $ERR"
grep -q 'deps:       client-app:pnpm' <<<"$ERR" && ok "detects pnpm" || bad "pnpm detection"
grep -q 'gradle:     installHoistCoreTools' <<<"$ERR" && ok "detects gradle task" || bad "gradle detection"
grep -q 'secrets/a.key' <<<"$ERR" && ! grep -q 'secrets/b.txt' <<<"$ERR" && ok ".worktreeinclude matched" || bad "worktreeinclude: $ERR"
grep -q 'plugins:    xh@hoist-ai' <<<"$ERR" && ok "plugin in hoist repo" || bad "plugin"

# 2. Real run.
run --repo "$T/app" --branch feature/foo
[[ $RC -eq 0 && "$OUT" == "$WT" ]] && ok "real run stdout is path only" || bad "real run rc=$RC out=[$OUT] err=$ERR"
[[ $(printf '%s' "$OUT" | wc -l | tr -d ' ') == 0 ]] && ok "stdout single line" || bad "stdout lines"
[[ -f "$WT/.env" && -f "$WT/secrets/a.key" && ! -e "$WT/secrets/b.txt" ]] && ok "locals copied" || bad "locals"
grep -q '"xh@hoist-ai": true' "$WT/.claude/settings.local.json" && ok "plugin enabled" || bad "plugin file"
[[ -f "$WT/client-app/node_modules.stub" ]] && ok "deps installed" || bad "deps"
grep -q 'hoist-ai-launcher' "$WT/bin/hoist-docs" && grep -qF '$0' "$WT/bin/hoist-ts" && ok "launchers from templates" || bad "launchers"
grep -q '==> deps: pnpm install (client-app)' <<<"$ERR" && ok "step marker" || bad "step marker"
[[ -z "$(git -C "$WT" rev-parse --abbrev-ref '@{upstream}' 2>/dev/null)" ]] && ok "new branch no-track" || bad "tracking"

# 3. Re-run resumes (adopt).
run --repo "$T/app" --branch feature/foo
[[ $RC -eq 0 && "$OUT" == "$WT" ]] && grep -q 'adopting' <<<"$ERR" && ok "re-run adopts" || bad "adopt rc=$RC $ERR"

# 4. New branch that exists on origin -> 3.
run --repo "$T/app" --branch pushed
[[ $RC -eq 3 && -z "$OUT" ]] && grep -q 'existing-branch' <<<"$ERR" && ok "exists on origin -> 3" || bad "exists rc=$RC"
run --repo "$T/app" --branch pushed --dry-run
[[ $RC -eq 3 ]] && ok "dry-run also exits 3" || bad "dry-run exists rc=$RC"

# 5. Existing branch from origin.
run --repo "$T/app" --branch pushed --existing-branch
[[ $RC -eq 0 ]] && grep -q 'level with origin/pushed' <<<"$ERR" && ok "existing-branch tracks origin" || bad "existing rc=$RC $ERR"

# 6. Existing branch checked out elsewhere -> 3.
run --repo "$T/app" --branch develop --existing-branch --dest "$T/x"
[[ $RC -eq 3 ]] && grep -q 'already checked out' <<<"$ERR" && ok "checked out elsewhere -> 3" || bad "checked out rc=$RC $ERR"

# 7. Existing-branch missing -> 3.
run --repo "$T/app" --branch nope --existing-branch
[[ $RC -eq 3 ]] && ok "missing existing -> 3" || bad "missing rc=$RC"

# 8. Usage errors -> 2.
run --repo "$T/app"
[[ $RC -eq 2 ]] && ok "no branch -> 2" || bad "no branch rc=$RC"
run --repo "$T/app" --branch x --base origin/develop --existing-branch
[[ $RC -eq 2 ]] && ok "base+existing -> 2" || bad "base+existing rc=$RC"
run --repo relative --branch x
[[ $RC -eq 2 ]] && ok "relative repo -> 2" || bad "relative rc=$RC"
run --repo "$T/app" --branch x --skip bogus
[[ $RC -eq 2 ]] && ok "bad skip -> 2" || bad "bad skip rc=$RC"

# 9. Bad base -> 3. Bare base resolves to origin.
run --repo "$T/app" --branch y --base nosuch --dry-run
[[ $RC -eq 3 ]] && ok "unresolvable base -> 3" || bad "bad base rc=$RC"
run --repo "$T/app" --branch y --base main --dry-run
grep -q 'off origin/main' <<<"$ERR" && ok "bare base -> origin/main" || bad "bare base: $ERR"

# 10. Dest exists, not a worktree -> 3.
mkdir -p "$T/occupied"
run --repo "$T/app" --branch z --dest "$T/occupied"
[[ $RC -eq 3 ]] && ok "occupied dest -> 3" || bad "occupied rc=$RC"

# 11. Two lockfiles -> 3, and nothing created.
( cd "$T/seed"; git checkout -q -b twolocks main; echo y > client-app/yarn.lock; git add -A; git commit -qm two; git push -q "$T/origin.git" twolocks; git checkout -q develop )
run --repo "$T/app" --branch two --base twolocks
[[ $RC -eq 3 && ! -e "$T/app-worktrees/two" ]] && ok "two lockfiles -> 3, nothing created" || bad "two locks rc=$RC $ERR"

# 12. Called from a linked worktree resolves to main checkout.
run --repo "$WT" --branch from-wt --dry-run
[[ "$OUT" == "$T/app-worktrees/from-wt" ]] && ok "linked worktree -> main checkout" || bad "linked: $OUT"

# 13. Default repo from cwd.
OUT="$(cd "$T/app/client-app" && "$BASH_BIN" "$SCRIPT" --branch cwdtest --dry-run 2>/dev/null)"
[[ "$OUT" == "$T/app-worktrees/cwdtest" ]] && ok "repo defaults from cwd" || bad "cwd: $OUT"

# 14. Missing tool -> 1 before anything created.
mkdir -p "$T/nopnpm"; ln -sf "$(command -v git)" "$T/nopnpm/git"
for t in dirname basename cat grep sed awk mkdir readlink; do ln -sf "$(command -v $t)" "$T/nopnpm/$t"; done
OUT="$(PATH="$T/nopnpm:/usr/bin:/bin" "$BASH_BIN" "$SCRIPT" --repo "$T/app" --branch notool --skip gradle 2>"$T/err")"; RC=$?
PATH_HAS_PNPM="$(PATH="$T/nopnpm:/usr/bin:/bin" command -v pnpm || true)"
if [[ -n "$PATH_HAS_PNPM" ]]; then echo "SKIP: pnpm is in /usr/bin"; else
[[ $RC -eq 1 && ! -e "$T/app-worktrees/notool" ]] && grep -q "'pnpm' is not on PATH" "$T/err" && ok "missing pnpm -> 1, nothing created" || bad "missing tool rc=$RC $(cat "$T/err")"
fi

# 15. Non-hoist repo: no plugin, gradle, launchers.
git init -q -b main "$T/plain"
( cd "$T/plain"; echo '{}' > package.json; echo l > package-lock.json; git add -A; git commit -qm i; git remote add origin "$T/origin.git"; )
run --repo "$T/plain" --branch feat --base refs/heads/main
[[ $RC -eq 0 ]] && grep -q 'not a Hoist repo' <<<"$ERR" && grep -q 'plugins:    none' <<<"$ERR" && [[ -f "$T/plain-worktrees/feat/node_modules.stub" ]] \
  && ok "non-hoist: deps only" || bad "non-hoist rc=$RC $ERR"

# 16. Child failure code maps to 1.
printf '#!/bin/sh\nexit 3\n' > "$T/stubbin/pnpm"
run --repo "$T/app" --branch childfail --skip gradle
[[ $RC -eq 1 ]] && ok "child exit 3 maps to 1" || bad "child fail rc=$RC"

# 17. mise + direnv wiring: deps and gradle run through `direnv exec` and `mise exec`.
printf '#!/bin/sh\necho "stub pnpm $*"\ntouch node_modules.stub\n' > "$T/stubbin/pnpm"
cat > "$T/stubbin/mise" <<'STUB'
#!/bin/sh
echo "mise $*" >> "$TOOL_LOG"
case "$1" in exec) shift; [ "$1" = "--" ] && shift; exec "$@" ;; esac
exit 0
STUB
cat > "$T/stubbin/direnv" <<'STUB'
#!/bin/sh
echo "direnv $*" >> "$TOOL_LOG"
case "$1" in exec) d="$2"; shift 2; cd "$d" && exec "$@" ;; esac
exit 0
STUB
chmod +x "$T/stubbin/mise" "$T/stubbin/direnv"
export TOOL_LOG="$T/tool.log"; : > "$TOOL_LOG"
( cd "$T/app"; echo '[tools]' > mise.toml; echo 'export X=1' > .envrc; git add mise.toml .envrc; git commit -qm tc; git push -q origin develop )
run --repo "$T/app" --branch tcwire
[[ $RC -eq 0 ]] && grep -q 'toolchain:  mise direnv' <<<"$ERR" && grep -q '^mise trust' "$TOOL_LOG" && grep -q 'direnv exec .*mise exec -- pnpm install' "$TOOL_LOG" && grep -q 'mise exec -- ./gradlew installHoistCoreTools' "$TOOL_LOG" \
  && ok "toolchain wraps deps and gradle" || bad "toolchain wiring rc=$RC log=$(cat "$TOOL_LOG") err=$ERR"

# 18. Gitignored mise config gets copied as a local.
( cd "$T/app"; echo 'mise.local.toml' >> .gitignore; git add .gitignore; git commit -qm gi; echo '[env]' > mise.local.toml )
run --repo "$T/app" --branch tclocal --dry-run
grep -q 'locals:.*mise.local.toml' <<<"$ERR" && ok "untracked mise config is a local" || bad "mise local: $ERR"

# ---- review regressions (stubs from 17 stay on PATH; remove toolchain files first) ----
( cd "$T/app"; git rm -q mise.toml .envrc; git commit -qm rmtc; git push -q origin develop; rm -f mise.local.toml )

# R1. Stale main checkout: main has yarn.lock, origin/develop switched to pnpm only.
git clone -q "$T/origin.git" "$T/r1"; git -C "$T/r1" checkout -q develop
( cd "$T/seed"; git checkout -q develop; git pull -q "$T/origin.git" develop; echo y > client-app/yarn.lock; git add -A; git commit -qm yarn; git push -q "$T/origin.git" develop )
git -C "$T/r1" pull -q   # r1 now on the yarn commit
( cd "$T/seed"; git rm -q client-app/yarn.lock; git commit -qm pnpm-only; git push -q "$T/origin.git" develop )
run --repo "$T/r1" --branch r1feat --dry-run
grep -q 'deps:       client-app:pnpm' <<<"$ERR" && ok "R1 deps read from target ref" || bad "R1: $ERR"
echo stray > "$T/r1/client-app/package-lock.json"
run --repo "$T/r1" --branch r1feat --dry-run
[[ $RC -eq 0 ]] && ok "R1 stray untracked lockfile ignored" || bad "R1 stray rc=$RC"

# R2. .worktreeinclude never descends into node_modules.
mkdir -p "$T/app/client-app/node_modules/pkg"; echo x > "$T/app/client-app/node_modules/pkg/.env"
printf 'secrets/*.key\n.env\n' > "$T/app/.worktreeinclude"
run --repo "$T/app" --branch r2 --dry-run
! grep -q 'node_modules' <<<"$ERR" && grep -q 'secrets/a.key' <<<"$ERR" && ok "R2 node_modules skipped" || bad "R2: $ERR"
echo 'secrets/*.key' > "$T/app/.worktreeinclude"

# R3. Re-run adopts when a tag shares the branch name.
git -C "$T/app" tag feature/foo origin/main
run --repo "$T/app" --branch feature/foo
[[ $RC -eq 0 ]] && ok "R3 adopt with same-name tag" || bad "R3 rc=$RC $ERR"

# R4. Stale registration -> 3 with prune hint.
run --repo "$T/app" --branch r4
rm -rf "$T/app-worktrees/r4"
run --repo "$T/app" --branch r4
[[ $RC -eq 3 ]] && grep -q 'worktree prune' <<<"$ERR" && ok "R4 stale registration -> 3" || bad "R4 rc=$RC $ERR"
git -C "$T/app" worktree prune

# R5. Dry run and real run print the same canonical path through a symlink.
L="$(dirname "$T")/sandlink"; ln -sfn "$T" "$L"
run --repo "$T/app" --branch r5 --dest "$L/r5-wt/" --dry-run; D1="$OUT"
run --repo "$T/app" --branch r5 --dest "$L/r5-wt/"; D2="$OUT"
[[ "$D1" == "$D2" && "$D2" == "$T/r5-wt" ]] && ok "R5 dry-run path == real path" || bad "R5 '$D1' vs '$D2'"
run --repo "$T/app" --branch r5b --dest "$T/x/../y" --dry-run
[[ $RC -eq 2 ]] && ok "R5 dotdot dest -> 2" || bad "R5 dotdot rc=$RC"

# R7. --skip plugin beats --enable-plugin.
run --repo "$T/app" --branch r7 --skip plugin --enable-plugin a@b --dry-run
grep -q 'plugins:    none' <<<"$ERR" && ok "R7 skip plugin wins" || bad "R7: $ERR"

# R9. --local outside the repo -> 2.
run --repo "$T/app" --branch r9 --local ../outside.txt --dry-run
[[ $RC -eq 2 ]] && ok "R9 local with .. -> 2" || bad "R9 rc=$RC"

# R10. Re-run keeps worktree edits to locals.
echo EDITED > "$WT/.env"
run --repo "$T/app" --branch feature/foo
[[ "$(cat "$WT/.env")" == EDITED ]] && grep -q 'kept   .env' <<<"$ERR" && ok "R10 re-run keeps edited local" || bad "R10: $(cat "$WT/.env")"

echo "== $PASS passed, $FAIL failed ($BASH_BIN)"
[[ $FAIL -eq 0 ]]
