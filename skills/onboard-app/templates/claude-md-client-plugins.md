
## Client Plugins

This application uses client-specific plugins that wrap core Hoist dependencies, adding an
intermediate layer between the app and the Hoist framework.

| Plugin | Type | Version | Provides |
|--------|------|---------|----------|
{{PLUGIN_TABLE}}

{{PLUGIN_NOTES}}

When working on code that touches APIs provided by a client plugin, check the plugin's source
and documentation -- it may extend, override, or restrict Hoist defaults. Use the package
manager to verify actual installed versions of `@xh/hoist` and `hoist-core`, as they may be
provided transitively through these plugins rather than declared as direct dependencies.
