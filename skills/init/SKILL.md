---
description: Initialize Hats in a new or existing project.
disable-model-invocation: true
---

# Initialize Hats

## Step 1: Check for existing code

Look at the current directory. If there are source code files (anything besides .git, .gitignore, README, etc.):
- Tell the user what you found
- Ask: "Want me to move your existing code to `developer/`? Config files stay at the root."
- **Wait for confirmation before moving anything**
- If yes: move source code to `developer/`, keep config files (package.json, pyproject.toml, Cargo.toml, .env, .gitignore, etc.) at root

If the directory is empty or only has .git, skip to Step 2.

## Step 2: Create Hats structure

Create the missing directories and files (do NOT overwrite existing files):
- `manager/`
- `designer/`
- `shared/`
- `developer/`
- `qa/`
- `status.json` (with `{}`)
- `.gitignore` (append if exists, create if not):
  ```
  node_modules/
  __pycache__/
  venv/
  .env
  *.log
  ```

## Step 3: Generate specs from existing code

If code was moved to `developer/` in Step 1, ask: "Want me to generate Gherkin specs from your code? I'll create .feature files in manager/ describing what your app already does."
- If yes: read `developer/`, generate `.feature` files
- If no: skip

## Done

Tell the user: "Project ready. Run `/hats:manager` to start planning."

## Rules:
- NEVER delete or overwrite existing files without asking
- Ask before every destructive action
