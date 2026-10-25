# Phase 4: Generate AGENTS.md

`AGENTS.md` holds the project guidance, because every harness reads it. If the team uses Claude
Code, `CLAUDE.md` holds the line `@AGENTS.md`, which makes Claude Code load the same file. Skip
every `CLAUDE.md` step below when Claude Code is not a confirmed harness.

1. Build the Hoist sections with the bundled script, from the project root. Pass the package
   manager and the decorator style from Phase 1:

   ```bash
   node "<skill-dir>/scripts/build-agents-md.mjs" --pkg <yarn|npm|pnpm> --decorators <tc39|legacy>
   ```

   `<skill-dir>` is the onboard-app skill folder, the parent of this file's folder. If you cannot
   find it, search for `**/onboard-app/scripts/build-agents-md.mjs`. The script fills the
   templates in the `templates/` folder beside it.

   For each client plugin from Phase 1, add
   `--plugin "<name>|<npm or Grails>|<version>|<what it provides>"`. Add a `--plugin-note` for
   each npm plugin that provides `@xh/hoist` transitively, and for each Grails plugin that
   provides `hoist-core` transitively. Add one more note that tells agents to check the plugin's
   source and docs when a change touches APIs the plugin provides.
2. Put the script's output in place with the shell, for example `> AGENTS.md` for a new file.
   Never retype it or copy it through a file editor, which can drop or change template lines.
   To merge into an existing file, write the output to a scratch file, then copy in the sections
   that step 4 selects.
3. Pick the target file from what Phase 1 found. An `AGENTS.md` that only points readers to
   `CLAUDE.md` counts as absent: replace it when you move the content.
   - **Neither file exists.** Write the generated content to `./AGENTS.md`. For Claude Code,
     write `./CLAUDE.md` with the single line `@AGENTS.md`.
   - **`AGENTS.md` exists.** Merge into it with the rules in step 4. For Claude Code, make sure
     `CLAUDE.md` imports it: create `CLAUDE.md` with the line `@AGENTS.md`, or add that line at
     the top of an existing `CLAUDE.md` that lacks it. If `CLAUDE.md` also holds Hoist sections
     from an older onboarding, move them into `AGENTS.md` and remove them from `CLAUDE.md`.
   - **Only `CLAUDE.md` exists.** Older onboarding runs wrote the Hoist guidance there. Propose
     to move its content to a new `AGENTS.md`, so Cursor and Codex read it too. `CLAUDE.md` then
     keeps the line `@AGENTS.md` and any line that only Claude Code understands, such as an
     `@path` import of another file. Then merge into `AGENTS.md` with the rules in step 4. If
     the user declines the move, merge into `CLAUDE.md` with the same rules and write no
     `AGENTS.md`.
4. Merge rules for an existing file:
   - Read the existing file.
   - Check which Hoist sections are already present (look for headings like
     "Architecture Primer", "Models and Decorators", "Hoist Reference Skills", "MCP Tools",
     "hoist-core", "Writing Style", "Commands", "Client Plugins").
   - Append the sections that are missing.
   - Replace each Hoist section that an older onboarding run wrote with the generated version.
     Older runs wrote Claude Code-only text, such as "The `xh` Claude Code plugin", `mcp__`
     tool names, and "restart Claude Code", which other harnesses cannot use. Keep any line the
     user added inside the section, which is a line the generated version lacks.
   <!-- legacy-api:start -->
   - **A stale model primer.** Hoist primer text that teaches the other decorator
     style is wrong for this app. Older onboarding runs put the HoistModel example inside
     "Architecture Primer", not in a "Models and Decorators" section. Judge it by the
     primer's HoistModel code example, not by prose that only names an API. The primer is
     stale if the app uses TC39 decorators and the example declares `@observable` or
     `@bindable` fields without `accessor`, or calls `makeObservable(this)`. It is also stale
     if the app uses legacy decorators and the example uses `accessor` fields.
     Offer to replace the "Architecture Primer" and "Models and Decorators" sections with the
     generated ones. Keep any project-specific text the user added inside them.
   <!-- legacy-api:end -->
   - Show the user what will be added, moved, or replaced before writing.
   - Preserve all existing project-specific content.
