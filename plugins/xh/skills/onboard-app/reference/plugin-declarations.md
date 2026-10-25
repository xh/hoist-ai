# Phase 4.5: Declare the Plugin for the Team

The plugin runs onboarding, so it is installed for the current developer. Other developers on the
project get it from a declaration in each harness's project config. Write the declaration for
each confirmed harness.

Merge into an existing file. Keep every other key and entry. If the file already enables or
disables `xh@hoist-ai`, leave that value alone, because `false` is a developer's opt-out. If a
`hoist-ai` marketplace entry already exists with a different source, such as a branch or a local
folder, leave it and name it in the report.

**Claude Code**, `.claude/settings.json`. Claude Code asks the user to approve a write to this
file. If the write is refused, show the user the entry to add.

```json
{
  "extraKnownMarketplaces": {
    "hoist-ai": {
      "source": { "source": "github", "repo": "xh/hoist-ai" }
    }
  },
  "enabledPlugins": {
    "xh@hoist-ai": true
  }
}
```

**Cursor**, `.cursor/settings.json`. Cursor keeps marketplaces per account, so this entry only
turns the plugin on. Each developer adds the marketplace once, unless a team marketplace
provides it.

```json
{
  "plugins": {
    "xh@hoist-ai": { "enabled": true }
  }
}
```

**Codex**, `.codex/config.toml`. The entry names the marketplace and turns the plugin on. Codex
reads project config only in a trusted project.

```toml
[marketplaces.hoist-ai]
source_type = "git"
source = "https://github.com/xh/hoist-ai.git"

[plugins."xh@hoist-ai"]
enabled = true
```
