# Changelog

## 1.4.6 - 2026-05-18

* `using-hoist-core-reference`: added a snippet-currency check to the preflight. The install
  snippet now ships with `// hoist-ai-snippet: hoist-core-install/v<N>` open/close markers so
  the skill can detect when an app's pasted snippet has drifted from the canonical (e.g. the
  Gradle API improvements landed in 1.4.4/1.4.5). On stale-snippet detection, the skill walks
  the user through an in-place refresh that preserves any local hand-edits. Working launchers
  keep working through the check -- the refresh is non-blocking and surfaced once per session.

## 1.4.5 - 2026-05-18

* `using-hoist-core-reference`: install snippet re-synced with the canonical
  `hoist-core/mcp/README.md`. Brings in the bash launcher's `java`/`JAVA_HOME` fallback
  for non-interactive MCP-client shells, the auto-emitted `bin/.gitignore`, and the
  `layout.buildDirectory` replacement for deprecated `$buildDir`. Procedure step 6
  rewritten to reflect the auto-scoped ignore -- no more two-stance commit/ignore choice.

## 1.4.4 - 2026-05-18

* `using-hoist-core-reference`: install snippet resolves the active hoist-core version
  lazily from the runtime classpath via a Provider. Eliminates the prior fallback that
  pushed agents to hardcode a version when hoist-core came in transitively via a client
  plugin.

## 1.4.3 - 2026-05-15

* Both reference-skill `description:` fields shortened to fit under Claude Code's per-skill
  listing cap. Previous versions exceeded the cap and were being silently truncated, dropping
  TRIGGER/SKIP detail before reaching the model. Trimmed symbol lists, redundant concept
  examples, and overspecific carve-outs while preserving the "Why this matters" lead and
  the TRIGGER/SKIP structure.

## 1.4.2 - 2026-05-14

* **Bug fix:** `using-hoist-react-reference` launcher content moved out of SKILL.md fenced
  code blocks into `templates/` files, copied byte-exact at install. Embedded fenced content
  was losing a literal `$0` somewhere in the loading pipeline, yielding broken launchers.
  Launcher stamp bumped to force refresh of any mangled installs; preflight gains a smoke check.
* Narrowed `using-hoist-react-reference` TRIGGER to changes that introduce or modify Hoist
  API usage, carving out config-only refactors that pass values through a Hoist component to
  a third-party lib (Highcharts, AG-Grid).
* Both reference-skill descriptions: replaced "ALWAYS use this skill when..." with a "Why
  this matters:" lead citing concrete failure modes.

## 1.4.1 - 2026-05-14

* Rewrote both reference-skill `description:` fields per skill-creator best practices:
  single-paragraph format, concrete TRIGGER/SKIP blocks with keyword anchors.
* Added trigger eval sets for both reference skills, re-runnable via skill-creator.
* CLAUDE.md: softened the eval bar to directional guidance -- the trigger-eval script has a
  measurement ceiling when simulating skills as slash commands.

## 1.4.0 - 2026-05-14

* `using-hoist-react-reference`: project-root CLI launchers (`bin/hoist-docs`, `bin/hoist-ts`)
  wrap the `@xh/hoist` binaries so agents can invoke them from the harness's default cwd.
  Eliminates the "must run from `client-app/`" gotcha; the skill owns install.
* Both reference skills: once-per-session preflight verifies launcher presence and stamp,
  with idempotent reinstall on drift. Plugin updates that bump the stamp self-propagate.
* `onboard-app`: no longer wires the hoist-react CLI -- the reference skill installs it lazily.

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
