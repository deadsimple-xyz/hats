# Self-Learning

Hats can improve itself. Debug logging captures every tool use, command, guard block, and role switch during real project work. Contributors can analyze these logs to find friction, fix bugs, and improve agent behavior.

## How It Works

1. **Enable logging** in any Hats project:
   ```bash
   touch .hats/debug
   ```

2. **Use Hats normally** — run `/hats:manager`, `/hats:autopilot`, etc. Every tool call is logged to `.hats/logs/YYYY-MM-DD.jsonl`.

3. **Analyze the logs** — open the Hats repo and ask Claude to read the log files:
   ```
   claude --plugin-dir ../hats
   > Read the logs in /path/to/my-app/.hats/logs/ and suggest improvements to Hats agents and guards.
   ```

4. **Make fixes** — Claude (working inside the Hats repo) can read the logs, identify issues, and edit agent files, guard scripts, or skill instructions.

5. **Submit a PR** with the improvements.

## What the Logs Capture

| Log field | What it tells you |
|-----------|------------------|
| `tool` + `file` | Which files each role reads/writes — are guards too strict or too loose? |
| `tool: "Bash"` + `command` | What shell commands roles run — any unsafe or redundant patterns? |
| `tool: "Agent"` + `description` | Sub-agent spawns — are prompts effective? |
| `event: "write_block"` / `event: "read_block"` | Guard blocks with reasons — false positives? Missing rules? |
| `role` field changes over time | Role switch patterns — is the workflow smooth? |

## Example Analysis

Given a log like:
```jsonl
{"ts":"...","role":"developer","tool":"Read","file":".hats/qa/test.spec.ts"}
{"ts":"...","event":"read_block","role":"developer","file":".hats/qa/test.spec.ts","tool":"Read","reason":"developer cannot read .hats/qa/"}
{"ts":"...","role":"developer","tool":"Read","file":".hats/qa/test.spec.ts"}
{"ts":"...","event":"read_block","role":"developer","file":".hats/qa/test.spec.ts","tool":"Read","reason":"developer cannot read .hats/qa/"}
```

This shows the Developer agent repeatedly trying to read test files despite being blocked. The fix: strengthen the instruction in `agents/developer.md` that says tests are off-limits, or add a more helpful block message pointing to `qa-report.md`.

## Log Format

Each line is a JSON object:

```jsonl
{"ts":"2026-04-25T14:30:00Z","hv":"4.2.0","model":"claude-opus-4-7-20251024","role":"manager","tool":"Write","file":".hats/shared/specs/auth.feature"}
{"ts":"2026-04-25T14:30:05Z","hv":"4.2.0","model":"claude-opus-4-7-20251024","role":"manager","tool":"Bash","command":"ls .hats/shared/specs/"}
{"ts":"2026-04-25T14:30:10Z","hv":"4.2.0","model":"claude-opus-4-7-20251024","event":"write_block","role":"designer","file":"src/app.ts","tool":"Write","reason":"designer can only write inside .hats/"}
```

Fields:
- `ts` — UTC timestamp
- `hv` — Hats plugin version active at the time
- `model` — Claude model active at the time (auto-detected from session transcript; override via `.hats/model`)
- `role` — active role at the time (`none` if no role set)
- `tool` — tool name (Bash, Write, Edit, Read, Glob, Grep, Agent, etc.)
- `event` — only present for guard blocks (`write_block` or `read_block`)
- `reason` — only present for guard blocks
- Tool-specific: `file`, `command`, `pattern`, `path`, `description`

## Filtering by model + version

`hv` and `model` let you compare friction across releases and Claude versions. Useful queries:

```bash
# Only logs from a specific model (e.g. Opus 4.7)
jq -c 'select(.model | startswith("claude-opus-4-7"))' .hats/logs/*.jsonl

# Only logs from a specific Hats version
jq -c 'select(.hv == "4.2.0")' .hats/logs/*.jsonl

# Count guard blocks per model — see if upgrading the model reduced friction
jq -c 'select(.event)' .hats/logs/*.jsonl | jq -r '.model' | sort | uniq -c

# Compare same role's behaviour across versions
jq -c 'select(.role=="developer" and .tool=="Read") | "\(.hv)\t\(.file)"' .hats/logs/*.jsonl | sort | uniq -c
```

This makes it possible to ask "did 4.1.0's notes.md actually cut redundant reads?" or "is the Opus 4.6 → 4.7 upgrade fixing friction we worked around in 3.x?"

## Tips for Contributors

- **Look for repeated blocks** — a role hitting the same guard 3+ times means the agent instruction isn't clear enough
- **Look for unnecessary reads** — if a role reads files it doesn't need, the agent prompt may be too broad
- **Look for missing communication** — if the Developer struggles without context that exists in `shared/`, the workflow instructions may need updating
- **Compare autopilot vs manual** — autopilot logs show the ideal pipeline flow; manual logs show real human usage patterns
- **Compare across model + version** — before proposing a fix, check if the friction still appears with the latest `hv` and `model`. Some old issues may already be solved by Claude getting smarter, not by Hats changes.
