---
name: hoist-upgrade
description: Upgrade a Hoist app's `@xh/hoist` dependency across one or more major versions. Reads per-version upgrade guides, auto-applies mechanical code migrations, flags judgment calls, checks the hoist-react version-compatibility matrix and bumps `@xh/hoist-dev-utils` when the target version requires or recommends it, bumps `hoistCoreVersion` (and refreshes the hoist-core MCP+CLI launchers if previously installed), and produces a comprehensive upgrade report.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, mcp__hoist-react__hoist-ping, mcp__hoist-react__hoist-search-docs, mcp__hoist-react__hoist-list-docs, mcp__hoist-react__hoist-read-doc, mcp__hoist-react__hoist-get-symbol, mcp__hoist-react__hoist-search-symbols, mcp__hoist-react__hoist-get-members
---

# Hoist Version Upgrade

Upgrade this Hoist project's `@xh/hoist` dependency between versions. Follow each phase in order.
Each phase has its detailed steps in a file in the `reference/` folder beside this SKILL.md. Read
that file when the phase starts, and follow it from start to end. If you cannot find the folder,
search for `**/hoist-upgrade/reference/detect.md`.

## Rules for Every Phase

- Make no change until the developer confirms the plan in Phase 2, and start from a clean working
  tree.
- Never commit on `main`, `master`, or `develop`. Commit once per version hop.
- Read upgrade notes and other installed docs from `client-app/node_modules/@xh/hoist/`, with a
  file read or a shell command. Some harnesses' search tools skip the gitignored `node_modules`.
- After the first install, use the hoist-react CLI, not the MCP tools, until the MCP server is
  reconnected in Phase 4. The server still describes the old version.
- Never write a caret range on a SNAPSHOT version. In canary mode, the spec stays `next`.

## Phase 1: Detect

### Parse arguments

Check the user's request for an optional target version (e.g. `81.0.0` or `v81`). If present,
normalize it: strip any leading `v`, store as the target version for Phase 2. If no version is
given, the skill will prompt the developer to choose a target in Phase 2.

Then follow [reference/detect.md](reference/detect.md) for the rest of the detection: package
manager, installed versions, canary mode, the working tree, hoist-core, and client plugins.

## Phase 2: Plan

Follow [reference/plan.md](reference/plan.md). It picks the target, splits the upgrade into hops,
checks the compatibility matrix and the guides, and shows the plan. Ask **"Proceed with this
upgrade plan? (yes/no)"** and wait for the answer.

## Phase 3: Execute

Follow [reference/execute.md](reference/execute.md) for each hop: bump and install, read the
guide, apply the migrations, check hoist-core and hoist-dev-utils, and commit. After the last
hop, refresh the agent docs.

## Phase 4: Verify

Follow [reference/verify.md](reference/verify.md): the developer-tool surfaces, `tsc`, lint, and
after a major hop the build, the dev server, and the tests.

## Phase 5: Report

Follow [reference/report.md](reference/report.md). Render the summary in the chat, and say
plainly what still fails.
