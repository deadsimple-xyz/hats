---
name: solo
description: Exit HATS mode and work as the plain host agent (no role restrictions).
---

# Solo Mode

Disable HATS role enforcement so you can work freely as the plain host agent.

## Steps

1. Delete `.hats/role` if it exists:
   ```bash
   rm -f .hats/role
   ```
2. Tell the user: "Solo mode. Guards are off -- you're working as the plain host agent now. Use any Hats role skill to re-enter a role."

## Rules

- Do NOT delete any other files
- Do NOT modify project structure
- This only removes role enforcement -- the project directories stay intact
