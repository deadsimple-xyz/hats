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

In Claude Code:

```
/plugin marketplace add deadsimple-xyz/hats
/plugin install hats@deadsimple-xyz
```

Or test from a local clone:

```bash
git clone git@github.com:deadsimple-xyz/hats.git
claude --plugin-dir ./hats
```

## Usage

```bash
mkdir my-app && cd my-app && git init

# Start Claude Code -- Manager agent loads by default
claude
```

Use `/hats:init` to scaffold the standard project structure.

The Manager helps you plan your project and write Gherkin specs. When ready, switch roles by asking:

```
"Switch to the Designer agent"
"Switch to CTO"
"Have the QA generate tests"
```

The typical flow is `mng > dsgn > cto > qa > dev`, but you can talk to any role at any time. If you know your stack, skip the CTO. If you have your own designs, skip the Designer. If something breaks in tests, jump into QA and discuss it.

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

| Role | Agent | Reads | Writes |
|------|-------|-------|--------|
| **Manager** | `mng` | everything | `features/` |
| **Designer** | `dsgn` | `features/` | `designs/` |
| **CTO** | `cto` | `features/`, `designs/` | `shared/` |
| **QA** | `qa` | `features/`, `shared/` | `tests/` |
| **Developer** | `dev` | everything except `tests/` writes | `src/`, `shared/setup.md` |

Each role is a separate Claude Code agent with its own system prompt. The QA doesn't know how the Developer will implement things. The Developer can't modify the QA's tests. This separation is the point -- no shared blind spots.

## Project Structure

After `/hats:init`:

```
my-app/
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
