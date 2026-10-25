# Phase 4: Verify

After ALL hops are complete, run verification. The CLI surface is the always-on baseline (it
reads from `node_modules` and always reflects the upgraded version); MCP reconnect is
opportunistic and safe to skip in environments that block MCP.

## 1. Verify the upgraded developer-tools surfaces

**hoist-react CLI (universal, always run).** From `client-app/`, run:

```bash
npx hoist-docs index
```

This reads from `client-app/node_modules/@xh/hoist/...` and always reflects the just-installed
version. A clean docs index print confirms the upgraded surface is reachable. Surface any
errors before continuing.

**hoist-react MCP reconnect (only if MCP is part of your workflow).** The MCP server is still
serving the pre-upgrade version's types and docs. Prompt the developer:

> "If you use MCP in this environment, please reconnect the hoist-react server, then say
> 'continue'. If you don't use MCP (for example, in MCP-blocked enterprise environments), say
> 'skip' -- the CLI surface above is the working path and already reflects the upgrade."

Name the reconnect step for the current harness: `/mcp` in Claude Code, or turn the server off
and on in Cursor's MCP settings. If the harness has no reconnect command, the developer starts a
new session and runs this phase there.

After 'continue': call the hoist-react server's `hoist-ping` tool to confirm. After 'skip', or if the ping
fails or the tool isn't in your context, proceed without error -- the CLI verification above is
sufficient.

**hoist-core CLI (only if launchers were refreshed in Phase 3e).** If Phase 3e re-ran
`installHoistCoreTools`, run:

```bash
./bin/hoist-core-docs ping
```

Expect `hoist-core CLI is running.` This confirms the refresh produced working launchers
pointing at the new JAR. Surface any errors before continuing.

## 2. TypeScript compilation

Run from `client-app/`:
```bash
npx tsc --noEmit
```
Report pass/fail.

## 3. Lint

Run the project's lint command from `client-app/` using the detected package manager.
Report pass/fail.

## 4. Build, dev server, and tests

`tsc` and lint miss problems that only show up when the app builds, boots, or runs its tests.
Run these when any hop crossed a major version, or when `@xh/hoist-dev-utils` changed:

- **Production build.** Run the app's build script from `client-app/` (for example `pnpm build`).
  Report pass/fail.
- **Dev server.** Start the app's start script in the background. Wait until it reports a
  successful compile, or an error. Then stop it. Report pass/fail. If the developer can open
  the app, ask them to check the browser console for errors at startup.
- **Tests.** If the app has a unit or E2E test suite (for example a `test` or `test:e2e`
  script, or a Playwright config), run it. E2E tests may need the running app and server. Ask
  the developer before you start them. Report pass/fail per suite.

## 5. Guided verification

If the final version's upgrade guide includes a verification checklist, present it to the
developer and work through each item.

If verification fails, present the errors and work with the developer to resolve them before
proceeding to the report phase. If the dev server or a production build fails after the upgrade
(bundler or loader errors, dev-server startup failures), suspect a missed hoist-dev-utils
pairing first. dev-utils mismatches surface at build / dev-server time, not runtime. Re-check
the version-compatibility doc (Phase 2.3) and the app's build config before debugging app code.

## Verification cadence

For multi-hop upgrades where all hops are LOW or TRIVIAL difficulty, batch all verification at
the end. For hops rated MEDIUM or higher, consider running intermediate TypeScript compilation
checks after those hops to catch issues before they compound. Use your judgment based on the
difficulty ratings read from the upgrade guides.
