---
name: init
description: Scaffold a new Hats BDD project with the standard directory structure.
disable-model-invocation: true
---

# Initialize Hats Project

Create the standard Hats BDD project structure in the current directory.

## Create these directories:
- `features/`
- `designs/`
- `shared/`
- `src/`
- `tests/`

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
Tell the user the project is ready and they can start planning with you (the Manager).
