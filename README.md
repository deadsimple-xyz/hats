# Hats

BDD-driven AI dev team. Five roles, one [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

```
mng -> dsgn -> cto -> qa -> dev
 |       |      |      |     |
specs  mockups stack  tests  code
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

# Work through the cycle
~/.hats/mng              # plan your project, write specs
~/.hats/dsgn             # create mockups from specs
~/.hats/cto              # decide technology stack
~/.hats/qa               # generate tests from specs
~/.hats/dev              # code until tests pass
```

Every command opens an interactive Claude Code session with the right role. You talk, it works. Add `--run` to skip the conversation and let it work autonomously:

```bash
~/.hats/dsgn --run
~/.hats/cto --run
~/.hats/qa --run
~/.hats/dev --run
```

The typical flow is `mng > dsgn > cto > qa > dev`, but you can talk to any role at any time. If you know your stack, skip the CTO. If you have your own designs, skip the Designer. If something breaks in tests, jump into `~/.hats/qa` and discuss it.

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

Then each role takes over:

| Role | Command | Reads | Writes |
|------|---------|-------|--------|
| **Manager** | `~/.hats/mng` | everything | `features/` |
| **Designer** | `~/.hats/dsgn` | `features/` | `designs/` |
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
