---
description: Scaffold a new Hats BDD project with the standard directory structure.
disable-model-invocation: true
---

# Initialize Hats Project

Create the standard Hats BDD project structure in the current directory.

## Create these directories:
- `manager/`
- `designer/`
- `shared/`
- `developer/`
- `qa/`

## Create these files:

### `status.json`
```json
{}
```

### `.gitignore`
```
node_modules/
__pycache__/
venv/
.env
*.log
```

## After creating the structure:
Tell the user: "Project ready. Run `/hats:manager` to talk to the Manager and plan your app."
