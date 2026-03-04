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
{"ts":"2026-03-04T14:30:00Z","role":"manager","tool":"Write","file":".hats/manager/auth.feature"}
{"ts":"2026-03-04T14:30:05Z","role":"manager","tool":"Bash","command":"ls .hats/manager/"}
{"ts":"2026-03-04T14:30:10Z","event":"write_block","role":"designer","file":"src/app.ts","tool":"Write","reason":"designer can only write inside .hats/"}
```

Fields:
- `ts` — UTC timestamp
- `role` — active role at the time (`none` if no role set)
- `tool` — tool name (Bash, Write, Edit, Read, Glob, Grep, Agent, etc.)
- `event` — only present for guard blocks (`write_block` or `read_block`)
- `reason` — only present for guard blocks
- Tool-specific: `file`, `command`, `pattern`, `path`, `description`

## Tips for Contributors

- **Look for repeated blocks** — a role hitting the same guard 3+ times means the agent instruction isn't clear enough
- **Look for unnecessary reads** — if a role reads files it doesn't need, the agent prompt may be too broad
- **Look for missing communication** — if the Developer struggles without context that exists in `shared/`, the workflow instructions may need updating
- **Compare autopilot vs manual** — autopilot logs show the ideal pipeline flow; manual logs show real human usage patterns
