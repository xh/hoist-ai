# Hoist Upgrade Report: v{{FROM_VERSION}} -> v{{TO_VERSION}}

- **Date:** {{DATE}}
- **Project:** {{PROJECT_NAME}}
- **Hops:** {{HOP_COUNT}} version(s)
- **Branch:** {{BRANCH_NAME}}

## Upgrade Summary

| Version Hop | Difficulty | Changes Applied | Judgment Calls | Status |
|-------------|------------|-----------------|----------------|--------|
<!-- REPEAT: One row per version hop -->
| v{{HOP_FROM}} -> v{{HOP_TO}} | {{HOP_DIFFICULTY}} | {{HOP_CHANGES_COUNT}} | {{HOP_JUDGMENT_COUNT}} | {{HOP_STATUS}} |
<!-- END REPEAT -->

## Per-Version Details

<!-- REPEAT: One section per version hop -->

### v{{HOP_FROM}} -> v{{HOP_TO}}

**Difficulty:** {{HOP_DIFFICULTY}}
**Guide source:** {{HOP_GUIDE_SOURCE}}

#### Changes Applied

<!-- List each mechanical change applied during this hop -->
- {{CHANGE_DESCRIPTION}} (`{{CHANGE_FILE}}`)

#### Judgment Calls Requiring Review

<!-- List items that were flagged but NOT auto-applied -->
- **{{JUDGMENT_ITEM}}** -- {{JUDGMENT_DESCRIPTION}}
  - Affected files: {{JUDGMENT_FILES}}
  - Recommendation: {{JUDGMENT_RECOMMENDATION}}

#### hoist-core Version

{{HOP_CORE_NOTE}}

<!-- END REPEAT -->

## Judgment Calls Requiring Review

All items across all version hops that need developer attention, ordered by priority.

<!-- REPEAT: One entry per judgment call, consolidated from all hops -->

### {{JUDGMENT_PRIORITY}}. {{JUDGMENT_ITEM}} (v{{JUDGMENT_HOP_FROM}} -> v{{JUDGMENT_HOP_TO}})

{{JUDGMENT_DESCRIPTION}}

- **Affected files:** {{JUDGMENT_FILES}}
- **Recommendation:** {{JUDGMENT_RECOMMENDATION}}

<!-- END REPEAT -->

## Verification Results

- **TypeScript compilation:** {{TSC_STATUS}}
- **Lint:** {{LINT_STATUS}}
{{ADDITIONAL_VERIFICATION}}

## hoist-core Changes

<!-- Include this section only if hoist-core version was bumped during the upgrade -->

- **Previous version:** {{CORE_OLD_VERSION}}
- **New version:** {{CORE_NEW_VERSION}}
- **Required by:** {{CORE_REQUIRED_BY}}
- **MCP+CLI launchers:** {{CORE_LAUNCHER_STATUS}}
  <!-- One of: "Refreshed via installHoistCoreTools (CLI ping verified)" |
       "Not previously installed -- skipped" |
       "Not previously installed AND now eligible (>= v39.0) -- see Next Steps" -->

> **Note:** The hoist-core version was bumped as required by the upgrade guide(s) listed above.
> If this project has significant server-side code (custom controllers, services, or endpoints),
> review the hoist-core release notes independently for any server-side breaking changes.

## Client Plugin Notes

<!-- Include this section only if client plugin packages were detected -->

| Plugin Package | Previous Version | New Version | Notes |
|----------------|-----------------|-------------|-------|
| {{PLUGIN_NAME}} | {{PLUGIN_OLD_VERSION}} | {{PLUGIN_NEW_VERSION}} | {{PLUGIN_NOTES}} |

{{PLUGIN_ADDITIONAL_NOTES}}

## Next Steps

- [ ] Review all judgment calls listed above and apply changes as appropriate
- [ ] Test affected features, especially those noted in judgment calls
- [ ] Run the application and verify core functionality
<!-- Include if hoist-core was bumped -->
- [ ] Review hoist-core changes if the project has significant server-side code
<!-- Include if hoist-core was bumped to >= 39.0 AND bin/hoist-core-mcp does NOT exist -->
- [ ] Install the hoist-core MCP server + CLI tools now that hoistCoreVersion >= v39.0:
      run `/xh:onboard-app` (it will detect the new eligibility and offer to install) or just
      ask Claude to install/setup the hoist-core MCP+CLI tools in this app -- the
      `using-hoist-core-reference` skill will walk through the install procedure
<!-- Include if client plugins were detected -->
- [ ] Verify client plugin compatibility with the upgraded Hoist version
- [ ] Create or merge the pull request for this upgrade branch
