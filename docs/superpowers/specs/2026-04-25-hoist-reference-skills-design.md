# Hoist Reference Skills — Design

**Status:** Approved through brainstorming. Ready for implementation planning.
**Date:** 2026-04-25
**Repo:** `xh/hoist-ai` (the `xh` Claude Code plugin)

## Goal

Ship two model-invokable skills that guide AI coding agents to consult Hoist's reference tools (MCP servers and CLIs) when about to author Hoist code, rather than improvising APIs from training data. Both skills are additive to the existing `xh` plugin and are designed to remain useful as Hoist's tooling story evolves (deployed MCPs, hoist-core CLI, etc.).

## Problem

Today, guidance on how to use the Hoist reference tools (`mcp__hoist-react__*`, `npx hoist-docs`, `npx hoist-ts`, the hoist-core MCP, and a forthcoming hoist-core CLI) reaches downstream Hoist application projects only through the `CLAUDE.md` block written by the `onboard-app` skill. This is duplicated into every app's CLAUDE.md, drifts as the tools evolve, and competes with all other CLAUDE.md content for the agent's attention. Worse: it does nothing for the agent's *fire-on-doubt* instinct. The agent has to remember to consult the tools at the right moments, and the existing wording is too passive to influence behavior reliably.

A model-invokable skill solves both: it carries the workflow guidance in one place (no duplication), and it fires *when needed* — at the moment the agent is about to write Hoist code. Two skills (one per library) let the trigger descriptions stay specific, which is essential for accurate firing.

## Scope

### In scope

- Two new skills in the existing `xh` plugin: `using-hoist-react-reference` and `using-hoist-core-reference`.
- Routing tables that map workflow verbs to MCP-tool and CLI invocations.
- Plugin-level permission updates so the new tools fire without prompts.
- Changes to the `onboard-app` skill's CLAUDE.md template (trim the "Hoist Developer Tools" section in favor of the new skills).
- Eval-driven test plan using `skill-creator`.

### Out of scope

- Changes to the existing `onboard-app`, `hoist-upgrade`, or `feedback` skills beyond the template trim and a single line in onboarding's report.
- Authoring the hoist-core CLI itself (handled in the hoist-core repo by a separate agent).
- Standing up deployed MCP servers (handled in the hoist-react and hoist-core repos).
- CI integration of skill evals (release-readiness check only, run before `plugin.json` version bumps).

## Architecture

Both skills ship from the existing `xh` plugin (in `hoist-ai/skills/`), alongside the three existing explicit-only skills:

```
hoist-ai/
  skills/
    onboard-app/                       (existing, explicit-only)
    hoist-upgrade/                     (existing, explicit-only)
    feedback/                          (existing, explicit-only)
    using-hoist-react-reference/       (NEW, model-invokable)
      SKILL.md
      evals/
        evals.json
    using-hoist-core-reference/        (NEW, model-invokable)
      SKILL.md
      evals/
        evals.json
```

Both new skills are **model-invokable** (no `disable-model-invocation` flag). They are the first model-invokable skills in this plugin; the existing three serve a different purpose (procedural workflows the developer triggers explicitly) and stay as they are.

The two new skills are structurally parallel: same frontmatter shape, same SKILL.md sections in the same order, same routing-table pattern. They differ only in:

- Trigger description language (TypeScript/React vs Groovy/Grails signals).
- Routing-table contents (different MCP tool names, different CLI commands).
- Example queries and pitfalls drawn from each library's domain.

Distribution piggybacks on the existing plugin: one `/plugin install xh@hoist-ai` gets a developer all five skills.

## Trigger descriptions

The `description` field is the single highest-leverage part of the design. A model-invokable skill only helps if it fires reliably when needed and stays silent otherwise. Both descriptions follow the same template: **what the skill is for + when to fire (with concrete framework symbols and path signals) + the imperative ("don't guess, look up first") + a skip clause**.

### `using-hoist-react-reference`

> Authoritative reference for the `@xh/hoist` React framework. Use when about to write or modify TypeScript/React code under a Hoist app's `client-app/` directory that consumes Hoist APIs — components (`hoistCmp`), models (`HoistModel`), services (`HoistService`), the `XH` singleton, decorators (`@bindable`, `@managed`, `@observable`, `@action`), or framework patterns (element factories, persistence, MobX integration). Do not guess at prop names, method signatures, decorators, or conventions — consult the reference tools first. Skip for code outside `client-app/` or for TypeScript work that doesn't import from `@xh/hoist`.

### `using-hoist-core-reference`

> Authoritative reference for the `io.xh:hoist-core` Grails/Groovy framework. Use when about to write or modify Groovy/Java backend code (typically under `grails-app/` or `src/`) that consumes hoist-core APIs — services (`BaseService`), controllers (`BaseController`, `RestController`), domain types (`HoistUser`, `Cache`, `CachedValue`, `Timer`, `Filter`), framework annotations, or patterns (cluster services, config service, monitoring, JSON client). Do not guess at class names, method signatures, annotations, or conventions — consult the reference tools first. Skip for non-Hoist Grails/Groovy code or pure Spring/Hibernate work that doesn't import from `io.xh.hoist`.

### Design choices in the wording

- **Concrete framework symbols.** Listing `HoistModel`, `BaseService`, `XH`, etc. gives the matcher reliable signals. Generic "Hoist code" is too vague.
- **Path signals.** React side uses a hard "skip for code outside `client-app/`" because the pattern is universal across Hoist apps. Core side uses a soft "typically under `grails-app/` or `src/`" because Grails apps put tooling/config at the root.
- **Explicit skip clause.** Cuts down false-positive fires on plain React or plain Grails code. False positives erode trust faster than misses.
- **The imperative is in the description, not just the body.** Descriptions are read at trigger time. Putting "do not guess, consult the reference tools first" in the description nudges fire-on-doubt behavior.

If Claude Code later exposes a structured directory-scoped skill activation mechanism (e.g. `path-globs` in frontmatter), the path constraints lift out of the description into config. Until then, the description is where they live.

## Skill body structure

Each `SKILL.md` has the same five sections in the same order:

1. **Routing table** — interface map (MCP tool / CLI command per workflow step).
2. **Workflow** — the canonical search → drill → disambiguate pattern.
3. **Common queries** — 4-6 worked examples per skill, drawn from realistic agent tasks. Each example shows both interfaces side-by-side.
4. **Common pitfalls** — known failure modes (e.g. searching for a UI concept by the wrong name, confusing a `*Config` interface with its consuming class, symbol disambiguation by path when names collide).
5. **When the tools aren't available** — explicit fallback for sandboxed environments. Tells the agent to surface the gap to the user rather than improvising.

### Routing table — `using-hoist-react-reference`

| Step | MCP tool | CLI command |
|---|---|---|
| Search docs | `mcp__hoist-react__hoist-search-docs` | `npx hoist-docs search "<query>"` |
| List docs by category | `mcp__hoist-react__hoist-list-docs` | `npx hoist-docs list -c <category>` |
| Read a specific doc | `mcp__hoist-react__hoist-search-docs` (with id) | `npx hoist-docs read <docId>` |
| Search symbols / members | `mcp__hoist-react__hoist-search-symbols` | `npx hoist-ts search "<query>"` |
| Get symbol details | `mcp__hoist-react__hoist-get-symbol` | `npx hoist-ts symbol <name>` |
| List class members | `mcp__hoist-react__hoist-get-members` | `npx hoist-ts members <name>` |

### Routing table — `using-hoist-core-reference`

The hoist-core skill carries the parallel table. MCP-tool names from `hoist-core/mcp/README.md` (e.g. `mcp__hoist-core__hoist-core-search-docs`, `mcp__hoist-core__hoist-core-search-symbols`). The CLI column is filled in once the hoist-core CLI lands in `xh/hoist-core` (work in flight in a parallel agent session). Until then, the implementation plan should leave the column shaped but unpopulated; the version that ships v1 of the skill must include the CLI commands.

### Workflow narrative (shared shape)

> Start broad: search docs and symbols by keyword. Multi-word queries are AND-matched against names and JSDoc/Groovydoc — useful for finding things by behavior. Drill in with `get-symbol` or `get-members` once you know the exact name. When two symbols share a name (e.g. `View` exists in `cmp/viewmanager` and `data/cube`), pass the source path to disambiguate. Read the relevant README from the docs index when starting in a new feature area before authoring code.

The agent picks the routing-table column based on what's in its tool context — MCP names visible → use those; otherwise use the CLI column. Transport (local stdio vs deployed MCP) is invisible to the agent: the MCP tool names look the same regardless of how the server is hosted.

## Distribution and permissions

### Plugin manifest bump

`.claude-plugin/plugin.json`: `1.1.0` → `1.2.0`. `marketplace.json` version follows.

### Plugin-level permissions

`hoist-ai/settings.json` (plugin-root, shipped with the plugin — not `.claude/settings.json`, which is for plugin-development only) adds:

```jsonc
"allow": [
  // existing
  "mcp__hoist-react__*",
  // new
  "mcp__hoist-core__*",
  "Bash(npx hoist-docs:*)",
  "Bash(npx hoist-ts:*)",
  "Bash(npx hoist-core-docs:*)",   // command name TBD — align with hoist-core CLI shipping
  "Bash(npx hoist-core-ts:*)"      // command name TBD — align with hoist-core CLI shipping
]
```

Wildcards (`Bash(npx hoist-docs:*)`) approve all subcommands without per-invocation prompts. This is essential — a reference lookup that triggers a permission prompt is slower than a guess, defeating the skill's purpose.

The hoist-core CLI command names are placeholders. The implementation plan must align them with whatever the hoist-core CLI agent picks before shipping.

### No new MCP server config

Onboarding (`/xh:onboard-app`) already wires up `hoist-react` MCP per-project. We extend onboarding to wire up `hoist-core` MCP when detected, but that's a small additive change to the existing onboarding skill — not new infrastructure for the new skills.

### Onboarding template changes

`onboard-app`'s CLAUDE.md template drops its "Hoist Developer Tools and Documentation" section. That content moves into the two new skills. The template keeps coding conventions, architecture primer, and project-specific guidance. A short replacement line acknowledges the skills:

> "When working with Hoist code, the `using-hoist-react-reference` and `using-hoist-core-reference` skills will guide reference lookups. They fire automatically when you're about to author Hoist code."

This single line in CLAUDE.md is cheap insurance — primes the agent to expect the skills and gives a human reading the file a pointer to where the workflow guidance lives.

### Onboarding output report

The Phase 6 report in `onboard-app/SKILL.md` gains:

> "Reference skills: `using-hoist-react-reference` and `using-hoist-core-reference` available — will fire when authoring Hoist code."

### Versioning discipline

Per `hoist-ai/CLAUDE.md`: bump `plugin.json` version before push. Marketplace consumers pick up updates automatically. No coordinated release between hoist-ai and hoist-react/hoist-core — the skills depend on tools shipped by the libraries, not the other way around. When the hoist-core CLI lands, ship a 1.2.x bump that adds the CLI commands to the routing table.

## Testing — `skill-creator` evals

We use `skill-creator`'s built-in eval framework as the test harness. Concretely:

```
skills/using-hoist-react-reference/
  SKILL.md
  evals/
    evals.json                 # eval prompts (positives + negatives)
# plus a workspace sibling created during runs:
using-hoist-react-reference-workspace/
  iteration-1/
    eval-add-grid-column/
      eval_metadata.json       # assertions
      with_skill/outputs/      # runs with the skill enabled
      baseline/outputs/        # runs without it (for comparison)
    eval-non-hoist-util/
      ...
```

### Workflow

1. Author `evals/evals.json` per skill — each entry is a prompt with a descriptive name.
2. Invoke `skill-creator` and let it dispatch the matrix in parallel (`scripts/run_eval.py`) — it spawns with-skill and baseline runs in the same turn, materializes the workspace tree, and aggregates metrics via `aggregate_benchmark.py`.
3. Use `eval-viewer/generate_review.py` to inspect qualitative outputs alongside quantitative metrics.
4. If results don't meet the bar, use `scripts/improve_description.py` to iterate on the trigger description against the same eval set.

### Acceptance bar (v1)

- ≥90% positive recall (skill fires when it should).
- ≤10% false-positive rate (skill stays silent when it shouldn't).

These are first-pass thresholds. Real numbers from `skill-creator` will surface whether 90/10 is too strict or too loose; we adjust before locking the v1 release.

### Eval set per skill: 8-12 prompts

Smaller sets work because `skill-creator` runs each prompt multiple times for variance analysis. Prompts come from this matrix:

| # | Skill | Type | Scenario | Test app file |
|---|---|---|---|---|
| 1 | React | + | "How would you add a sortable column to this grid?" | a Toolbox `client-app/src/...Panel.tsx` |
| 2 | React | + | "Wire this model to the panel below" | Toolbox panel + model |
| 3 | React | + | "Add a `@bindable` field to this model" | Toolbox model |
| 4 | React | + | "Look up which service method fetches X" | Toolbox service |
| 5 | React | + | "Configure persistence on this model" | Toolbox model |
| 6 | React | - | "Refactor this util function to be more concise" | `client-app/src/utils/...` (no Hoist imports) |
| 7 | React | - | "Bump the version in package.json" | Toolbox `client-app/package.json` |
| 8 | React | - | "Edit this README" | Toolbox README |
| 9 | Core | + | "Add a method to this service that fetches X" | a Toolbox `grails-app/services/...Service.groovy` |
| 10 | Core | + | "Add a new endpoint to this controller" | Toolbox `BaseController` subclass |
| 11 | Core | + | "Configure caching on this service" | Toolbox service using `Cache` |
| 12 | Core | + | "Wire up cluster service notifications" | Toolbox service |
| 13 | Core | + | "Look up the right annotation for X" | Toolbox class |
| 14 | Core | - | "Refactor this util Groovy class" | non-Hoist Groovy |
| 15 | Core | - | "Add a Spring controller endpoint" | non-Hoist controller (or fixture) |
| 16 | Core | - | "Edit `build.gradle`" | Toolbox root `build.gradle` |

### Test app: Toolbox only

Toolbox is the public, canonical Hoist demo app and exercises both `client-app/` and `grails-app/` layouts. One repo is sufficient. Private XH apps are not used as test fixtures and are not referenced in any committed test materials.

### No CI gate

The eval suite is a release-readiness check before each `plugin.json` version bump, not a per-commit gate. The implementation plan codifies this as a one-line note in `hoist-ai/CLAUDE.md`:

> "Before bumping `plugin.json`, run `skill-creator` evals against both reference skills."

### Iteration is a feature

The workspace is structured around `iteration-1/`, `iteration-2/`, etc. — explicitly designed for the description-tuning loop. We expect to iterate post-launch as we observe real triggering behavior.

## Open items for the implementation plan

These are decisions deliberately deferred to `writing-plans`:

- Exact format of `evals.json` entries (`skill-creator` schema in `references/schemas.md`).
- Final hoist-core CLI command names and routing-table population (depends on hoist-core CLI shipping).
- Whether the per-skill `evals/` directory is committed to the repo or `.gitignore`'d (the workspace tree definitely is — generated artifact).
- Sequencing: ship `using-hoist-react-reference` first if hoist-core CLI is delayed, or hold both for a single 1.2.0 release.

## Honest constraints

- **Skill firing is probabilistic.** Even with high eval scores, "85% accuracy on 30 examples" is not "always correct." Expect occasional misses and false positives in production. Iterate.
- **No test runner for triggering exists outside of `skill-creator`.** The harness's matcher is not introspectable. We work with what `skill-creator` measures.
- **Description tuning is the long tail.** The plan must accept that description language will evolve post-launch and the eval set will grow with real-world failure modes.
