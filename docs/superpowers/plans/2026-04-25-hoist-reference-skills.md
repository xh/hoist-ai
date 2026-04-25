# Hoist Reference Skills Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship two model-invokable skills (`using-hoist-react-reference` and `using-hoist-core-reference`) to the existing `xh` Claude Code plugin in the `hoist-ai` repo, with `skill-creator` eval suites for both, and update onboarding/permissions to match.

**Architecture:** Two parallel skills under `hoist-ai/skills/`, each with a routing-table-shaped `SKILL.md` that maps workflow steps to MCP-tool and CLI invocations. Eval suites under each skill's `evals/` directory drive validation via `skill-creator`'s framework. Plugin manifest, permissions, and onboarding template are updated in one coordinated 1.2.0 release.

**Tech Stack:** Markdown skills with YAML frontmatter, JSON eval specs, Claude Code plugin manifest format, `skill-creator` eval runner. No application code.

**Spec:** `docs/superpowers/specs/2026-04-25-hoist-reference-skills-design.md`

**Sequencing note:** The hoist-core CLI is being authored in parallel by another agent and may or may not be ready during this work. The plan builds the hoist-core skill with its CLI routing-table column populated as TBD placeholders. A late phase (Phase 9) gates the v1.2.0 release on CLI availability — if CLI is ready, populate the column and ship; if not, ship 1.2.0 with the React skill only and follow up with 1.2.1 once the CLI lands.

---

## File Structure

**Create:**
- `hoist-ai/skills/using-hoist-react-reference/SKILL.md`
- `hoist-ai/skills/using-hoist-react-reference/evals/evals.json`
- `hoist-ai/skills/using-hoist-react-reference/evals/files/SamplePanel.tsx`
- `hoist-ai/skills/using-hoist-react-reference/evals/files/SampleModel.ts`
- `hoist-ai/skills/using-hoist-react-reference/evals/files/plain-util.ts`
- `hoist-ai/skills/using-hoist-core-reference/SKILL.md`
- `hoist-ai/skills/using-hoist-core-reference/evals/evals.json`
- `hoist-ai/skills/using-hoist-core-reference/evals/files/SampleService.groovy`
- `hoist-ai/skills/using-hoist-core-reference/evals/files/SampleController.groovy`
- `hoist-ai/skills/using-hoist-core-reference/evals/files/PlainSpringController.groovy`

**Modify:**
- `hoist-ai/.claude-plugin/plugin.json` (version bump 1.1.0 → 1.2.0)
- `hoist-ai/.claude-plugin/marketplace.json` (version follows)
- `hoist-ai/settings.json` (permission allowlist additions)
- `hoist-ai/skills/onboard-app/SKILL.md` (Phase 6 report — add skill availability line)
- `hoist-ai/skills/onboard-app/templates/claude-md-base.md` (drop "Hoist Developer Tools" section; add skill-pointer line)
- `hoist-ai/CLAUDE.md` (add release-readiness note about evals)

---

## Phase 1: Branch and scaffold

### Task 1.1: Create feature branch in hoist-ai

**Files:** none (git op)

- [ ] **Step 1: Verify hoist-ai is on clean main**

```bash
git -C /Users/amcclain/dev/hoist-ai status --short
git -C /Users/amcclain/dev/hoist-ai branch --show-current
```
Expected: empty status output; branch `main`.

- [ ] **Step 2: Create feature branch**

```bash
git -C /Users/amcclain/dev/hoist-ai checkout -b feat/hoist-reference-skills
```
Expected: `Switched to a new branch 'feat/hoist-reference-skills'`

### Task 1.2: Scaffold skill directories

**Files:**
- Create: `hoist-ai/skills/using-hoist-react-reference/evals/files/`
- Create: `hoist-ai/skills/using-hoist-core-reference/evals/files/`

- [ ] **Step 1: Create directory tree**

```bash
mkdir -p /Users/amcclain/dev/hoist-ai/skills/using-hoist-react-reference/evals/files
mkdir -p /Users/amcclain/dev/hoist-ai/skills/using-hoist-core-reference/evals/files
```

- [ ] **Step 2: Verify**

```bash
ls /Users/amcclain/dev/hoist-ai/skills/
```
Expected: includes `feedback`, `hoist-upgrade`, `onboard-app`, `using-hoist-core-reference`, `using-hoist-react-reference`.

---

## Phase 2: Author React skill

### Task 2.1: Create sample fixture files for React eval set

**Files:**
- Create: `hoist-ai/skills/using-hoist-react-reference/evals/files/SamplePanel.tsx`
- Create: `hoist-ai/skills/using-hoist-react-reference/evals/files/SampleModel.ts`
- Create: `hoist-ai/skills/using-hoist-react-reference/evals/files/plain-util.ts`

These fixtures mimic Toolbox-style code without any client-specific references. They give eval prompts realistic file context while keeping the eval suite self-contained.

- [ ] **Step 1: Write `SamplePanel.tsx`**

```typescript
import {hoistCmp} from '@xh/hoist/core';
import {grid} from '@xh/hoist/cmp/grid';
import {panel} from '@xh/hoist/desktop/cmp/panel';
import {SamplePanelModel} from './SampleModel';

export const SamplePanel = hoistCmp.factory({
    model: SamplePanelModel,
    render({model}) {
        return panel({
            title: 'Sample',
            items: [grid({model: model.gridModel})]
        });
    }
});
```

- [ ] **Step 2: Write `SampleModel.ts`**

```typescript
import {HoistModel, managed} from '@xh/hoist/core';
import {GridModel} from '@xh/hoist/cmp/grid';
import {bindable} from '@xh/hoist/mobx';

export class SamplePanelModel extends HoistModel {
    @managed gridModel: GridModel;
    @bindable filterText: string = '';

    constructor() {
        super();
        this.makeObservable();
        this.gridModel = new GridModel({
            columns: [
                {field: 'name'},
                {field: 'value'}
            ]
        });
    }
}
```

- [ ] **Step 3: Write `plain-util.ts` (non-Hoist fixture)**

```typescript
export function formatNumber(value: number, decimals = 2): string {
    if (value == null || isNaN(value)) return '';
    return value.toFixed(decimals);
}

export function isBlank(s: string | null | undefined): boolean {
    return s == null || s.trim().length === 0;
}
```

### Task 2.2: Author React skill eval set

**Files:**
- Create: `hoist-ai/skills/using-hoist-react-reference/evals/evals.json`

The eval set drives validation. It contains 5 positive prompts (skill should fire and the agent should consult the reference tools) and 3 negative prompts (skill should NOT fire). Each `expectations` entry is a verifiable statement the grader can check against the agent's transcript.

- [ ] **Step 1: Write `evals.json`**

```json
{
  "skill_name": "using-hoist-react-reference",
  "evals": [
    {
      "id": 1,
      "prompt": "I want to add a sortable column to the grid in SamplePanel.tsx that displays a derived 'doubled' value. Show me how.",
      "expected_output": "The agent invokes the using-hoist-react-reference skill, looks up the GridModel column config via the reference tools, and proposes a column definition with a sortable derived field.",
      "files": ["evals/files/SamplePanel.tsx", "evals/files/SampleModel.ts"],
      "expectations": [
        "The skill `using-hoist-react-reference` was invoked",
        "The agent called either `mcp__hoist-react__hoist-search-symbols` or `npx hoist-ts search` (or `hoist-get-members` / `hoist-ts members`) to look up GridModel column config",
        "The agent did not improvise prop names without verification"
      ]
    },
    {
      "id": 2,
      "prompt": "Add a new @bindable field called 'sortField' (string, default 'name') to SamplePanelModel and use it in the grid.",
      "expected_output": "The agent invokes the skill, confirms the @bindable decorator's behavior via reference tools, and adds the property correctly with default value.",
      "files": ["evals/files/SampleModel.ts"],
      "expectations": [
        "The skill `using-hoist-react-reference` was invoked",
        "The agent consulted the reference tools (MCP or CLI) for @bindable semantics",
        "The proposed code uses `@bindable sortField: string = 'name'` (or equivalent) and does not invent setter signatures"
      ]
    },
    {
      "id": 3,
      "prompt": "Configure persistence on SamplePanelModel so the filterText survives page reloads.",
      "expected_output": "The agent invokes the skill, looks up Hoist's persistence support, and proposes the right config.",
      "files": ["evals/files/SampleModel.ts"],
      "expectations": [
        "The skill `using-hoist-react-reference` was invoked",
        "The agent searched docs or symbols for persistence (e.g. `persistWith`, `PersistenceProvider`)",
        "The agent did not improvise persistence setup without consulting the framework"
      ]
    },
    {
      "id": 4,
      "prompt": "What is the correct way to wire up an autorun that reacts to filterText changes on SamplePanelModel? Show me the code.",
      "expected_output": "The agent invokes the skill, looks up addAutorun/addReaction on HoistBase, and shows correct usage.",
      "files": ["evals/files/SampleModel.ts"],
      "expectations": [
        "The skill `using-hoist-react-reference` was invoked",
        "The agent consulted reference tools for HoistBase / addAutorun / addReaction",
        "The proposed code uses `this.addAutorun(...)` (or `addReaction`) and does not import autorun from MobX directly"
      ]
    },
    {
      "id": 5,
      "prompt": "I'm new to Hoist. Show me where to start reading docs to understand Models, Components, and Services.",
      "expected_output": "The agent invokes the skill, queries the docs index, and surfaces the relevant README locations.",
      "files": [],
      "expectations": [
        "The skill `using-hoist-react-reference` was invoked",
        "The agent called the docs index tool (`hoist-search-docs` with no/empty query, `hoist-list-docs`, or `npx hoist-docs index`)",
        "The agent referenced specific Hoist docs by id (e.g. `core/README.md`, `svc/README.md`)"
      ]
    },
    {
      "id": 6,
      "prompt": "Refactor `formatNumber` in plain-util.ts to be more concise. Don't introduce dependencies.",
      "expected_output": "The agent does NOT invoke the using-hoist-react-reference skill. This is plain TypeScript with no Hoist imports.",
      "files": ["evals/files/plain-util.ts"],
      "expectations": [
        "The skill `using-hoist-react-reference` was NOT invoked",
        "The agent refactored the function without consulting Hoist reference tools"
      ]
    },
    {
      "id": 7,
      "prompt": "Bump the version field in this package.json from 1.0.0 to 1.0.1.",
      "expected_output": "The agent does NOT invoke the using-hoist-react-reference skill. This is a pure config change with no Hoist code authoring.",
      "files": [],
      "expectations": [
        "The skill `using-hoist-react-reference` was NOT invoked"
      ]
    },
    {
      "id": 8,
      "prompt": "Add a `isBlank` overload to plain-util.ts that accepts an array and returns true when the array is empty or contains only blank strings.",
      "expected_output": "The agent does NOT invoke the using-hoist-react-reference skill. Plain TypeScript, no Hoist.",
      "files": ["evals/files/plain-util.ts"],
      "expectations": [
        "The skill `using-hoist-react-reference` was NOT invoked",
        "The agent added the overload without referring to Hoist tools"
      ]
    }
  ]
}
```

- [ ] **Step 2: Validate JSON**

```bash
python3 -c "import json; json.load(open('/Users/amcclain/dev/hoist-ai/skills/using-hoist-react-reference/evals/evals.json'))"
```
Expected: silent success (parses cleanly).

### Task 2.3: Author `using-hoist-react-reference/SKILL.md`

**Files:**
- Create: `hoist-ai/skills/using-hoist-react-reference/SKILL.md`

- [ ] **Step 1: Write `SKILL.md`**

````markdown
---
name: using-hoist-react-reference
description: Authoritative reference for the @xh/hoist React framework. Use when about to write or modify TypeScript/React code under a Hoist app's `client-app/` directory that consumes Hoist APIs - components (`hoistCmp`), models (`HoistModel`), services (`HoistService`), the `XH` singleton, decorators (`@bindable`, `@managed`, `@observable`, `@action`), or framework patterns (element factories, persistence, MobX integration). Do not guess at prop names, method signatures, decorators, or conventions - consult the reference tools first. Skip for code outside `client-app/` or for TypeScript work that doesn't import from `@xh/hoist`.
allowed-tools: Read, Bash, mcp__hoist-react__hoist-ping, mcp__hoist-react__hoist-search-docs, mcp__hoist-react__hoist-list-docs, mcp__hoist-react__hoist-search-symbols, mcp__hoist-react__hoist-get-symbol, mcp__hoist-react__hoist-get-members
---

# Using Hoist React Reference

You're about to write or modify code that consumes the `@xh/hoist` framework. Consult the reference tools before authoring - Hoist's API surface is large, prop names and decorators are easy to misremember, and a wrong guess produces code that compiles but fails at runtime.

## Routing table

Each workflow step has two interfaces. Use the column that matches what's in your tool context.

| Step | MCP tool | CLI command |
|---|---|---|
| Search docs | `mcp__hoist-react__hoist-search-docs` | `npx hoist-docs search "<query>"` |
| List docs by category | `mcp__hoist-react__hoist-list-docs` | `npx hoist-docs list -c <category>` |
| Read a specific doc | `mcp__hoist-react__hoist-search-docs` (with id query) | `npx hoist-docs read <docId>` |
| Search symbols / members | `mcp__hoist-react__hoist-search-symbols` | `npx hoist-ts search "<query>"` |
| Get symbol details | `mcp__hoist-react__hoist-get-symbol` | `npx hoist-ts symbol <name>` |
| List class members | `mcp__hoist-react__hoist-get-members` | `npx hoist-ts members <name>` |

If `mcp__hoist-react__*` tools are listed in your tool context, prefer them. Otherwise use the CLI column. The MCP tool names look the same regardless of whether the server is running locally or as a deployed remote endpoint - transport is invisible to you.

## Workflow

Standard sequence for any Hoist authoring task:

1. **Index first.** Read the docs index (`mcp__hoist-react__hoist-search-docs` with no query, `mcp__hoist-react__hoist-list-docs`, or `npx hoist-docs index`) when you're new to the area. Find the right README.
2. **Search docs** for context on conventions, architecture, common pitfalls in the area you're touching.
3. **Search symbols** for specific class/method/decorator names. Multi-word queries are AND-matched against names AND JSDoc - `"panel modal"` finds `ModalSupportModel` via its JSDoc.
4. **Drill** with `get-symbol` for full details, or `get-members` to list a class's properties and methods with types and decorators.
5. **Disambiguate** by passing `filePath` when symbol names collide (e.g. `View` exists in both `cmp/viewmanager` and `data/cube`).

## Common queries

**Look up a component's available props.**
- MCP: `mcp__hoist-react__hoist-get-members` with `name: "GridConfig"` (or whatever `*Config` interface fronts the component).
- CLI: `npx hoist-ts members GridConfig`

**Find which decorator a model property uses.**
- MCP: `mcp__hoist-react__hoist-get-members` with `name: "<MyModelClass>"`.
- CLI: `npx hoist-ts members <MyModelClass>`

**Look up a service method by behavior, not name.**
- MCP: `mcp__hoist-react__hoist-search-symbols` with `query: "fetch loadConfigs"` (multi-word AND match against names + JSDoc).
- CLI: `npx hoist-ts search "fetch loadConfigs"`

**Find the convention for something cross-cutting (persistence, theming, lifecycle).**
- MCP: `mcp__hoist-react__hoist-search-docs` with `query: "persistence MobX integration"`.
- CLI: `npx hoist-docs search "persistence MobX integration"`

**Read the docs index.**
- MCP: `mcp__hoist-react__hoist-list-docs` (or `hoist-search-docs` with empty query).
- CLI: `npx hoist-docs index` (shorthand for `read docs/README.md`).

**Print coding conventions.**
- MCP: `mcp__hoist-react__hoist-search-docs` with `query: "coding conventions"` then read the matching id.
- CLI: `npx hoist-docs conventions`

## Common pitfalls

- **Searching by display name, not symbol name.** Querying `"modal"` may miss the answer. Use multi-word queries that include behavior keywords (`"panel modal"`) - JSDoc matching surfaces symbols whose names don't include the term.
- **Confusing a `*Config` interface with its consuming class.** `GridModel` (the class) and `GridConfig` (its config interface) both exist. `GridModel`'s properties are runtime state; `GridConfig`'s are configuration knobs. Use `members` on whichever you actually need - they answer different questions.
- **Symbol disambiguation.** When `search-symbols` returns multiple matches with the same name (e.g. `View` in `cmp/viewmanager` AND `data/cube`), the tool will hint that you should pass a file path. Do so.
- **Falling back to `Read` on framework source.** If the reference tools answer the question, prefer them - they expose JSDoc and decorator info more cleanly than reading source. Read the source only as a last resort.
- **Trusting training data.** Hoist's API has evolved. Decorators have changed names, base classes have moved. Always verify with the reference tools before authoring.

## When the tools aren't available

If neither MCP tools (`mcp__hoist-react__*`) nor the CLI (`npx hoist-docs`, `npx hoist-ts`) are present in your context, stop and tell the user. Do not improvise Hoist APIs from training data - prop names, decorators, and conventions evolve, and stale guesses produce real bugs.

If the project has `@xh/hoist` installed locally, you may use the `Read` tool to read package READMEs (e.g. `client-app/node_modules/@xh/hoist/core/README.md`) as a last resort. Surface the limitation to the user; the recommended fix is to ensure the plugin's MCP server or CLI is wired up via `/xh:onboard-app`.
````

- [ ] **Step 2: Validate frontmatter**

```bash
head -5 /Users/amcclain/dev/hoist-ai/skills/using-hoist-react-reference/SKILL.md
```
Expected: opens with `---`, has `name:` and `description:` lines, no `disable-model-invocation`.

### Task 2.4: Commit React skill scaffold

- [ ] **Step 1: Stage and commit**

```bash
git -C /Users/amcclain/dev/hoist-ai add skills/using-hoist-react-reference
git -C /Users/amcclain/dev/hoist-ai commit -m "$(cat <<'EOF'
Add using-hoist-react-reference skill with eval suite

First model-invokable skill in the xh plugin. Routes the agent to either
the hoist-react MCP tools or the hoist-docs/hoist-ts CLI commands when
authoring code that consumes @xh/hoist APIs. Eval suite under evals/
covers 5 positive triggers and 3 negatives, with sample TS fixtures for
the agent to act on.

Generated with Claude Opus 4.7 (1M context)
EOF
)"
```

---

## Phase 3: Author hoist-core skill

### Task 3.1: Create sample fixture files for hoist-core eval set

**Files:**
- Create: `hoist-ai/skills/using-hoist-core-reference/evals/files/SampleService.groovy`
- Create: `hoist-ai/skills/using-hoist-core-reference/evals/files/SampleController.groovy`
- Create: `hoist-ai/skills/using-hoist-core-reference/evals/files/PlainSpringController.groovy`

- [ ] **Step 1: Write `SampleService.groovy`**

```groovy
package sample

import io.xh.hoist.BaseService
import io.xh.hoist.cache.Cache

class SampleService extends BaseService {

    Cache<String, Map> dataCache = new Cache(svc: this, expireTime: 60_000)

    Map fetchData(String id) {
        dataCache.getOrCreate(id) { -> loadData(id) }
    }

    private Map loadData(String id) {
        return [id: id, value: Math.random()]
    }
}
```

- [ ] **Step 2: Write `SampleController.groovy`**

```groovy
package sample

import io.xh.hoist.BaseController
import org.grails.web.json.JSONObject

class SampleController extends BaseController {

    SampleService sampleService

    def fetchData(String id) {
        renderJSON(sampleService.fetchData(id))
    }

    def listAll() {
        renderJSON([items: []])
    }
}
```

- [ ] **Step 3: Write `PlainSpringController.groovy` (non-Hoist fixture)**

```groovy
package sample

import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RestController

@RestController
class PlainSpringController {

    @GetMapping('/health')
    Map health() {
        return [status: 'ok']
    }
}
```

### Task 3.2: Author hoist-core skill eval set

**Files:**
- Create: `hoist-ai/skills/using-hoist-core-reference/evals/evals.json`

- [ ] **Step 1: Write `evals.json`**

```json
{
  "skill_name": "using-hoist-core-reference",
  "evals": [
    {
      "id": 1,
      "prompt": "Add a method to SampleService that fetches a list of items, with caching. Use Hoist's caching primitives.",
      "expected_output": "The agent invokes the using-hoist-core-reference skill, looks up Cache or Timer in the reference tools, and proposes a method that uses them correctly.",
      "files": ["evals/files/SampleService.groovy"],
      "expectations": [
        "The skill `using-hoist-core-reference` was invoked",
        "The agent called either `mcp__hoist-core__hoist-core-search-symbols` or `mcp__hoist-core__hoist-core-get-members` (or the CLI equivalent if available) to look up Cache",
        "The proposed code uses Hoist's `Cache` (or `CachedValue`/`Timer`) class, not a hand-rolled map"
      ]
    },
    {
      "id": 2,
      "prompt": "Add a new endpoint to SampleController that returns paged results. Use Hoist conventions.",
      "expected_output": "The agent invokes the skill, looks up BaseController's render helpers, and proposes an endpoint using `renderJSON` (or similar).",
      "files": ["evals/files/SampleController.groovy"],
      "expectations": [
        "The skill `using-hoist-core-reference` was invoked",
        "The agent consulted the reference tools for BaseController members or render conventions",
        "The proposed endpoint uses Hoist's render helper (e.g. `renderJSON`) and follows the pattern in the existing methods"
      ]
    },
    {
      "id": 3,
      "prompt": "How do I expose a Hoist config to SampleService so it reads a configurable refresh interval?",
      "expected_output": "The agent invokes the skill, queries docs/symbols for ConfigService, and proposes the right injection and access pattern.",
      "files": ["evals/files/SampleService.groovy"],
      "expectations": [
        "The skill `using-hoist-core-reference` was invoked",
        "The agent looked up ConfigService (or `configService` injection) via the reference tools",
        "The proposed code reads the config via Hoist's mechanism, not a hardcoded value or environment variable"
      ]
    },
    {
      "id": 4,
      "prompt": "Add cluster-aware behavior to SampleService so cache invalidation broadcasts to other nodes.",
      "expected_output": "The agent invokes the skill, looks up ClusterService or distributed cache patterns, and proposes the right approach.",
      "files": ["evals/files/SampleService.groovy"],
      "expectations": [
        "The skill `using-hoist-core-reference` was invoked",
        "The agent searched docs/symbols for cluster, ClusterService, or distributed cache",
        "The proposed solution uses Hoist's cluster primitives (e.g. ClusterService, distributed Cache)"
      ]
    },
    {
      "id": 5,
      "prompt": "I'm new to hoist-core. Show me where to start reading docs to understand BaseService, BaseController, and the common services.",
      "expected_output": "The agent invokes the skill, queries the docs index, and surfaces the relevant README locations.",
      "files": [],
      "expectations": [
        "The skill `using-hoist-core-reference` was invoked",
        "The agent called the docs index tool (`hoist-core-list-docs`, `hoist-core-search-docs` with broad query, or CLI equivalent if available)",
        "The agent referenced specific hoist-core docs by id"
      ]
    },
    {
      "id": 6,
      "prompt": "Add a /health endpoint to PlainSpringController that includes the JVM uptime in milliseconds. Don't introduce dependencies.",
      "expected_output": "The agent does NOT invoke the using-hoist-core-reference skill. This is plain Spring with no hoist-core imports.",
      "files": ["evals/files/PlainSpringController.groovy"],
      "expectations": [
        "The skill `using-hoist-core-reference` was NOT invoked",
        "The agent added the endpoint without consulting hoist-core reference tools"
      ]
    },
    {
      "id": 7,
      "prompt": "Add a `dependencies` block stub to a fresh build.gradle for a Spring Boot project. No hoist-core needed.",
      "expected_output": "The agent does NOT invoke the using-hoist-core-reference skill.",
      "files": [],
      "expectations": [
        "The skill `using-hoist-core-reference` was NOT invoked"
      ]
    },
    {
      "id": 8,
      "prompt": "Refactor PlainSpringController so the health response key uses the constant 'STATUS_KEY' defined in a sibling Constants class.",
      "expected_output": "The agent does NOT invoke the using-hoist-core-reference skill.",
      "files": ["evals/files/PlainSpringController.groovy"],
      "expectations": [
        "The skill `using-hoist-core-reference` was NOT invoked",
        "The agent refactored without consulting hoist-core tools"
      ]
    }
  ]
}
```

- [ ] **Step 2: Validate JSON**

```bash
python3 -c "import json; json.load(open('/Users/amcclain/dev/hoist-ai/skills/using-hoist-core-reference/evals/evals.json'))"
```
Expected: silent success.

### Task 3.3: Author `using-hoist-core-reference/SKILL.md`

**Files:**
- Create: `hoist-ai/skills/using-hoist-core-reference/SKILL.md`

The CLI column in the routing table uses placeholder commands (`<TBD>`) marked clearly. Phase 9 swaps these for real CLI commands once the hoist-core CLI lands.

- [ ] **Step 1: Write `SKILL.md`**

````markdown
---
name: using-hoist-core-reference
description: Authoritative reference for the io.xh:hoist-core Grails/Groovy framework. Use when about to write or modify Groovy/Java backend code (typically under `grails-app/` or `src/`) that consumes hoist-core APIs - services (`BaseService`), controllers (`BaseController`, `RestController`), domain types (`HoistUser`, `Cache`, `CachedValue`, `Timer`, `Filter`), framework annotations, or patterns (cluster services, config service, monitoring, JSON client). Do not guess at class names, method signatures, annotations, or conventions - consult the reference tools first. Skip for non-Hoist Grails/Groovy code or pure Spring/Hibernate work that doesn't import from `io.xh.hoist`.
allowed-tools: Read, Bash, mcp__hoist-core__hoist-core-ping, mcp__hoist-core__hoist-core-search-docs, mcp__hoist-core__hoist-core-list-docs, mcp__hoist-core__hoist-core-search-symbols, mcp__hoist-core__hoist-core-get-symbol, mcp__hoist-core__hoist-core-get-members
---

# Using Hoist Core Reference

You're about to write or modify Groovy/Java backend code that consumes the `io.xh:hoist-core` framework. Consult the reference tools before authoring - hoist-core's API surface is large, base-class semantics are easy to misremember, and a wrong guess produces code that compiles but fails at runtime.

## Routing table

Each workflow step has two interfaces. Use the column that matches what's in your tool context.

| Step | MCP tool | CLI command |
|---|---|---|
| Search docs | `mcp__hoist-core__hoist-core-search-docs` | `<TBD: hoist-core CLI not yet shipped>` |
| List docs by category | `mcp__hoist-core__hoist-core-list-docs` | `<TBD>` |
| Search symbols / members | `mcp__hoist-core__hoist-core-search-symbols` | `<TBD>` |
| Get symbol details | `mcp__hoist-core__hoist-core-get-symbol` | `<TBD>` |
| List class members | `mcp__hoist-core__hoist-core-get-members` | `<TBD>` |

If `mcp__hoist-core__*` tools are listed in your tool context, prefer them. The CLI column will be populated when the hoist-core CLI ships - until then, MCP is the only path. The MCP tool names look the same regardless of whether the server is running locally or as a deployed remote endpoint.

## Workflow

Standard sequence for any hoist-core authoring task:

1. **Index first.** Use `mcp__hoist-core__hoist-core-list-docs` (or search with a broad query) when you're new to the area. Find the right doc.
2. **Search docs** for context on conventions, architecture, and common patterns in the area you're touching.
3. **Search symbols** for specific class/method names. Multi-word queries are AND-matched against names AND Groovydoc.
4. **Drill** with `get-symbol` for full details, or `get-members` to list a class's properties and methods with types and annotations.
5. **Disambiguate** by passing `filePath` when symbol names collide.

Member-indexed classes (those whose public members are individually searchable): `BaseService`, `BaseController`, `RestController`, `HoistUser`, `Cache`, `CachedValue`, `Timer`, `Filter`, `FieldFilter`, `CompoundFilter`, `JSONClient`, `ClusterService`, `ConfigService`, `MonitorResult`, `LogSupport`, `HttpException`, `IdentitySupport`. Use `search-symbols` with a member name (e.g. `getOrCreate`, `expireTime`) to find which of these classes provides it.

## Common queries

**Look up the methods on `BaseService`.**
- MCP: `mcp__hoist-core__hoist-core-get-members` with `name: "BaseService"`.

**Find which class provides a method like `getOrCreate`.**
- MCP: `mcp__hoist-core__hoist-core-search-symbols` with `query: "getOrCreate"` - returns matching symbols and matching members with their owning class.

**Find the convention for something cross-cutting (caching, monitoring, cluster).**
- MCP: `mcp__hoist-core__hoist-core-search-docs` with `query: "cache cluster"` (multi-word AND match).

**Read the docs index.**
- MCP: `mcp__hoist-core__hoist-core-list-docs` (with no `category` param).

**Look up an annotation or trait by name.**
- MCP: `mcp__hoist-core__hoist-core-get-symbol` with `name: "<TraitName>"`. Use `kind: trait` on `search-symbols` to filter.

## Common pitfalls

- **Hand-rolling caching.** hoist-core ships `Cache`, `CachedValue`, and `Timer`. Search for them before writing your own.
- **Guessing controller render helpers.** `BaseController` provides `renderJSON`, `renderJSONP`, exception handling, and identity support. Look it up via `get-members` instead of using raw Grails `render`.
- **Mistaking ClusterService for raw Hazelcast.** hoist-core wraps cluster operations in `ClusterService` with conventions for monitoring, replication, and identity. Use it through that wrapper.
- **Stomping on the cluster boundary.** Some `Cache` configurations are local; some are distributed. Read the Cache docs and use the right form.
- **Falling back to reading framework source.** If the reference tools answer the question, prefer them - they expose Groovydoc and annotations more cleanly than reading source. Read the source only as a last resort.

## When the tools aren't available

If `mcp__hoist-core__*` tools are not present in your context (and the CLI is not yet shipped), stop and tell the user. Do not improvise hoist-core APIs from training data - class names and member signatures evolve, and stale guesses produce real bugs.

If the project has hoist-core checked out as a sibling repo, you may use `Read` to consult its docs (`docs/`) or source as a last resort. Surface the limitation to the user; the recommended fix is to ensure the plugin's hoist-core MCP server is wired up via `/xh:onboard-app`.
````

- [ ] **Step 2: Validate frontmatter**

```bash
head -5 /Users/amcclain/dev/hoist-ai/skills/using-hoist-core-reference/SKILL.md
```
Expected: opens with `---`, has `name:` and `description:` lines, no `disable-model-invocation`.

### Task 3.4: Commit hoist-core skill scaffold

- [ ] **Step 1: Stage and commit**

```bash
git -C /Users/amcclain/dev/hoist-ai add skills/using-hoist-core-reference
git -C /Users/amcclain/dev/hoist-ai commit -m "$(cat <<'EOF'
Add using-hoist-core-reference skill with eval suite

Sister skill to using-hoist-react-reference, structured identically.
Routes the agent to the hoist-core MCP tools when authoring Groovy/Java
code that consumes io.xh:hoist-core APIs. CLI column in the routing
table is left as TBD placeholder pending the hoist-core CLI ship -
phase 9 of the implementation plan swaps these for real commands.

Generated with Claude Opus 4.7 (1M context)
EOF
)"
```

---

## Phase 4: Plugin manifest and permissions

### Task 4.1: Update plugin manifest version

**Files:**
- Modify: `hoist-ai/.claude-plugin/plugin.json:4`
- Modify: `hoist-ai/.claude-plugin/marketplace.json:11`

- [ ] **Step 1: Bump `plugin.json` version**

Read `hoist-ai/.claude-plugin/plugin.json`. Change `"version": "1.1.0"` to `"version": "1.2.0"`.

- [ ] **Step 2: Bump `marketplace.json` plugin entry version**

Read `hoist-ai/.claude-plugin/marketplace.json`. Change the inner `"version": "1.0.0"` to `"version": "1.2.0"` (note: the existing value is stale; align both manifests).

- [ ] **Step 3: Verify**

```bash
grep -E '"version"' /Users/amcclain/dev/hoist-ai/.claude-plugin/plugin.json /Users/amcclain/dev/hoist-ai/.claude-plugin/marketplace.json
```
Expected: both show `"version": "1.2.0"`.

### Task 4.2: Update plugin permissions

**Files:**
- Modify: `hoist-ai/settings.json` (plugin-root, shipped with the plugin)

- [ ] **Step 1: Replace `permissions.allow` with consolidated wildcard form**

Read `hoist-ai/settings.json`. Replace the entire `permissions.allow` array with:

```json
"allow": [
  "mcp__hoist-react__*",
  "mcp__hoist-core__*",
  "Bash(npx hoist-docs:*)",
  "Bash(npx hoist-ts:*)"
]
```

The hoist-core CLI command names (`Bash(npx hoist-core-docs:*)`, etc.) are NOT added in this phase - we don't pre-approve commands that don't exist yet. Phase 9 adds them when the CLI ships.

Also add `"hoist-core"` to the `enabledMcpjsonServers` array, alongside the existing `"hoist-react"`. Final `settings.json` shape:

```json
{
  "enabledMcpjsonServers": ["hoist-react", "hoist-core"],
  "permissions": {
    "allow": [
      "mcp__hoist-react__*",
      "mcp__hoist-core__*",
      "Bash(npx hoist-docs:*)",
      "Bash(npx hoist-ts:*)"
    ]
  }
}
```

- [ ] **Step 2: Validate JSON**

```bash
python3 -c "import json; json.load(open('/Users/amcclain/dev/hoist-ai/settings.json'))"
```
Expected: silent success.

### Task 4.3: Commit manifest and permissions changes

- [ ] **Step 1: Stage and commit**

```bash
git -C /Users/amcclain/dev/hoist-ai add .claude-plugin/plugin.json .claude-plugin/marketplace.json settings.json
git -C /Users/amcclain/dev/hoist-ai commit -m "$(cat <<'EOF'
Bump plugin to 1.2.0 and pre-approve hoist-react CLI + hoist-core MCP

Adds wildcard permissions for the hoist-core MCP tool family (consumed
by the new using-hoist-core-reference skill) and the hoist-react CLI
(consumed by using-hoist-react-reference when MCP tools aren't
available). Enables hoist-core in the default MCP server set.

Hoist-core CLI permissions are intentionally omitted here - the CLI
hasn't shipped yet and pre-approving non-existent commands is a
correctness hazard. Phase 9 adds them once the CLI lands.

Also aligns marketplace.json version (was stale at 1.0.0) with
plugin.json.

Generated with Claude Opus 4.7 (1M context)
EOF
)"
```

---

## Phase 5: Onboarding template trim

### Task 5.1: Trim CLAUDE.md template

**Files:**
- Modify: `hoist-ai/skills/onboard-app/templates/claude-md-base.md`

The current template includes a "Hoist Developer Tools and Documentation" section that duplicates content now living in the new skills. We remove it and add a single skill-pointer line in its place.

- [ ] **Step 1: Read the current template**

```bash
wc -l /Users/amcclain/dev/hoist-ai/skills/onboard-app/templates/claude-md-base.md
```
Read the file. Locate the section header for "Hoist Developer Tools and Documentation" (or equivalent — it may be titled slightly differently). Note the start and end line numbers of the section, including any subsections about MCP tools and CLI usage.

- [ ] **Step 2: Replace the section**

Use Edit to remove the entire "Hoist Developer Tools and Documentation" section (and any subsections discussing MCP tool listings or CLI usage that belong with it). Replace with a single subsection:

```markdown
## Hoist Reference Skills

When working with Hoist code, the `using-hoist-react-reference` and `using-hoist-core-reference` skills (shipped by the `xh` Claude Code plugin) will guide reference lookups. They fire automatically when you're about to author Hoist code and route you to the right MCP tools or CLI commands. You don't need to invoke them manually.

If the skills aren't firing or the underlying tools aren't available, run `/xh:onboard-app` to verify the plugin and MCP servers are wired up.
```

Preserve all other sections of the template (architecture primer, coding conventions, hoist-core, commands, client plugins, etc.).

- [ ] **Step 3: Verify the trim**

```bash
grep -n "Hoist Developer Tools" /Users/amcclain/dev/hoist-ai/skills/onboard-app/templates/claude-md-base.md
grep -n "Hoist Reference Skills" /Users/amcclain/dev/hoist-ai/skills/onboard-app/templates/claude-md-base.md
```
Expected: first command returns nothing; second returns the new heading line.

### Task 5.2: Update onboarding Phase 6 report

**Files:**
- Modify: `hoist-ai/skills/onboard-app/SKILL.md` (Phase 6 report block, around line 264)

- [ ] **Step 1: Add reference skills line to the report block**

Read `hoist-ai/skills/onboard-app/SKILL.md`. Find the Phase 6 report fenced block (the one that starts with `## Onboarding Complete`). Add a new bullet after the `MCP server` bullet:

```markdown
- **Reference skills:** `using-hoist-react-reference` and `using-hoist-core-reference` available - will fire automatically when authoring Hoist code.
```

- [ ] **Step 2: Verify**

```bash
grep -n "Reference skills" /Users/amcclain/dev/hoist-ai/skills/onboard-app/SKILL.md
```
Expected: one match in the Phase 6 report block.

### Task 5.3: Commit onboarding changes

- [ ] **Step 1: Stage and commit**

```bash
git -C /Users/amcclain/dev/hoist-ai add skills/onboard-app
git -C /Users/amcclain/dev/hoist-ai commit -m "$(cat <<'EOF'
Trim onboarding template; point to new reference skills instead

Remove the "Hoist Developer Tools and Documentation" section from
claude-md-base.md - that workflow guidance now lives in the
using-hoist-react-reference and using-hoist-core-reference skills.
Replace with a single pointer subsection so anyone reading a generated
CLAUDE.md knows where to look.

Onboarding Phase 6 report gains a line confirming the skills are
available.

Generated with Claude Opus 4.7 (1M context)
EOF
)"
```

---

## Phase 6: Plugin CLAUDE.md update

### Task 6.1: Add eval-before-bump note

**Files:**
- Modify: `hoist-ai/CLAUDE.md`

- [ ] **Step 1: Add release-readiness note**

Read `hoist-ai/CLAUDE.md`. Find the "Development Workflow" or "Key Rules" section. Add a new bullet under "Key Rules":

```markdown
- Before bumping `plugin.json` version, run `skill-creator` evals against both reference skills (`using-hoist-react-reference` and `using-hoist-core-reference`) and confirm acceptance bars (≥90% positive recall, ≤10% false-positive rate) are met. The eval suites live under each skill's `evals/` directory.
```

- [ ] **Step 2: Commit**

```bash
git -C /Users/amcclain/dev/hoist-ai add CLAUDE.md
git -C /Users/amcclain/dev/hoist-ai commit -m "$(cat <<'EOF'
Document skill-eval gate before plugin version bumps

Every release of the xh plugin that touches a model-invokable skill
must pass skill-creator evals before the manifest version bump. Add
this rule to the plugin's own CLAUDE.md so future contributors see it.

Generated with Claude Opus 4.7 (1M context)
EOF
)"
```

---

## Phase 7: Run React skill evals

### Task 7.1: Invoke skill-creator to run React skill evals

This task runs the eval suite for `using-hoist-react-reference` via `skill-creator`'s `Skill` tool. The runner dispatches with-skill and baseline runs, materializes the workspace tree, and produces metrics.

- [ ] **Step 1: Invoke the `skill-creator` skill**

Use the Skill tool with `skill-creator:skill-creator`. Pass instructions that direct it to:
- Run evals from `/Users/amcclain/dev/hoist-ai/skills/using-hoist-react-reference/evals/evals.json`
- Use the existing skill at `/Users/amcclain/dev/hoist-ai/skills/using-hoist-react-reference/`
- Run 3 iterations per configuration for variance analysis
- Save workspace to `/Users/amcclain/dev/hoist-ai/skills/using-hoist-react-reference-workspace/iteration-1/`

- [ ] **Step 2: Inspect the results**

Once the run completes, read the aggregated `benchmark.json` from the workspace and check:
- `run_summary.with_skill.pass_rate.mean` ≥ 0.90 for positive evals (1-5)
- `run_summary.with_skill.pass_rate.mean` for negative evals (6-8): the "skill was NOT invoked" assertion should pass — i.e. expectations met ≥ 0.90.

- [ ] **Step 3: Decide whether to iterate**

If both bars are met, mark Phase 7 complete and move on. If a bar is missed, run Task 7.2 below.

### Task 7.2: Iterate React skill description (only if Task 7.1 acceptance fails)

- [ ] **Step 1: Run the description-improvement script**

Invoke `skill-creator` again with instructions to use `improve_description.py` against the same eval set. Cap at 3 iterations.

- [ ] **Step 2: After each iteration, verify**

Re-check the bars from Task 7.1 Step 2. If after 3 iterations the bars still aren't met, stop and surface the result to the user — likely the description language needs human revision rather than further automated tuning.

- [ ] **Step 3: Commit any description changes**

```bash
git -C /Users/amcclain/dev/hoist-ai add skills/using-hoist-react-reference/SKILL.md
git -C /Users/amcclain/dev/hoist-ai commit -m "Tune using-hoist-react-reference description based on eval results

[Briefly summarize the change and the metric improvement it produced.]

Generated with Claude Opus 4.7 (1M context)"
```

The workspace tree is gitignored (Phase 8 below adds the rule), so the iteration artifacts are not committed.

---

## Phase 8: Run hoist-core skill evals

### Task 8.1: Add workspace artifacts to .gitignore

**Files:**
- Modify: `hoist-ai/.gitignore`

The skill-creator workspace trees are generated artifacts and should not be committed.

- [ ] **Step 1: Append workspace patterns to .gitignore**

Read `hoist-ai/.gitignore`. Append:

```
# skill-creator eval workspace artifacts (generated, not committed)
skills/*-workspace/
```

- [ ] **Step 2: Commit the .gitignore change**

```bash
git -C /Users/amcclain/dev/hoist-ai add .gitignore
git -C /Users/amcclain/dev/hoist-ai commit -m "Ignore skill-creator workspace trees

The workspace directories created by skill-creator during eval runs
contain transcripts, metrics, and intermediate artifacts. Generated;
not committed.

Generated with Claude Opus 4.7 (1M context)"
```

### Task 8.2: Invoke skill-creator to run hoist-core skill evals

- [ ] **Step 1: Invoke the `skill-creator` skill**

Same shape as Task 7.1, but for `using-hoist-core-reference`:
- Eval set: `/Users/amcclain/dev/hoist-ai/skills/using-hoist-core-reference/evals/evals.json`
- Skill: `/Users/amcclain/dev/hoist-ai/skills/using-hoist-core-reference/`
- Workspace: `/Users/amcclain/dev/hoist-ai/skills/using-hoist-core-reference-workspace/iteration-1/`

- [ ] **Step 2: Inspect the results**

Same acceptance bars as Task 7.1.

- [ ] **Step 3: Iterate description if needed**

Mirror Task 7.2 if the bars aren't met.

---

## Phase 9: Hoist-core CLI alignment (CONDITIONAL — only when CLI ships)

This phase is gated on the hoist-core CLI shipping. The user has a parallel agent authoring the CLI in the hoist-core repo. When the CLI is available and its docs are updated, run this phase before bumping `plugin.json` to a publishable version.

If the CLI is NOT yet ready when Phase 8 completes, **stop here**. The plugin remains at version 1.2.0 on the feature branch but should not be merged to main until the CLI ships. Surface this to the user explicitly.

### Task 9.1: Populate CLI commands in hoist-core SKILL.md routing table

**Files:**
- Modify: `hoist-ai/skills/using-hoist-core-reference/SKILL.md` (routing table block)

- [ ] **Step 1: Determine the actual hoist-core CLI command names**

Read the hoist-core repo's docs (likely `hoist-core/mcp/README.md` or a new `hoist-core/cli/README.md`) to confirm the exact `bin` entries shipped by hoist-core. Expected names follow the hoist-react pattern: `hoist-core-docs` and `hoist-core-symbols` (or similar). The user has indicated they will update those docs when the CLI ships.

- [ ] **Step 2: Replace the `<TBD>` placeholders in the routing table**

Use Edit to replace each `<TBD>` cell with the actual CLI command, mirroring the hoist-react skill's table shape.

### Task 9.2: Add hoist-core CLI permissions to plugin settings

**Files:**
- Modify: `hoist-ai/settings.json`

- [ ] **Step 1: Add CLI permission entries**

Add two entries to `permissions.allow`, aligned with the actual command names from Task 9.1:

```json
"Bash(npx hoist-core-docs:*)",
"Bash(npx hoist-core-symbols:*)"
```

(Replace command names if hoist-core picks different ones.)

### Task 9.3: Re-run hoist-core skill evals with CLI rows populated

- [ ] **Step 1: Invoke skill-creator**

Same as Task 8.2 but with the updated SKILL.md. This is a regression check — adding the CLI column shouldn't degrade the trigger description's accuracy, but verify.

### Task 9.4: Commit CLI alignment

- [ ] **Step 1: Stage and commit**

```bash
git -C /Users/amcclain/dev/hoist-ai add skills/using-hoist-core-reference/SKILL.md settings.json
git -C /Users/amcclain/dev/hoist-ai commit -m "$(cat <<'EOF'
Populate hoist-core CLI commands in routing table; pre-approve them

The hoist-core CLI shipped in <hoist-core version>. Replace TBD
placeholders in the using-hoist-core-reference routing table with
the real command names and add wildcard Bash permissions for them
to the plugin's settings.json.

Generated with Claude Opus 4.7 (1M context)
EOF
)"
```

---

## Phase 10: Final verification and merge prep

### Task 10.1: Final repo state check

- [ ] **Step 1: Confirm clean tree**

```bash
git -C /Users/amcclain/dev/hoist-ai status --short
```
Expected: empty.

- [ ] **Step 2: Inspect commit log**

```bash
git -C /Users/amcclain/dev/hoist-ai log --oneline main..HEAD
```
Expected: 5-7 commits implementing the plan, on the feature branch.

- [ ] **Step 3: Sanity-check the directory tree**

```bash
find /Users/amcclain/dev/hoist-ai/skills -name SKILL.md | sort
ls /Users/amcclain/dev/hoist-ai/skills/using-hoist-react-reference/
ls /Users/amcclain/dev/hoist-ai/skills/using-hoist-core-reference/
```
Expected: 5 SKILL.md files (3 existing + 2 new); each new skill dir contains `SKILL.md` and `evals/`.

### Task 10.2: Surface release readiness to user

- [ ] **Step 1: Report status**

Summarize for the user:
- What landed on the feature branch (skill files, plugin manifest bump, permissions, onboarding trim)
- Whether the hoist-core CLI alignment (Phase 9) ran or was deferred
- Eval pass rates from Phase 7 and Phase 8
- Whether the branch is ready to merge to `main` or is gated on hoist-core CLI shipping

The user decides when to merge to `main` (which auto-publishes the plugin via marketplace pickup).

---

## Self-review notes

- **Spec coverage:** All sections of the spec have at least one task — architecture (Phase 2 + 3), trigger descriptions (locked into SKILL.md frontmatter in Tasks 2.3 and 3.3), skill body (Tasks 2.3 and 3.3), distribution and permissions (Phase 4), onboarding template trim (Phase 5), CLAUDE.md note (Phase 6), eval-driven testing (Phases 7 + 8), conditional CLI alignment (Phase 9).
- **No placeholders in code:** Every SKILL.md, evals.json, and fixture file has its complete content in the plan body. The hoist-core skill's routing table includes `<TBD>` cells, but those are intentional content (visible to readers as TBD) — replaced in Phase 9 with concrete commands.
- **Type/name consistency:** MCP tool names (`mcp__hoist-react__hoist-search-docs`, `mcp__hoist-core__hoist-core-search-docs`, etc.) match the actual server emit. CLI commands (`hoist-docs`, `hoist-ts`) match `hoist-react/package.json` `bin` entries.
- **Sequencing:** Phase 9 is conditional and explicitly documented as such; Phase 10 surfaces the gate to the user.
