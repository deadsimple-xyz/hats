---
description: Adopt an existing project into the Hats BDD workflow.
disable-model-invocation: true
---

# Adopt Existing Project

Set up Hats in an existing codebase. Follow these steps IN ORDER, waiting for user confirmation at each step.

## Step 1: Scan the project

Look at the current directory structure and files. Summarize what you found:
- What language/framework is used
- Where the source code lives
- Whether tests already exist
- Whether there's already a developer/ directory

## Step 2: Move code to developer/

If the source code is NOT already in `developer/`:
- Tell the user what you plan to move to `developer/` and what you'll leave in place (config files, package.json, etc. stay at root)
- **Ask the user to confirm before moving anything**
- Move source code to `developer/`

If code is already in `developer/`, skip this step.

## Step 3: Create Hats structure

Create the missing directories and files:
- `manager/` (if missing)
- `designer/` (if missing)
- `shared/` (if missing)
- `qa/` (if missing -- or keep existing tests in place)
- `status.json` (if missing)

Do NOT overwrite existing files.

## Step 4: Ask about auto-generating features

Ask the user: "Want me to read your code and generate Gherkin feature specs from it? I'll create .feature files in manager/ based on what your app already does."

- If yes: read the source code in `developer/`, generate `.feature` files that describe the existing behavior
- If no: tell them to run `/hats:manager` when ready to write specs manually

## Rules:
- NEVER delete or overwrite existing files without asking
- Keep config files (package.json, pyproject.toml, Cargo.toml, etc.) at the project root
- Keep dotfiles (.env, .gitignore, etc.) at the project root
- Only move actual source code to `developer/`
- Ask before every destructive action
