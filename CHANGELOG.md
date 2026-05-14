# Changelog

## 1.4.1 - 2026-05-14

* Rewrote `description:` frontmatter for both reference skills (`using-hoist-react-reference`,
  `using-hoist-core-reference`) following skill-creator best practices: single-paragraph format
  with no blank-line breaks (so the full text reaches the model -- the harness truncates display
  at blank lines), concrete TRIGGER and SKIP blocks anchoring on real symbols and keywords agents
  encounter in practice, directive "ALWAYS use this skill when..." framing to combat the model's
  default undertriggering tendency.
* Added trigger eval sets at `skills/<skill>/evals/trigger.json` (20 react queries, 23 core
  queries) covering positive cases across the full skill surface and negative cases including
  near-misses with overlapping keywords (plain Spring, JPA, Liquibase, plain React/MobX, plain TS).
  Re-runnable via skill-creator's `run_eval.py`.
* Updated CLAUDE.md's eval-bar rule: noted that `run_eval.py` simulates skills as slash commands
  and has a measurement ceiling around 15% recall regardless of description quality, so the
  prior >=90% hard bar isn't directly attainable; reframed as directional guidance (FP near 0%,
  no recall regressions) plus the structural best practices above.

## 1.4.0 - 2026-05-14

* `using-hoist-react-reference`: introduced project-root CLI launchers (`./bin/hoist-docs`, `./bin/hoist-ts`) that wrap
  the `@xh/hoist`-shipped binaries through `client-app/node_modules/.bin/`. Agents now invoke the CLI from the harness's
  default working directory with no `cd` required, eliminating the recurring "must run from `client-app/`" gotcha. The
  skill owns the install procedure; onboarding no longer wires the CLI.
* `using-hoist-react-reference`: added a "Preflight (do once per session before first CLI use)" section. Agents verify
  launcher presence and a `# hoist-ai-launcher: hoist-react/v1` stamp at the top of each file. Missing or drifted
  launchers trigger an idempotent rewrite, so plugin updates that bump the stamp version self-propagate across all
  consuming apps on next agent invocation.
* `using-hoist-core-reference`: added a parallel Preflight section. Agents verify the three `./bin/hoist-core-*`
  launchers exist and that `./bin/hoist-core-docs ping` succeeds before first CLI use. Catches the common case where
  `./gradlew clean` wipes the JAR a launcher's absolute path points at — the fix is one idempotent
  `./gradlew installHoistCoreTools` re-run.
* `onboard-app`: stopped wiring the hoist-react CLI itself. Verification now reports launcher presence informationally
  and notes that the `using-hoist-react-reference` skill installs them automatically on first CLI use. Greenfield
  projects get the same end state, just lazily.
* Removed the "CLI working directory" advisory section from `using-hoist-react-reference` — the launcher pattern makes
  the advice moot.

## 1.3.3 - 2026-05-13

* `hoist-upgrade`: dropped the auto PR-creation step from Phase 5. The skill stops at
  the rendered summary; developers can ask the agent to follow up with whatever they
  want (open a PR, merge directly, etc.). Some environments don't have `gh` configured.
* `using-hoist-react-reference`: added a "CLI working directory" section reminding the
  agent that `npx hoist-docs` / `npx hoist-ts` must be run from `client-app/`, not the
  project root. Agents commonly stumbled on this in practice.

## 1.3.2 - 2026-05-01

* `hoist-upgrade`: Phase 5 now renders the upgrade report directly in the chat instead
  of writing a `docs/upgrade-reports/*.md` file into the consuming project. The
  conversation is the artifact; developers can persist or discard as they prefer.
  Removed the now-unused `templates/upgrade-report.md`.

## 1.3.1 - 2026-04-30

* `hoist-upgrade` and `onboard-app` are now model-invokable
  (`disable-model-invocation: true` removed from both). The agent will auto-discover
  them when developers describe matching intent. Slash-command invocation
  (`/xh:hoist-upgrade`, `/xh:onboard-app`) continues to work as before.

## 1.3.0 - 2026-04-30

* Added two model-invokable reference skills: `using-hoist-react-reference` (TypeScript /
  React, `client-app/`) and `using-hoist-core-reference` (Groovy / Java, server-side).
  Both route to MCP tools when available, CLI tools (`npx hoist-docs` / `npx hoist-ts` /
  `./bin/hoist-core-*`) otherwise, so MCP-blocked enterprise environments stay productive.
  Each ships with an `evals/` suite gated at >=90% recall / <=10% false-positive rate.
* `using-hoist-core-reference` is the canonical source for installing or upgrading the
  hoist-core MCP+CLI tools (`installHoistCoreTools` Gradle task, project-local `bin/`
  launchers).
* `onboard-app`: new Phase 3.5 detects whether the hoist-core MCP+CLI tools are installed
  and offers to install them when `hoistCoreVersion >= 39.0`. Phase 1 gained SNAPSHOT-aware
  version comparison. Verification reframed CLI-first / MCP-opportunistic so MCP-blocked
  environments don't stall.
* `hoist-upgrade`: Phase 3e refreshes project-local `bin/hoist-core-*` launchers when
  `hoistCoreVersion` is bumped (avoiding stale absolute JAR paths). Surfaces hoist-core
  MCP+CLI install eligibility when the bump crosses the v39.0 floor. Phase 4
  verification reframed CLI-first.
* Pre-approved `Bash(./bin/hoist-core-*:*)` and `Bash(./gradlew installHoistCoreTools:*)`
  in `settings.json` so consumers don't get prompt-flooded on the install happy path.
* Removed the `feedback` skill -- required `gh` auth and outbound to `xh/hoist-ai`,
  not viable in target enterprise environments.

## 1.1.0 - 2026-03-04

* MCP server config moved from the plugin's `.mcp.json` to per-project `.mcp.json`
  managed by the onboarding skill. Plugin-cache-relative paths weren't resolving in
  consuming projects; the project now owns the config.
* `onboard-app`: added client-plugin detection and an expanded CLAUDE.md template.

## 1.0.1 - 2026-03-04

* Fixed the plugin MCP config to point at the bundled hoist-react server.
* Added `enabledMcpjsonServers` so the hoist-react server is auto-approved on install.

## 1.0.0 - 2026-02-21

* Initial release. The `xh` plugin in the `hoist-ai` marketplace, with three skills:
  `onboard-app`, `hoist-upgrade`, and `feedback`.
