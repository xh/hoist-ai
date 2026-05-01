# Changelog

## Unreleased

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
