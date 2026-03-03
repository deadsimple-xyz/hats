---
description: Diagnose and fix a Hats project structure (missing dirs, symlinks, files).
---

# Doctor

Read `MIGRATIONS.md` for the full list of version-specific changes. The checks below reflect the current version (3.0.0).

## Step 0: Detect old version and migrate

Before running the normal check, detect whether the project is on an older version.

**Detect v2 (pre-3.0.0):** check if any of `manager/`, `designer/`, `cto/`, `shared/`, `qa/` exist at the project root (without the `.hats/` prefix) AND `.hats/` does not yet exist.

If old v2 directories are found, report it and ask to migrate:

```
Doctor: Found a v2 Hats project (manager/, shared/, etc. at root).
Migration to v3.0.0 will:
  1. Move developer/* to project root (code no longer lives in developer/)
  2. Create .hats/{manager,designer,cto,shared,qa}/
  3. Move manager/*.feature → .hats/manager/
  4. Move designer/* → .hats/designer/
  5. Move qa/* → .hats/qa/
  6. Move shared/* → .hats/shared/
  7. Move status.json → .hats/status.json
  8. Recreate symlinks in new locations
  9. Remove old root-level Hats dirs (manager/, designer/, cto/, shared/, qa/, developer/)

Run migration now?
```

Wait for confirmation. Then execute in order:

**1. Move developer/ contents to project root** (if `developer/` exists and has files):
```bash
# Move everything except symlinks and hidden files
find developer/ -maxdepth 1 ! -name 'developer' ! -name '.*' -exec mv {} . \;
```
Skip files that already exist at root — never overwrite.

**2. Create new directories:**
```bash
mkdir -p .hats/manager .hats/designer .hats/cto .hats/shared .hats/qa
```

**3. Move files to new locations** (skip symlinks, only move real files):
```bash
# .feature files from manager/
find manager/ -maxdepth 1 -name '*.feature' -exec mv {} .hats/manager/ \;
# all real files from designer/, qa/, shared/
find designer/ -maxdepth 1 -type f -exec mv {} .hats/designer/ \;
find qa/ -maxdepth 1 -type f -exec mv {} .hats/qa/ \;
find shared/ -maxdepth 1 -type f -exec mv {} .hats/shared/ \;
# status.json
[ -f status.json ] && mv status.json .hats/status.json
```

**4. Recreate symlinks:**
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

**5. Remove old root-level dirs** (now empty after migration):
```bash
rm -rf manager/ designer/ cto/ shared/ qa/ developer/
```
Only remove dirs that are now empty (or contain only the old symlinks). If a dir still has files (e.g., because a file was skipped to avoid overwriting), warn the user instead of deleting.

After migration completes, continue to Step 1 to verify the new structure is correct.

---

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
