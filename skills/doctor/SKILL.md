---
description: Diagnose and fix a Hats project structure (missing dirs, symlinks, files).
---

# Doctor

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
- `manager/.hats-designs` → `../designer`

**designer/**
- `designer/.hats-shared` → `../shared`
- `designer/.hats-specs` → `../manager`

**cto/**
- `cto/.hats-shared` → `../shared`
- `cto/.hats-specs` → `../manager`
- `cto/.hats-designs` → `../designer`

**qa/**
- `qa/.hats-shared` → `../shared`
- `qa/.hats-specs` → `../manager`

**developer/**
- `developer/.hats-shared` → `../shared`
- `developer/.hats-specs` → `../manager`
- `developer/.hats-designs` → `../designer`

### Files

- `status.json` exists (any content is fine)

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
  [ok]      manager/.hats-designs → ../designer
  [missing] cto/.hats-shared → ../shared
  [missing] cto/.hats-specs → ../manager
  [missing] cto/.hats-designs → ../designer
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
  ln -sfn ../designer manager/.hats-designs
  ln -sfn ../shared designer/.hats-shared
  ln -sfn ../manager designer/.hats-specs
  ln -sfn ../shared cto/.hats-shared
  ln -sfn ../manager cto/.hats-specs
  ln -sfn ../designer cto/.hats-designs
  ln -sfn ../shared qa/.hats-shared
  ln -sfn ../manager qa/.hats-specs
  ln -sfn ../shared developer/.hats-shared
  ln -sfn ../manager developer/.hats-specs
  ln -sfn ../designer developer/.hats-designs
  ```
- Create missing `status.json` with `{}`
- Append `.hats-role` to `.gitignore` if missing

## Rules

- NEVER delete existing files or directories
- NEVER overwrite `status.json` if it already exists
- Only fix what the user confirmed
