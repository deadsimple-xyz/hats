# Migrations

The doctor reads this file to upgrade old Hats projects.

## 3.2.0 → 4.0.0

### Breaking: symlinks removed, shared data consolidated

All cross-role symlinks are removed. Specs and designs move into `.hats/shared/` subdirectories. This eliminates recursive symlink cycles that caused tools (bddgen, playwright) to create infinite directory nesting.

**New structure:**
- `.hats/shared/specs/` — Manager writes `.feature` files here (was `.hats/manager/`)
- `.hats/shared/designs/` — Designer writes design files here (was `.hats/designer/`)
- `.hats/manager/`, `.hats/designer/`, `.hats/cto/` — empty private workspaces (no symlinks)

**What moved:**
```bash
# Specs
mkdir -p .hats/shared/specs
mv .hats/manager/*.feature .hats/shared/specs/

# Designs
mkdir -p .hats/shared/designs
mv .hats/designer/*.md .hats/shared/designs/
```

**Remove all symlinks:**
```bash
find .hats/manager/ .hats/designer/ .hats/cto/ .hats/qa/ -maxdepth 1 -name '.hats-*' -type l -delete
```

**Guard update:** The write guard now enforces ownership of `shared/specs/` (manager only) and `shared/designs/` (designer only) in addition to the existing per-file rules for `shared/`.

**Agent path changes:**
- `.hats/manager/*.feature` → `.hats/shared/specs/*.feature`
- `.hats/designer/*` → `.hats/shared/designs/*`
- `.hats-manager/` → `.hats/shared/specs/`
- `.hats-designer/` → `.hats/shared/designs/`
- `.hats-shared/` → `.hats/shared/`
- All `../status.json` → `.hats/status.json`

**run-tests.sh:** QA must ALWAYS use `bash run-tests.sh` to run tests. Never run test commands directly (no raw `npx playwright`, `npx bddgen`, `pytest`).

## 3.1.0 → 3.2.0

### Test contract and `qa` attributes

QA now writes a **test contract** to `.hats/shared/test-contract.md` listing all observable expectations (qa attributes, API endpoints, response fields). The Developer reads this contract instead of guessing what tests expect.

**Selectors:** QA tests must use `qa="..."` HTML attributes instead of CSS classes, ids, or tag names. Example: `<button qa="reset-button">Reset</button>`, selected as `[qa="reset-button"]`.

**Existing projects with tests:** If `.hats/qa/` already contains tests using CSS selectors:
1. Run `/hats:qa` — QA will review existing tests, migrate selectors to `qa` attributes, and write `test-contract.md`
2. Run `/hats:developer` — Developer will read the contract and add `qa="..."` attributes to the implementation

**New file:** `.hats/shared/test-contract.md` (created by QA, read by Developer)

**Guard update:** QA can now write `test-contract.md` to `.hats/shared/`.

### Autopilot scope change

Autopilot (`/hats:autopilot`) now runs only the **QA ↔ Developer loop**, not the full pipeline. Manager, Designer, and CTO must be run manually first. Max 3 outer rounds.

## 3.0.0 → 3.1.0

### Role file moved

`.hats-role` → `.hats/role` — the role activation file now lives inside `.hats/` with everything else.

**Auto-migration (doctor handles this):**
- If `.hats-role` exists at project root, move it to `.hats/role`
- If `.gitignore` contains `.hats-role`, replace with `.hats/role`

**Manual fix:**
```bash
[ -f .hats-role ] && mv .hats-role .hats/role
sed -i '' 's/^\.hats-role$/.hats\/role/' .gitignore
```

### Debug logging (optional)

Touch `.hats/debug` to enable JSONL debug logging to `.hats/logs/YYYY-MM-DD.jsonl`. Remove the file to disable. Zero overhead when off.

### .gitignore

- `.hats-role` → `.hats/role`
- Add `.hats/logs/` (debug log output)

## 2.3.0 → 3.0.0

### Breaking: directory restructure

All Hats directories move into `.hats/`. The `developer/` directory is eliminated — code lives at project root.

**Move code out of developer/ (if applicable):**
```bash
# If your code was in developer/, move it to project root first:
mv developer/* . && rm -rf developer/
```

**Remove old Hats dirs** (after moving content):
```bash
rm -rf manager/ designer/ cto/ shared/ qa/ status.json
```

**Create new structure:**
```bash
mkdir -p .hats/{manager,designer,cto,shared,qa}
# Move specs:
mv manager/*.feature .hats/manager/ 2>/dev/null || true
# Move designs:
mv designer/* .hats/designer/ 2>/dev/null || true
# Move tests:
mv qa/* .hats/qa/ 2>/dev/null || true
# Move shared:
mv shared/* .hats/shared/ 2>/dev/null || true
mv status.json .hats/status.json 2>/dev/null || true
```

**Recreate symlinks:**
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

Note: no symlinks are created for the developer role — developer reads `.hats/` paths directly.

## 2.2.0 → 2.3.0

### Symlink renames

Old names are removed; recreate with new names:

**manager/**
- `.hats-designs` → renamed to `.hats-designer`

**designer/**
- `.hats-specs` → renamed to `.hats-manager`

**cto/**
- `.hats-specs` → renamed to `.hats-manager`
- `.hats-designs` → renamed to `.hats-designer`

**qa/**
- `.hats-specs` → renamed to `.hats-manager`

**developer/**
- `.hats-specs` → renamed to `.hats-manager`
- `.hats-designs` → renamed to `.hats-designer`

To fix: remove old symlinks and recreate:
```bash
rm manager/.hats-designs designer/.hats-specs cto/.hats-specs cto/.hats-designs qa/.hats-specs developer/.hats-specs developer/.hats-designs
ln -sfn ../designer manager/.hats-designer
ln -sfn ../manager designer/.hats-manager
ln -sfn ../manager cto/.hats-manager
ln -sfn ../designer cto/.hats-designer
ln -sfn ../manager qa/.hats-manager
ln -sfn ../manager developer/.hats-manager
ln -sfn ../designer developer/.hats-designer
```

## 2.1.0 → 2.2.0

### New file in `shared/`
- `shared/cto2team.md` -- CTO → team stack announcements (create empty if missing)

### `status.json`
Add `cto2team` channel to `messages` key:
```json
{
  "messages": {
    "cto2team": { "count": 0, "read_by": { "manager": 0, "designer": 0, "qa": 0, "developer": 0 } }
  }
}
```

## 2.0.0 → 2.1.0

### New files in `shared/`
- `manager2team.md` -- Manager → team announcements (create empty if missing)
- `qa2dev.md` -- QA → Developer messages (create empty if missing)
- `dev2qa.md` -- Developer → QA messages (create empty if missing)
- `dev2designer.md` -- Developer → Designer questions (create empty if missing)
- `qa2designer.md` -- QA → Designer questions (create empty if missing)
- `designer2team.md` -- Designer → Developer + QA responses (create empty if missing)

### `status.json`
Add `messages` key if missing:
```json
{
  "messages": {
    "manager2team": { "count": 0, "read_by": { "cto": 0, "designer": 0, "qa": 0, "developer": 0 } },
    "qa2dev": { "count": 0, "read_by": { "developer": 0, "manager": 0 } },
    "dev2qa": { "count": 0, "read_by": { "qa": 0, "manager": 0 } },
    "dev2designer": { "count": 0, "read_by": { "designer": 0, "manager": 0 } },
    "qa2designer": { "count": 0, "read_by": { "designer": 0, "manager": 0 } },
    "designer2team": { "count": 0, "read_by": { "developer": 0, "qa": 0, "manager": 0 } }
  }
}
```

## 1.0.0 → 2.0.0

### New directory
- `cto/`

### New symlinks (12 total)

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

### .gitignore
- Must contain `.hats/role`

### Files
- `status.json` must exist (create with `{}` if missing)
