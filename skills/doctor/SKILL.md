---
description: Diagnose and fix a Hats project structure (missing dirs, symlinks, files).
---

# Doctor

Read `MIGRATIONS.md` for the full list of version-specific changes. The checks below reflect the current version (3.0.0).

## Step 1: Check everything

Inspect the project root and print a checklist report. Mark each item as **ok**, **missing**, or **broken** (symlink exists but points to wrong target).

### Directories (5)

- `.hats/manager/`
- `.hats/designer/`
- `.hats/cto/`
- `.hats/shared/`
- `.hats/qa/`

### Symlinks (9)

**`.hats/manager/`**
- `.hats/manager/.hats-shared` → `../shared`
- `.hats/manager/.hats-designer` → `../designer`

**`.hats/designer/`**
- `.hats/designer/.hats-shared` → `../shared`
- `.hats/designer/.hats-manager` → `../manager`

**`.hats/cto/`**
- `.hats/cto/.hats-shared` → `../shared`
- `.hats/cto/.hats-manager` → `../manager`
- `.hats/cto/.hats-designer` → `../designer`

**`.hats/qa/`**
- `.hats/qa/.hats-shared` → `../shared`
- `.hats/qa/.hats-manager` → `../manager`

### Messaging files in `.hats/shared/`

- `.hats/shared/manager2team.md` exists (create empty if missing)
- `.hats/shared/cto2team.md` exists (create empty if missing)
- `.hats/shared/qa2dev.md` exists (create empty if missing)
- `.hats/shared/dev2qa.md` exists (create empty if missing)
- `.hats/shared/dev2designer.md` exists (create empty if missing)
- `.hats/shared/qa2designer.md` exists (create empty if missing)
- `.hats/shared/designer2team.md` exists (create empty if missing)

### Files

- `.hats/status.json` exists and contains `messages` key (add default messaging structure if missing)

### .gitignore

- `.gitignore` contains the line `.hats-role`

## Step 2: Print the report

Print all findings as a checklist, for example:

```
## Hats Doctor

Directories:
  [ok]      .hats/manager/
  [ok]      .hats/designer/
  [missing] .hats/cto/
  [ok]      .hats/shared/
  [ok]      .hats/qa/

Symlinks:
  [ok]      .hats/manager/.hats-shared → ../shared
  [ok]      .hats/manager/.hats-designer → ../designer
  [missing] .hats/cto/.hats-shared → ../shared
  [missing] .hats/cto/.hats-manager → ../manager
  [missing] .hats/cto/.hats-designer → ../designer
  ...

Files:
  [ok]      .hats/status.json

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
  ln -sfn ../shared .hats/manager/.hats-shared
  ln -sfn ../designer .hats/manager/.hats-designer
  ln -sfn ../shared .hats/designer/.hats-shared
  ln -sfn ../manager .hats/designer/.hats-manager
  ln -sfn ../shared .hats/cto/.hats-shared
  ln -sfn ../manager .hats/cto/.hats-manager
  ln -sfn ../designer .hats/cto/.hats-designer
  ln -sfn ../shared .hats/qa/.hats-shared
  ln -sfn ../manager .hats/qa/.hats-manager
  ```
- Create missing `.hats/status.json` with `{}`
- Append `.hats-role` to `.gitignore` if missing

## Rules

- NEVER delete existing files or directories
- NEVER overwrite `.hats/status.json` if it already exists
- Only fix what the user confirmed
