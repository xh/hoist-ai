# Renaming the `xh` plugin

This guide covers a rename of the `xh` plugin to `hoist`. We tested the rename in October 2026
on Claude Code 2.1.304, then deferred it. The guide records why, what Claude Code does during a
rename, and the change list if we go ahead.

## Decision

We keep the name `xh`. A rename forces every developer on every client project to act once, or
their skills disappear. The benefit is cosmetic: `/hoist:upgrade` reads a little better than
`/xh:hoist-upgrade`. Hoist developers already read `xh` as Hoist, from the `XH` global, the
`@xh/hoist` package, and the `io.xh` group.

Reverse the decision if one of these becomes true:

- Claude Code installs the target of a `renames` entry by itself.
- A release already forces every developer to run a command, so the rename adds no new step.
- The `xh` name causes real confusion, for example with another XH product.

### Pros

- The install id `hoist@hoist-ai` and the commands `/hoist:<skill>` match the product name.
- The name pairs with the planned second plugin, `hoist-framework`.

### Cons

- Each developer must run `claude plugin install hoist@hoist-ai` once per scope. Until they do,
  the skills do not load.
- A developer who installed at user scope loses the skills silently after a marketplace refresh.
- The install step must run in a shell. No `/plugin` path we tried could do it. See
  [What Claude Code does](#what-claude-code-does).
- The `renames` entry stays in the catalog forever.
- `onboard-app` needs a migration step, and the README needs a migration section.
- Project docs and muscle memory still use `/xh:`.

A rename does not change these:

- The `/hoist` mod command. Mod commands are not namespaced, so plugin `xh` can register it.
- The `plugins/` layout, and a second plugin beside `xh`.
- The `autoUpdate` setting. It is worth shipping without a rename.

## What Claude Code does

### The `renames` field

`marketplace.json` takes a top-level `renames` map from an old plugin name to its new name, or
to `null` for a removed plugin:

```json
"renames": { "xh": "hoist" }
```

- The map is append-only. A removed key strands every project that still enables the old id.
- `claude plugin validate` checks that each chain ends at a name in `plugins[]` or at `null`.
- Do not rename the marketplace. Claude Code ignores a changed `name` for an existing
  registration, so `hoist@<new-name>` fails for current users.

### When the rename applies

- The session plugin loader applies `renames`. It does so when an enabled id is missing from the
  catalog. `claude plugin marketplace update` does not apply it.
- The loader rewrites the enabled id in the settings file, for example `xh@hoist-ai` to
  `hoist@hoist-ai` in the project's `.claude/settings.json`. It also removes the old install
  record.
- The loader skips an id set to `false`, so a disabled `xh@hoist-ai` stays as it is.
- The old version folder stays in the plugin cache.

### What the developer sees

1. Without `autoUpdate`, nothing changes until the developer refreshes the marketplace. The cached
   `xh` plugin keeps working.
2. After `/plugin marketplace update hoist-ai` in a session, Claude Code reports "1 plugin failed
   to update" and reloads. The `/hoist:*` skills work, but only in that session.
3. At the next launch the skills are gone. `/plugin` > Errors shows "Plugin "hoist" not cached".
   The resolve action offers only disable or uninstall.
4. In a session, `/plugin install hoist@hoist-ai --scope project` opens the plugin page, because
   the project already enables the plugin. "Update now" fails with "not installed".
5. In a shell, `claude plugin install hoist@hoist-ai --scope project` installs the plugin. This
   is the only command that works.

Without a `renames` entry, `xh@hoist-ai` stays enabled but leaves the catalog, and its skills
disappear.

### Auto-update

- Auto-update is off by default for a marketplace that is not Anthropic's.
- `"autoUpdate": true` on the `extraKnownMarketplaces` entry turns it on. A value in the
  project's `.claude/settings.json` takes effect. We confirmed this in an interactive session.
- A refresh runs within about 10 minutes of a session's first message. The running session keeps
  its versions until `/reload-plugins` or the next launch.

## Change list

1. Move `plugins/xh/` to `plugins/hoist/`. Set `"name": "hoist"` in its `plugin.json`, and bump
   the major version.
2. In `marketplace.json`, rename the entry, point `source` at `./plugins/hoist`, and add
   `"renames": {"xh": "hoist"}`.
3. Rewrite each `/xh:` command and each `xh@hoist-ai` id in skills, templates, and the README.
   Search the whole repo for `/xh:`, `xh@hoist-ai`, `` `xh` plugin `` and `plugins/xh`. Known
   places:
   - `setup-worktree`: the `--enable-plugin` flag in `SKILL.md`, and the example in the header of
     `provision-worktree.sh`.
   - `onboard-app`: the upgrade prompts, and the plugin name in the Phase 6 report.
   - `onboard-app/templates/claude-md-base.md`: the plugin name in two sections.
4. Leave old CHANGELOG entries as they are.
5. Add a migration step to `onboard-app`. It runs after the user confirms setup. See
   [The onboard-app step](#the-onboard-app-step).
6. Add a migration section to the README. See [The README section](#the-readme-section).
7. Add a CHANGELOG entry that says each developer must install the new plugin once.
8. Add a rule to the repo CLAUDE.md: `renames` in `marketplace.json` is append-only.
9. Rebase every open branch that adds files under `plugins/xh/`.

### The onboard-app step

The step must change nothing that is already correct, so a second run writes nothing.

- **Detect first.** Read `.claude/settings.json` and `.claude/settings.local.json` in Phase 1.
  The planned actions must name each change before the user confirms.
- **Project settings.** Change them only if the project already enables `xh@hoist-ai` or
  `hoist@hoist-ai`. Otherwise the step leaves a marketplace entry without an enabled plugin.
  Replace the key `xh@hoist-ai` with `hoist@hoist-ai` and keep its value. Make sure the
  `hoist-ai` entry in `extraKnownMarketplaces` has `"autoUpdate": true`.
- **Show the full entry.** Give the agent the complete JSON, because an agent can flatten the
  `source` object into an invalid entry:

  ```json
  "hoist-ai": {
    "source": { "source": "github", "repo": "xh/hoist-ai" },
    "autoUpdate": true
  }
  ```

- **Local settings.** Apply the same `enabledPlugins` change to `.claude/settings.local.json`.
- **Agent docs.** Rewrite `/xh:` commands in `CLAUDE.md`, `CLAUDE.local.md`, `AGENTS.md`, and
  `.claude/rules/`, outside `node_modules/`. Rewrite each renamed skill first, for example
  `/xh:hoist-upgrade` to `/hoist:upgrade`.
- **Permissions.** In print mode, Claude Code refuses to write `.claude/settings*.json`, even
  with `acceptEdits`. The step needs an interactive session, where the user approves the write.

The `autoUpdate` check stays useful after the migration. Remove the rename parts in a later
major release.

### The README section

Cover both install scopes. The developer who migrates a project runs these commands in a shell:

```
claude plugin marketplace update hoist-ai
claude plugin install hoist@hoist-ai --scope project
```

Then they start a new session, run `/hoist:onboard-app`, and commit the result. Every other
developer runs the install command once. A developer who installed at user scope runs
`claude plugin install hoist@hoist-ai`. State that `/plugin install` in a session does not
install a plugin that the project already enables.

## Test the update path

Test in an isolated config so your own install stays untouched. Point `CLAUDE_CONFIG_DIR` at an
empty folder, install `xh@hoist-ai` from a copy of `main`, then publish the branch to the
marketplace.

- Use a git source, not a folder source. Claude Code reads a folder marketplace in place, so a
  folder test skips the refresh.
- `claude plugin marketplace add` accepts only `owner/repo`, an `https` URL, or a path. Claude
  Code refuses the `git` and `file` transports, and dumb HTTP fails because the clone is shallow.
- Serve the repository over smart HTTP on localhost with a small wrapper around
  `git http-backend`. Then map a fake `https` URL to it in the environment:

  ```
  GIT_CONFIG_COUNT=1
  GIT_CONFIG_KEY_0=url.http://127.0.0.1:8765/.insteadOf
  GIT_CONFIG_VALUE_0=https://hoist-ai.test/
  ```

- `claude -p` runs the plugin loader before it checks the login, so it can trigger the rename
  without credentials.
- The interactive steps need a login in the isolated config. A copied `.credentials.json` works,
  but a token refresh in the copy can sign out your real sessions. Delete the copy after the
  test.
- The auto mode classifier blocks an agent that drives an interactive session through tmux. Run
  the interactive steps yourself.
