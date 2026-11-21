# hoist-react CLI launchers

These launchers are for `@xh/hoist` before v91 only. From v91, `@xh/hoist` ships no CLI, and the app reads its docs through the Hoist Docs MCP server (`@xh/hoist-docs`). There, `client-app/node_modules/.bin/hoist-docs` is the Hoist Docs server, so a `bin/hoist-docs` launcher starts the server instead of answering a query.

To tell which applies, check `client-app/node_modules/@xh/hoist/package.json`. A `hoistDocs` key means v91 or later. Then do not install the launchers. If `bin/hoist-docs` or `bin/hoist-ts` exist, offer to delete them, and use the `mcp__hoist-docs__*` tools.

The CLI surface runs through two project-local launchers, `bin/hoist-docs` and `bin/hoist-ts`. Each one is a short shell script that execs the `@xh/hoist` binary of the same name through `client-app/node_modules/.bin/`. Because they live at the project root, the agent can run them from its default working directory without a `cd`. Always run them as `./bin/hoist-...` from the app project root.

## Preflight

Run this once per session, before the first `./bin/hoist-docs` or `./bin/hoist-ts` call. Skip it if you work through MCP only.

1. Check that `client-app/node_modules/@xh/hoist/package.json` has no `hoistDocs` key. If it has one, stop: the app is on v91 or later, as described above.
2. Check that `./bin/hoist-docs` and `./bin/hoist-ts` exist at the project root.
3. Read the first 3 lines of each. The second line should be exactly:

       # hoist-ai-launcher: hoist-react/v2

4. Run a smoke check to confirm that the launcher resolves its target:

       ./bin/hoist-docs --help

   Exit 0 with usage output is a pass. A non-zero exit with `No such file or directory` in stderr means that the path resolution in the launcher is broken. The usual cause is a lost `$0` literal: `dirname ""` resolves to `.`, and the exec target lands one level above the project root. Treat this the same as a missing launcher or a stale stamp.

If a check fails, run [Install](#install) from start to end, then continue with your task. The procedure is idempotent, so it is safe to run again. Tell the user about the refresh in your next message, for example "refreshed hoist-react launchers to v2".

After the preflight passes, do not check again on each CLI call.

## Install

Run this procedure when:

- the preflight found the launchers missing, stale, or broken.
- the user asks to install, set up, or refresh the hoist-react CLI launchers.
- a CLI call failed with `No such file or directory`.
- neither the MCP tools nor the launchers are available in a Hoist app.

### Prerequisites

- The app is a Hoist project: `client-app/package.json` lists `@xh/hoist`, directly or through a client plugin.
- The installed `@xh/hoist` is earlier than v91: its `package.json` has no `hoistDocs` key. If `node_modules` is not installed, check the version in the lockfile.
- `client-app/node_modules` is populated, that is, the app's package manager install has run from `client-app/`. The launchers install without it, but they fail at runtime until the packages are present.

If `node_modules` is missing, tell the user it is a separate step. Still install the launchers. The two steps are independent.

### Procedure

The canonical launchers are the template files `templates/hoist-docs` and `templates/hoist-ts` in this skill. Copy them byte for byte. Do not transcribe them. Shell expansions with nested double quotes, such as `"$(dirname "$0")"`, can break when content goes through serialization layers. The `$0` literal has been observed to disappear in some skill-loading paths. A byte copy avoids that risk.

1. Use `Glob` with the pattern `**/using-hoist-react-reference/templates/hoist-docs` to find the template folder on disk. Both launchers are in the parent folder of the match.

2. Use `Bash` to copy the templates into the project's `bin/` and make them executable:

       mkdir -p bin
       cp "<templates-dir>/hoist-docs" bin/hoist-docs
       cp "<templates-dir>/hoist-ts" bin/hoist-ts
       chmod +x bin/hoist-docs bin/hoist-ts

   Replace `<templates-dir>` with the folder from the Glob result. Do **not** use `Read` and `Write` to copy the content. That path serializes the file body through tools that can break shell content with nested quotes. `cp` is byte-exact.

3. Check what landed:

       grep -F '$0' bin/hoist-docs && grep -F '$0' bin/hoist-ts

   Both commands should match. If one does not, the copy lost the literal `$0` and the launcher is broken. Do not continue.

The templates are canonical for `hoist-react/v2`. If launchers on disk differ from the templates in any way, overwrite them. This includes a different stamp version or a missing `$0`. The launchers are generated from the templates, so there are no manual edits to keep.

### Verification

```bash
./bin/hoist-docs --help
./bin/hoist-docs index
./bin/hoist-ts members GridConfig
```

`--help` checks that the launcher resolves its path. Exit 0 with usage output is a pass. `No such file or directory` from `--help` means the launcher itself is broken. The usual cause is a `$0` literal lost during the copy, so run the procedure again with `Bash cp`. If `--help` works but `index` or `members` fails with "command not found" from the `node_modules/.bin/` target, the `client-app` package install has not run.

## Git tracking

The launchers are deterministic copies of the templates. Both stances work:

- **Track them in git.** This is the recommended stance for teams that want fresh clones to work at once. The preflight does nothing until the stamp version changes.
- **Ignore them.** Add `bin/hoist-docs` and `bin/hoist-ts` to `.gitignore`. The first agent session in each fresh checkout runs the preflight, which installs them.

The preflight handles both states the same way.
