# Hats

BDD-driven AI dev team. Five roles, one [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

```
You <-> Manager -> Designer -> CTO -> QA -> Developer
  (plan & spec)  (mockups)  (stack) (tests) (code)
       |              |         |       |       |
  features/      designs/   shared/  tests/   src/
```

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI installed and authenticated

## Install

```bash
git clone git@github.com:deadsimple-xyz/hats.git ~/.hats
```

To update: `cd ~/.hats && git pull`

## Usage

```bash
# Create a new project
~/.hats/init my-app
cd my-app

# 1. Talk to the Manager -- plan your project, write specs
claude

# 2. Designer creates mockups from specs
~/.hats/designer

# 3. CTO decides technology stack
~/.hats/cto

# 4. QA generates tests from specs
~/.hats/qa

# 5. Developer codes until tests pass
~/.hats/dev
```

Every command opens an interactive Claude Code session with the right role. Add `--run` to skip the conversation and let it work autonomously:

```bash
~/.hats/designer --run
~/.hats/cto --run
~/.hats/qa --run
~/.hats/dev --run
```

## How It Works

You are the product owner. You talk to the **Manager** and describe what you want. The Manager writes [Gherkin](https://cucumber.io/docs/gherkin/) specs -- human-readable, machine-parseable `.feature` files:

```gherkin
@auth
Feature: JWT Authentication
  Users can register and login.
  Technical: RS256, access token 15min, refresh 7d.

  @critical @happy-path
  Scenario: Successful login
    Given a user "test@mail.com" with password "secret123" exists
    When user sends POST /auth/login with valid credentials
    Then response status is 200
    And response contains access_token and refresh_token
```

Then each role takes over in sequence:

| Role | Command | Reads | Writes |
|------|---------|-------|--------|
| **Manager** | `claude` | everything | `features/` |
| **Designer** | `~/.hats/designer` | `features/` | `designs/` |
| **CTO** | `~/.hats/cto` | `features/`, `designs/` | `shared/` |
| **QA** | `~/.hats/qa` | `features/`, `shared/` | `tests/` |
| **Developer** | `~/.hats/dev` | everything except `tests/` writes | `src/`, `shared/setup.md` |

Each role runs in its own Claude Code session with its own system prompt. The QA doesn't know how the Developer will implement things. The Developer can't modify the QA's tests. This separation is the point -- no shared blind spots.

## Project Structure

After `~/.hats/init my-app`:

```
my-app/
  CLAUDE.md        Points to ~/.hats for role instructions
  status.json      Current state
  features/        Gherkin specs
  designs/         Mockups and wireframes
  shared/          Cross-role knowledge
    stack.md         Technology decisions (CTO)
    setup.md         How to run the project (CTO/Developer)
    api.md           API conventions (CTO/Developer)
  src/             Implementation code
  tests/           Automated tests
```

## Why

When one AI writes code AND tests, it tests its own assumptions -- same blind spots. By splitting into roles with separate contexts and separate prompts, the QA tests *requirements* while the Developer implements *solutions*. Neither can see the other's instructions.

Gherkin `.feature` files are the contract between roles: readable by you, parseable by the AI.

## License

MIT
