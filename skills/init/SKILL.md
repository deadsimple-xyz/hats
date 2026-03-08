---
description: Initialize Hats in a new or existing project.
---

# Initialize Hats

## Step 1: Check for existing code

Look at the current directory. If there are source code files (anything besides `.git/`, `.gitignore`, `README*`, `LICENSE*`):
- Tell the user what you found
- Say: "Found existing code — it stays at the project root. Hats adds a `.hats/` folder for specs, designs, and tests."

If the directory is empty or only has `.git/`, skip to Step 2.

## Step 2: Create Hats structure

Create the missing directories and files (do NOT overwrite existing files):
- `.hats/manager/` (private workspace)
- `.hats/designer/` (private workspace)
- `.hats/cto/` (private workspace)
- `.hats/shared/`
- `.hats/shared/specs/` (Manager writes .feature files here)
- `.hats/shared/designs/` (Designer writes design files here)
- `.hats/qa/`
- `.hats/shared/manager2team.md` (empty)
- `.hats/shared/cto2team.md` (empty)
- `.hats/shared/qa2dev.md` (empty)
- `.hats/shared/dev2qa.md` (empty)
- `.hats/shared/dev2designer.md` (empty)
- `.hats/shared/qa2designer.md` (empty)
- `.hats/shared/designer2team.md` (empty)
- `.hats/status.json` (with default messaging structure — see MIGRATIONS.md for the full `messages` schema)
- `.gitignore` (append if exists, create if not):
  ```
  node_modules/
  __pycache__/
  venv/
  .env
  .hats/role
  .hats/logs/
  *.log
  ```

No symlinks are created. All shared data lives in `.hats/shared/` — specs in `shared/specs/`, designs in `shared/designs/`. Role directories (manager/, designer/, cto/) are private workspaces.

## Step 3: Generate specs from existing code

If code exists in the project, ask: "Want me to generate Gherkin specs from your code? I'll create .feature files in `.hats/shared/specs/` describing what your app already does."
- If yes: read existing source files, generate `.feature` files in `.hats/shared/specs/`
- If no: skip

## Done

Tell the user: "Project ready. Run `/hats:manager` to start planning."

## Rules:
- NEVER delete or overwrite existing files without asking
- Ask before every destructive action
