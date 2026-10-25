# Phase 2: Plan

Present the upgrade plan for developer confirmation. Do NOT make any changes until the developer
confirms.

## 1. Determine target version

If a target version was provided via arguments in Phase 1, use it.

**Canary mode.** A dist-tag spec is a deliberate choice to track SNAPSHOTs. Do not treat it as
a version string to bump. Run `npm view @xh/hoist dist-tags` to see where `next` and `latest`
point, then ask the developer which path they want:
- **Stay on canary:** re-resolve `next` to its current SNAPSHOT and apply the migrations for
  every major it crosses. The spec stays `next`.
- **Move to a stable release:** pick a target from the list below. The spec becomes a caret
  range. If the target is older than the installed SNAPSHOT, warn that this is a downgrade.

Wait for the developer to choose before continuing.

If no target version was specified, query npm for available versions:
```bash
npm view @xh/hoist versions --json
```

`npm view` is a registry-query command -- it works in any Node.js environment regardless of
which package manager the project uses, since `npm` ships with Node itself. No need to route
through the project's detected manager here.

Filter the results to **stable releases only** -- versions matching `x.y.z` with no prerelease
suffix. Exclude versions with `-SNAPSHOT`, `-alpha`, `-beta`, `-rc`, or any other prerelease tag.
XH publishes many SNAPSHOT versions to npm during development -- these should never be suggested
as upgrade targets.

Filter to versions newer than the currently installed version and present a structured list:
```
Available @xh/hoist versions (you have v{current}):

  v79.0.0
  v80.0.0
  v80.1.0
  v81.0.0  <- latest

What version would you like to upgrade to?
```

Wait for the developer to choose before continuing.

## 2. Determine version hop sequence

Each major version between current and target is a separate hop. Example: v77 -> v81 produces
the sequence [v77->v78, v78->v79, v79->v80, v80->v81].

For minor version jumps within the same major version (e.g. v80.0.0 -> v80.1.0), treat that as
a single hop.

On the canary path, the target is the version `next` resolves to. The tag cannot install
intermediate majors, so Phase 3 installs once and applies each hop's guide in order. The
installed package carries the upgrade notes for every earlier major. A SNAPSHOT may ship a
partial guide for its own major, or none yet. If `next` resolves within the installed major,
there is one hop. Read the breaking changes for that major at the top of the installed
`CHANGELOG.md`.

## 3. Check version compatibility (hoist-core AND hoist-dev-utils)

hoist-react ships a compatibility reference, `docs/version-compatibility.md`, with matrices
pairing each hoist-react release with its required/recommended **hoist-core** and
**hoist-dev-utils** versions. Retrieve it via either path:

- MCP: `hoist-read-doc` with id `docs/version-compatibility.md` (`@xh/hoist` v86+)
- Filesystem: Read `client-app/node_modules/@xh/hoist/docs/version-compatibility.md`

At plan time both paths serve the *currently installed* hoist-react's copy, which may not yet
include rows for the target version -- re-check from `node_modules` after each hop's install
(Phase 3f), when the target's copy is on disk. Apps on older hoist-react may not have the doc
at all (it first shipped in the v82 era), or may have a copy that predates its dev-utils
tables. If the doc or its dev-utils section is missing at plan time, note that in the plan
and rely on the per-hop post-install check in Phase 3f.

For the target version (and each intermediate hop), note:
- **hoist-core:** Min Core Required / Recommended Core vs the current `hoistCoreVersion`.
- **hoist-dev-utils:** Min Dev-Utils Required / Recommended Dev-Utils vs the app's current
  `@xh/hoist-dev-utils` (Phase 1). Also check the doc's reverse-lookup table -- each dev-utils
  major sets its own minimum hoist-react and may raise the minimum Node version.

Record any required or recommended bumps for the plan display below.

## 4. Check guide availability

For each hop in the sequence, check if a dedicated upgrade guide exists. List the guides with a
shell command, because some harnesses' search tools skip the gitignored `node_modules`:
```bash
ls client-app/node_modules/@xh/hoist/docs/upgrade-notes/
```

Match each hop's target version against the available files. If a guide does NOT exist for a
particular hop's target version (versions before v73 will not have one), note that hop as
"CHANGELOG-only" and alert the developer:
> "Note: No dedicated upgrade guide exists for v{target}. This hop will use CHANGELOG entries
> only, and guidance may be less thorough."

## 5. Client plugin confirmation

If client plugins were detected in Phase 1, present the detection:
```
### Client Plugins Detected

| Plugin | Current Version | Hoist Version Mapping |
|--------|----------------|----------------------|
| {plugin name} | {version} | {mapping from the agent docs, or "No mapping found"} |

How should I handle the plugin version during this upgrade?
- Bump to a specific version?
- Leave unchanged?
- Other guidance?
```

Do not proceed until the developer confirms the plugin approach.

## 6. Display the upgrade plan

```
## Upgrade Plan: @xh/hoist v{current} -> v{target}

| Hop | Guide Available | Difficulty |
|-----|-----------------|------------|
| v77 -> v78 | Yes (upgrade notes) | TBD (read during execution) |
| v78 -> v79 | Yes (upgrade notes) | TBD |
| ...

- **Branch:** upgrade/hoist-v{current}-to-v{target} (or existing branch if found)
- **Commits:** One per version hop
- **hoist-core:** {current version from gradle.properties}
- **hoist-dev-utils:** {current} -> {planned bump per compatibility matrix, or "no change required"}
- **Server complexity:** {Minimal (stock) | Significant (custom controllers/services)}
- **Client plugins:** {Detected plugins, or "None detected"}
- **Package manager:** {detected package manager}
```

## 7. Confirm with developer

Ask: **"Proceed with this upgrade plan? (yes/no)"**

Wait for confirmation before making any changes.
