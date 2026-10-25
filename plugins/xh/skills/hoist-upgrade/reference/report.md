# Phase 5: Report

Render a structured upgrade summary directly in the chat. Do NOT write a report file --
the conversation is the artifact. If the developer wants it persisted, they can copy it
or ask you to save it somewhere specific.

## 1. Render the summary

Print the following as a single Markdown response. Use short prose and lists; lean on
tables only where they genuinely help (e.g. the hop overview). Skip optional sections
when they don't apply.

```markdown
## Hoist Upgrade Complete: @xh/hoist v{FROM} -> v{TO}

- **Hops:** {N} ({comma-separated hop list, e.g. v77 -> v78, v78 -> v79})
- **Branch:** {branch name}
- **Package manager:** {yarn | npm | pnpm}
- **Spec:** {`^{TO}` | `next` (canary)}

### Hop Overview

| Hop | Difficulty | Changes | Judgment Calls | Status |
|-----|------------|---------|----------------|--------|
| v{a} -> v{b} | {TRIVIAL/LOW/MEDIUM/HIGH} | {n} | {n} | {ok / failed} |
| ...

### Per-Hop Detail

#### v{a} -> v{b} ({difficulty}, guide: {upgrade-notes | CHANGELOG})

**Mechanical changes applied:**
- `{file}` -- {what changed}
- ...

**Judgment calls (require your review):**
- **{item}** -- {one-line description}
  - Files: {comma-separated}
  - Guide recommendation: {recommendation}

{Repeat per hop. Omit empty subsections.}

### Verification

- TypeScript (`tsc --noEmit`): {pass | fail with brief detail}
- Lint: {pass | fail with brief detail}
- Production build: {pass | fail | not run}
- Dev server startup: {pass | fail | not run}
- Tests: {pass | fail per suite | no suite | not run}
- hoist-react CLI (`npx hoist-docs index`): {ok | error}
- hoist-react MCP reconnect: {reconnected | skipped | failed}
- hoist-core CLI (if launchers refreshed): {ok | error | N/A}

### hoist-core Changes
{Include only if hoistCoreVersion was bumped.}

- {old} -> {new} (required by {hop or guide reference})
- Launchers: {refreshed via installHoistCoreTools, ping verified | not previously installed -- skipped}
- {If significant server-side code was detected in Phase 1, add a one-line note that
  server-side review is recommended.}

### hoist-dev-utils Changes
{Include only if @xh/hoist-dev-utils was bumped.}

- {old} -> {new} (required/recommended for hoist-react v{version} per the compatibility matrix)
- {Note any new Node version floor or config changes from the dev-utils CHANGELOG.}

### Agent Docs
{Include only if Phase 3j changed anything.}

- {file}: {what changed, e.g. "regenerated the Hoist primer for TC39 decorators"}

### Client Plugin Notes
{Include only if client plugins were detected.}

- `{plugin}`: {old} -> {new or unchanged} -- {notes}

### Next Steps
- [ ] Review the judgment calls above and apply as appropriate
- [ ] Test affected features (especially anything in judgment calls)
- [ ] Run the app and verify core functionality
{Include if hoist-core was bumped:}
- [ ] Review hoist-core release notes if this project has significant server-side code
{Include if hoist-dev-utils was bumped across a major with a new Node floor:}
- [ ] Confirm CI / build agents meet the new minimum Node version
{Include if hoistCoreVersion >= 39.0 AND bin/hoist-core-mcp does NOT exist:}
- [ ] Install the hoist-core MCP+CLI tools now that you're eligible (>= v39.0):
      run the `onboard-app` skill -- it will detect the new eligibility and offer to install
{Include if client plugins were detected:}
- [ ] Verify client plugin compatibility with the upgraded Hoist version
- [ ] Open / merge the pull request for this upgrade branch
```

Be honest in the verification section -- if `tsc` or lint failed and you and the developer
worked through the failures, summarize what was resolved. If something is still broken at
report time, say so plainly so the developer doesn't merge a half-green branch.
