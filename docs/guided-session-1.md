# Guided Session 1: Plugin Installation and First AI-Assisted Task

**Goal:** Every XH developer installs the `xh` plugin, runs project onboarding, and
completes their first AI-assisted task.

**Duration:** ~60-90 minutes (30 min guided setup, 30-60 min working session)

**Prerequisites:** Claude Code installed and licensed, `gh` CLI authenticated (`gh auth status`),
a Hoist project checked out locally.

---

## Part 1: Plugin Installation (~10 min)

Walk through these steps together. Everyone should complete each step before moving on.

1. Open Claude Code in a Hoist project directory.
2. Add the XH marketplace:
   ```
   /plugin marketplace add xh/hoist-ai
   ```
3. Install the plugin:
   ```
   /plugin install xh@hoist-ai
   ```
4. Verify the plugin is active:
   ```
   /plugin list
   ```
   You should see `xh` in the list with its version and status.
5. **Expected outcome:** Plugin installed, hoist-react MCP server starts automatically. You
   should see the MCP server indicator in Claude Code's status.

## Part 2: Project Onboarding (~10 min)

1. Run the onboarding skill:
   ```
   /xh:onboard-app
   ```
2. Review the detection results -- the skill will identify:
   - @xh/hoist version (from `client-app/package.json`)
   - hoist-core version (from `gradle.properties`)
3. When prompted, confirm CLAUDE.md generation. The skill will create or merge a `CLAUDE.md`
   file at the project root with Hoist conventions and framework guidance.
4. The skill will automatically verify MCP server connectivity via `hoist-ping`.
5. **Expected outcome:** `CLAUDE.md` exists at the project root. MCP tools (`hoist-search-docs`,
   `hoist-search-symbols`, etc.) are available.

## Part 3: First AI-Assisted Task (~30-45 min)

Choose a starter task and work through it with Claude. These are real, useful tasks that
demonstrate the value of having Hoist convention knowledge (via CLAUDE.md) and framework
documentation (via the MCP server) immediately available.

### Starter Tasks (pick one)

**Simple -- Architecture Exploration**
> "Explain the architecture of this project's main model. What does it extend, what state does
> it manage, and how do its services connect?"

Claude will use MCP tools to look up base classes and documentation, giving you an accurate
answer grounded in current Hoist APIs rather than stale training data.

**Medium -- Add a Type Annotation**
> "Add missing TypeScript type annotations to [ModelName]. Use Hoist patterns -- look up the
> correct types for observable properties, action methods, and computed values."

Claude will reference Hoist conventions from CLAUDE.md and use `hoist-search-symbols` to find
the correct types.

**Advanced -- Create a New Model**
> "Create a new HoistModel for [feature] with a couple of observable properties and a computed
> value. Follow this project's conventions and Hoist patterns."

Claude will scaffold a model using `hoistCmp.factory()`, `@managed`, `makeObservable(this)`,
and other Hoist patterns documented in the project's CLAUDE.md.

**Advanced -- Investigate an Unfamiliar Component**
> "I need to use [GridModel / FormModel / StoreSelectionModel / etc.] but I haven't worked with
> it before. Show me how it works and create a basic example following this project's patterns."

Claude will use `hoist-search-docs` and `hoist-get-symbol` to pull up current documentation and
API details.

## Part 4: Feedback and Discussion (~10 min)

**Try the feedback skill.** If you ran into any issues or have observations about the AI
tooling, file them now:
```
/xh:feedback
```
This files a sanitized GitHub issue on `xh/hoist-ai` with your feedback categorized and
tracked.

**Join the #ai Slack channel.** This is our ongoing venue for AI-related questions, tips,
workflow discoveries, and discussion. Share what you tried in today's session and any
interesting results.

---

## Facilitator Notes

### Common Issues

- **MCP server not starting:** Ensure `@xh/hoist` is installed in the project's `node_modules`.
  Run your package manager's install command in `client-app/` if needed.
- **`gh` not authenticated:** Run `gh auth login` in a terminal before using the feedback skill.
- **CLAUDE.md merge conflicts:** If the project already has a CLAUDE.md, the onboarding skill
  will show a diff preview before merging. Review carefully and confirm.
- **Plugin not appearing:** Try restarting Claude Code. Check `/plugin list` for error status.

### What to Watch For

- Verify the MCP server starts correctly across different projects.
- If anyone gets a CLAUDE.md that looks wrong (missing sections, wrong project type), capture
  the details via `/xh:feedback` for investigation.
- Encourage developers to try different starter tasks so the group covers a range of use cases.

### After the Session

- Review any feedback issues filed on `xh/hoist-ai` during the session.
- Check the #ai Slack channel for follow-up questions or tips shared by attendees.
- Plan targeted follow-ups for any developers who had persistent setup issues.
