---
description: Initialize Hats in a new or existing project.
---

# Initialize Hats

## Step 1: Check for existing code

Look at the current directory. If there are source code files (anything besides `.git/`, `.gitignore`, `README*`, `LICENSE*`):
- Tell the user what you found
- Ask which option they prefer:
  1. **(Recommended)** Move existing files to `developer/` automatically. All files move except: `.git/`, config files (`package.json`, `pyproject.toml`, `Cargo.toml`, `.env`, `.gitignore`, `README*`, `LICENSE*`, etc.) which stay at root.
  2. Create Hats directories only and let the user move files manually.
- **Wait for the user to choose before doing anything**
- If option 1: move files to `developer/`, skip `.git/` entirely
- If option 2: skip straight to Step 2

If the directory is empty or only has `.git/`, skip to Step 2.

## Step 2: Create Hats structure

Create the missing directories and files (do NOT overwrite existing files):
- `manager/`
- `designer/`
- `cto/`
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
  .hats-role
  *.log
  ```

## Step 3: Create symlinks

Create `.hats-*` symlinks in each role's folder. These give each role access to the data it needs while maintaining isolation.

**manager/**
```bash
ln -sfn ../shared manager/.hats-shared
ln -sfn ../designer manager/.hats-designs
```

**designer/**
```bash
ln -sfn ../shared designer/.hats-shared
ln -sfn ../manager designer/.hats-specs
```

**cto/**
```bash
ln -sfn ../shared cto/.hats-shared
ln -sfn ../manager cto/.hats-specs
ln -sfn ../designer cto/.hats-designs
```

**qa/**
```bash
ln -sfn ../shared qa/.hats-shared
ln -sfn ../manager qa/.hats-specs
```

**developer/**
```bash
ln -sfn ../shared developer/.hats-shared
ln -sfn ../manager developer/.hats-specs
ln -sfn ../designer developer/.hats-designs
```

## Step 4: Generate specs from existing code

If code was moved to `developer/` in Step 1, ask: "Want me to generate Gherkin specs from your code? I'll create .feature files in manager/ describing what your app already does."
- If yes: read `developer/`, generate `.feature` files
- If no: skip

## Done

Tell the user: "Project ready. Run `/hats:manager` to start planning."

## Rules:
- NEVER delete or overwrite existing files without asking
- Ask before every destructive action
