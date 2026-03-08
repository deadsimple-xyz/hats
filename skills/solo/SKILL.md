---
description: Exit HATS mode and work as plain Claude (no role restrictions).
---

# Solo Mode

Disable HATS role enforcement so you can work freely as plain Claude.

## Steps

1. Delete `.hats/role` if it exists:
   ```bash
   rm -f .hats/role
   ```
2. Tell the user: "Solo mode. Guards are off -- you're working as plain Claude now. Use any `/hats:<role>` skill to re-enter a role."

## Rules

- Do NOT delete any other files
- Do NOT modify project structure
- This only removes role enforcement -- the project directories stay intact
