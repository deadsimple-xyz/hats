---
name: doctor
description: Diagnose and fix a Hats project structure (missing dirs, symlinks, files).
---

# Doctor

Read `MIGRATIONS.md` for the full list of version-specific changes. The checks below reflect the current version (4.0.0).

## Step 0: Detect old version and migrate

Before running the normal check, detect whether the project is on an older version.

**Detect v3.x (pre-4.0.0):** check if any `.hats-*` symlinks exist inside role directories (e.g. `.hats/manager/.hats-shared`, `.hats/qa/.hats-manager`), OR if `.hats/manager/*.feature` exists (specs should be in `shared/specs/`), OR if `.hats/designer/` has design files (designs should be in `shared/designs/`).

If v3.x structure is found, report it and ask to migrate:
```
Doctor: Found a v3.x Hats project (symlinks in role dirs, specs in .hats/manager/).
Migration to v4.0.0 will:
  1. Move .hats/manager/*.feature → .hats/shared/specs/
  2. Move .hats/designer/* (real files) → .hats/shared/designs/
  3. Remove all .hats-* symlinks from role directories
  4. Keep role directories as private workspaces

Run migration now?
```

Wait for confirmation. Then execute:

```bash
# 1. Create new subdirectories
mkdir -p .hats/shared/specs .hats/shared/designs

# 2. Move specs
find .hats/manager/ -maxdepth 1 -name '*.feature' -exec mv {} .hats/shared/specs/ \;

# 3. Move designs (real files only, not symlinks)
find .hats/designer/ -maxdepth 1 -type f -exec mv {} .hats/shared/designs/ \;

# 4. Remove all .hats-* symlinks from all role directories
find .hats/manager/ .hats/designer/ .hats/cto/ .hats/qa/ -maxdepth 1 -name '.hats-*' -type l -delete
```

After migration completes, continue to Step 1 to verify.

**Detect v3.0.0 (pre-3.1.0):** check if `.hats-role` exists at the project root. If so, move it to `.hats/role`. Also check if `.gitignore` contains `.hats-role` — if so, replace with `.hats/role`.

**Detect v2 (pre-3.0.0):** check if any of `manager/`, `designer/`, `cto/`, `shared/`, `qa/` exist at the project root (without the `.hats/` prefix) AND `.hats/` does not yet exist.

If old v2 directories are found, report it and ask to migrate:

```
Doctor: Found a v2 Hats project (manager/, shared/, etc. at root).
Migration to v4.0.0 will:
  1. Move developer/* to project root (code no longer lives in developer/)
  2. Create .hats/{manager,designer,cto,shared,shared/specs,shared/designs,qa}/
  3. Move manager/*.feature → .hats/shared/specs/
  4. Move designer/* → .hats/shared/designs/
  5. Move qa/* → .hats/qa/
  6. Move shared/* → .hats/shared/
  7. Move status.json → .hats/status.json
  8. Remove old root-level Hats dirs

Run migration now?
```

Wait for confirmation. Then execute in order:

**1. Move developer/ contents to project root** (if `developer/` exists and has files):
```bash
find developer/ -maxdepth 1 ! -name 'developer' ! -name '.*' -exec mv {} . \;
```
Skip files that already exist at root — never overwrite.

**2. Create new directories:**
```bash
mkdir -p .hats/manager .hats/designer .hats/cto .hats/shared/specs .hats/shared/designs .hats/qa
```

**3. Move files to new locations** (skip symlinks, only move real files):
```bash
find manager/ -maxdepth 1 -name '*.feature' -exec mv {} .hats/shared/specs/ \;
find designer/ -maxdepth 1 -type f -exec mv {} .hats/shared/designs/ \;
find qa/ -maxdepth 1 -type f -exec mv {} .hats/qa/ \;
find shared/ -maxdepth 1 -type f -exec mv {} .hats/shared/ \;
[ -f status.json ] && mv status.json .hats/status.json
```

**4. Remove old root-level dirs** (now empty after migration):
```bash
rm -rf manager/ designer/ cto/ shared/ qa/ developer/
```
Only remove dirs that are now empty (or contain only the old symlinks). If a dir still has files, warn the user instead of deleting.

After migration completes, continue to Step 1 to verify the new structure is correct.

---

## Step 1: Check everything

Inspect the project root and print a checklist report. Mark each item as **ok**, **missing**, or **stale**.

### Directories (9)

- `.hats/manager/` (private workspace)
- `.hats/designer/` (private workspace)
- `.hats/cto/` (private workspace)
- `.hats/qa/`
- `.hats/developer/` (private workspace)
- `.hats/shared/`
- `.hats/shared/specs/` (Manager's .feature files)
- `.hats/shared/designs/` (Designer's mockups)
- `.hats/shared/threads/` (any-role topic memos)

### Stale symlinks (should NOT exist)

Check all role directories for `.hats-*` symlinks. If any exist, flag them as **stale** — they should be removed.

### Channels in `.hats/shared/`

Each of `manager2team`, `cto2team`, `designer2team`, `qa2dev`, `dev2qa`,
`dev2designer`, `qa2designer` should exist as a **directory** with an
`INDEX.md`. Create the directory if missing.

**If you find the flat `<channel>.md` instead, that is the migration and it is
not cosmetic.** A channel is appended at the bottom, `Read` returns the first
2000 lines, and the roles are told never to `tail` — so past roughly 130 KB the
newest entries are read by nobody, ever. Measured on a live project: 15 entries
in the file, 6 reachable.

Offer it, one command per channel, and say what it does:

```
Found 3 flat channels (qa2dev.md 985K, dev2qa.md 610K, manager2team.md 520K).
Roles reading these see entries from two weeks ago and nothing since.

Migrate? Each becomes a directory of entries plus an index; the original is
kept as ARCHIVE.md and the split is verified byte-for-byte before anything is
written.
```

Then, on a yes, per channel:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/channel.sh" split .hats/shared/<channel>.md
```

### Sizes — the check nobody had

A structure can be perfectly correct and still unreadable. Report, do not just
list:

- any channel `INDEX.md` over 100 KB, or any channel with more than 500
  entries → say the index itself now needs paging
- `.hats/status.json` over 4 KB → it is a state file, not a channel; something
  is writing narrative into it (seen in the wild at 106 KB)
- any `shared/*.md` document over 200 KB (`stack.md`, `test-contract.md`) →
  history is being appended to a file that is supposed to describe the present
- any role directory containing `node_modules/`, build output, or anything
  over 10 MB
- `.hats/logs/` older than 30 days, or over 5 MB
- `.hats/shared/test-contract.md` exists (only if `.hats/qa/` has test files — skip if no tests yet)

### Per-role scratchpads

- `.hats/manager/notes.md` exists (create empty if missing)
- `.hats/designer/notes.md` exists (create empty if missing)
- `.hats/cto/notes.md` exists (create empty if missing)
- `.hats/qa/notes.md` exists (create empty if missing)
- `.hats/developer/notes.md` exists (create empty if missing)

### Files

- `.hats/status.json` exists and contains `messages` key (add default messaging structure if missing)

### .gitignore

- `.gitignore` contains the line `.hats/role`
- `.gitignore` contains the line `.hats/logs/`
- `.gitignore` contains the line `.hats/debug`

## Step 2: Print the report

Print all findings as a checklist, for example:

```
## Hats Doctor

Directories:
  [ok]      .hats/manager/
  [ok]      .hats/designer/
  [missing] .hats/cto/
  [ok]      .hats/shared/
  [ok]      .hats/shared/specs/
  [ok]      .hats/shared/designs/
  [ok]      .hats/qa/

Stale symlinks:
  [stale]   .hats/qa/.hats-manager (remove)
  [stale]   .hats/qa/.hats-shared (remove)

Files:
  [ok]      .hats/status.json

Gitignore:
  [missing] .hats/role entry
```

If everything is ok, say "All good!" and stop.

## Step 3: Ask before fixing

If there are any missing or stale items, list what will be fixed and ask the user to confirm before proceeding.

## Step 4: Fix

Only after user confirms:

- Create missing directories (including `.hats/shared/specs/`, `.hats/shared/designs/`, `.hats/shared/threads/`, `.hats/developer/`)
- Create missing `notes.md` scratchpads (empty)
- Remove stale `.hats-*` symlinks from role directories
- Create missing `.hats/status.json` with `{}`
- Append `.hats/role` to `.gitignore` if missing
- Append `.hats/logs/` to `.gitignore` if missing
- Append `.hats/debug` to `.gitignore` if missing

## Rules

- NEVER delete existing files or directories
- NEVER overwrite `.hats/status.json` if it already exists
- Only fix what the user confirmed
