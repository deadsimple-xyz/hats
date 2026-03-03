# Migrations

The doctor reads this file to upgrade old Hats projects.

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
- Must contain `.hats-role`

### Files
- `status.json` must exist (create with `{}` if missing)
