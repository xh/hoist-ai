---
name: feedback
description: Report feedback about Hoist AI tooling. Files a sanitized GitHub issue with category labels for documentation gaps, convention issues, MCP problems, or general observations.
disable-model-invocation: true
allowed-tools: Bash
---

# Hoist AI Feedback

You are helping a developer file structured feedback about the Hoist AI tooling as a GitHub
issue. Follow these phases in order.

## Phase 1: Gather Feedback

**1. Parse arguments.** Check `$ARGUMENTS` for:
- A `--repo owner/repo` flag -- if present, use that repo instead of the default `xh/hoist-ai`.
  Example: `/xh:feedback --repo client-org/client-repo MCP search not returning results`
- Any remaining text after flags -- use it as the initial feedback description.

**2. Ask the user to select a category:**

| Category     | Use for                                       |
|--------------|-----------------------------------------------|
| `doc-gap`    | Documentation gap or missing information      |
| `convention` | Convention violation or unclear convention     |
| `mcp-issue`  | MCP server problem or tool issue               |
| `skill-bug`  | Skill not working as expected                  |
| `general`    | General feedback or observation                |

**3. Collect description.** If no description was provided via `$ARGUMENTS`, ask the user to
describe the issue in a few sentences.

**4. Offer session context.** Ask the user:
> "Would you like to include session context (a summary of recent tool interactions that may be
> relevant)? I will sanitize any sensitive content before posting. (yes/no)"

If yes, summarize the last few relevant tool interactions -- tool names and outcomes only, not
full inputs/outputs.

## Phase 2: Sanitize Content

Before showing the preview, apply these sanitization rules to ALL content (description, context):

1. **Strip absolute file paths.** Replace any path matching `/Users/*/...` or `/home/*/...` or
   `C:\Users\*\...` with `[project]/...`. Remove directory segments that could identify client
   projects.

2. **Redact potential secrets.** Replace strings matching these patterns with `[REDACTED]`:
   - Strings longer than 20 characters with mixed uppercase, lowercase, and digits
   - Strings starting with `sk-`, `ghp_`, `gho_`, `xoxb-`, `xoxp-`, `AKIA`, `sk_live_`,
     `pk_live_`, `Bearer `, or `token=`
   - Anything that looks like a connection string or DSN with credentials

3. **Strip client-identifying content.** Remove or genericize:
   - Client company names in paths or descriptions (replace with `[client]`)
   - Project-specific business logic or domain terms
   - Internal URLs or hostnames

4. **Keep safe content.** These are always safe to include:
   - Hoist component/model/service names (e.g., `GridModel`, `HoistModel`, `XH`)
   - MCP tool names (e.g., `hoist-search-docs`, `hoist-ping`)
   - Error messages from Hoist or Claude Code tooling
   - Hoist version numbers
   - Skill names and plugin references

**Principle:** Err on the side of less context. The user can always add detail to the issue
after it is created.

## Phase 3: Preview and Confirm

Show the user the exact issue that will be posted:

```
--- ISSUE PREVIEW ---

Repository: {target-repo}
Title: [{Category}] {Brief description}
Labels: feedback, {category}

Body:
## Category
{Category full name}

## Description
{Sanitized description}

## Session Context
{Sanitized context, or "None provided"}

## Environment
- Plugin: xh (from hoist-ai marketplace)
- Filed via: /xh:feedback

--- END PREVIEW ---
```

Ask the user: **"Post this issue to {target-repo}? (yes/no)"**

If the user says no, ask what they would like to change. Repeat from the relevant phase.

## Phase 4: File Issue

Use the `gh` CLI to create the issue:

```bash
gh issue create \
  -R "{target-repo}" \
  -t "[{Category}] {Brief title}" \
  -b "{formatted body}" \
  -l "feedback,{category}"
```

**Default target repo:** `xh/hoist-ai`

**Error handling:** If the `gh` command fails with an authentication error, inform the user:
> "The `gh` CLI is not authenticated. Please run `gh auth login` in your terminal to
> authenticate with GitHub, then try this skill again."

If the command fails for another reason (e.g., repo not found, permission denied), show the
error and suggest the user verify the target repository and their access.

## Phase 5: Report

Display the created issue URL back to the user. Example:

> "Issue filed successfully: https://github.com/xh/hoist-ai/issues/42
>
> You can add additional detail or screenshots directly on the issue page."
