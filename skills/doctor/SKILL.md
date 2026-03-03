---
description: Diagnose and fix a Hats project structure (missing dirs, symlinks, files).
---

# Doctor

Read `MIGRATIONS.md` for the full list of version-specific changes. The checks below reflect the current version (2.3.0).

## Step 1: Check everything

Inspect the project root and print a checklist report. Mark each item as **ok**, **missing**, or **broken** (symlink exists but points to wrong target).

### Directories (6)

- `manager/`
- `designer/`
- `cto/`
- `shared/`
- `developer/`
- `qa/`

### Symlinks (12)

**manager/**
- `manager/.hats-shared` → `../shared`
- `manager/.hats-designer` → `../designer`

**designer/**
- `designer/.hats-shared` → `../shared`
- `designer/.hats-manager` → `../manager`

**cto/**
- `cto/.hats-shared` → `../shared`
- `cto/.hats-manager` → `../manager`
- `cto/.hats-designer` → `../designer`

**qa/**
- `qa/.hats-shared` → `../shared`
- `qa/.hats-manager` → `../manager`

**developer/**
- `developer/.hats-shared` → `../shared`
- `developer/.hats-manager` → `../manager`
- `developer/.hats-designer` → `../designer`

### Messaging files in `shared/`

- `shared/manager2team.md` exists (create empty if missing)
- `shared/cto2team.md` exists (create empty if missing)
- `shared/qa2dev.md` exists (create empty if missing)
- `shared/dev2qa.md` exists (create empty if missing)
- `shared/dev2designer.md` exists (create empty if missing)
- `shared/qa2designer.md` exists (create empty if missing)
- `shared/designer2team.md` exists (create empty if missing)

### Files

- `status.json` exists and contains `messages` key (add default messaging structure if missing)

### .gitignore

- `.gitignore` contains the line `.hats-role`

## Step 2: Print the report

Print all findings as a checklist, for example:

```
## Hats Doctor

Directories:
  [ok]      manager/
  [ok]      designer/
  [missing] cto/
  [ok]      shared/
  [ok]      developer/
  [ok]      qa/

Symlinks:
  [ok]      manager/.hats-shared → ../shared
  [ok]      manager/.hats-designer → ../designer
  [missing] cto/.hats-shared → ../shared
  [missing] cto/.hats-manager → ../manager
  [missing] cto/.hats-designer → ../designer
  ...

Files:
  [ok]      status.json

Gitignore:
  [missing] .hats-role entry
```

If everything is ok, say "All good!" and stop.

## Step 3: Ask before fixing

If there are any missing or broken items, list what will be fixed and ask the user to confirm before proceeding.

## Step 4: Fix

Only after user confirms:

- Create missing directories
- Recreate missing or broken symlinks using `ln -sfn`:
  ```bash
  ln -sfn ../shared manager/.hats-shared
  ln -sfn ../designer manager/.hats-designer
  ln -sfn ../shared designer/.hats-shared
  ln -sfn ../manager designer/.hats-manager
  ln -sfn ../shared cto/.hats-shared
  ln -sfn ../manager cto/.hats-manager
  ln -sfn ../designer cto/.hats-designer
  ln -sfn ../shared qa/.hats-shared
  ln -sfn ../manager qa/.hats-manager
  ln -sfn ../shared developer/.hats-shared
  ln -sfn ../manager developer/.hats-manager
  ln -sfn ../designer developer/.hats-designer
  ```
- Create missing `status.json` with `{}`
- Append `.hats-role` to `.gitignore` if missing

## Rules

- NEVER delete existing files or directories
- NEVER overwrite `status.json` if it already exists
- Only fix what the user confirmed
