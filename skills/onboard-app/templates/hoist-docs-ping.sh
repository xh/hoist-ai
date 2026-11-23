#!/usr/bin/env bash
# hoist-ai-script: hoist-docs-ping/v1
# Ask the project's Hoist Docs server for hoist-ping over stdio, with no MCP client and no
# Claude Code restart. Run from the app project root. Prints the ping text: the Hoist versions
# served, and any library not loaded with the reason. Exits non-zero if the server fails.
set -u

server="client-app/node_modules/@xh/hoist-docs/bin/hoist-docs.mjs"
if [ ! -f "$server" ]; then
    echo "Hoist Docs is not installed: $server not found." >&2
    echo "Add @xh/hoist-docs as a client-app dev dependency, then run the install." >&2
    exit 1
fi

init='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"hoist-ai","version":"1"}}}'
ping='{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"hoist-ping","arguments":{}}}'
log="$(mktemp)"
trap 'rm -f "$log"' EXIT

out="$(printf '%s\n%s\n' "$init" "$ping" | INDEX_DIR= node "$server" 2>"$log")"
text="$(printf '%s' "$out" | node -e '
let s = "";
process.stdin.on("data", d => (s += d)).on("end", () => {
    const msg = s.split("\n").filter(Boolean).map(l => JSON.parse(l)).find(m => m.id === 2);
    if (!msg?.result) process.exit(1);
    console.log(msg.result.content[0].text);
});
')"
if [ -z "$text" ]; then
    echo "Hoist Docs did not start:" >&2
    grep -v '"level":"info"' "$log" >&2
    exit 1
fi
printf '%s\n' "$text"
