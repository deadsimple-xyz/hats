# Hats

BDD-driven AI dev team. Five roles, one [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

```
manager -> designer -> cto -> qa -> developer
   |          |         |      |       |
 specs     mockups    stack  tests    code
```

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI installed and authenticated

## Install

```bash
git clone https://github.com/deadsimple-xyz/hats.git
mkdir my-app && cd my-app && git init
claude --plugin-dir ../hats
```

Official marketplace listing is pending review.

## Usage

```
/hats:init          # new project — scaffold the directory structure
/hats:adopt         # existing project — move code to developer/, generate specs
/hats:manager       # "Manager here. What are we building?"
/hats:designer      # "Any ideas for the look, or should I read the specs?"
/hats:cto           # "Got any stack preferences, or should I figure it out?"
/hats:qa            # "Want me to generate tests from the specs?"
/hats:developer     # "Ready to work!"
```

The typical flow is `manager > designer > cto > qa > developer`, but you can talk to any role at any time. If you know your stack, skip the CTO. If you have your own designs, skip the Designer. If something breaks in tests, jump into QA and discuss it.

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

| Role | Agent | Can read | Can write |
|------|-------|----------|-----------|
| **Manager** | `manager` | `manager/`, `designer/`, `shared/` | `manager/` |
| **Designer** | `designer` | `manager/`, `designer/`, `shared/` | `designer/` |
| **CTO** | `cto` | `manager/`, `designer/`, `shared/` | `shared/` |
| **QA** | `qa` | `manager/`, `designer/`, `shared/`, `qa/` | `qa/`, `shared/qa-report.md` |
| **Developer** | `developer` | `manager/`, `designer/`, `shared/`, `developer/` | `developer/`, `shared/` |

Permissions are enforced by hooks -- the Developer literally *can't* read tests, and the QA *can't* read source code. QA writes a plain-language report (`shared/qa-report.md`) so the Developer understands what failed and why, without seeing test code.

## Project Structure

After `/hats:init`:

```
my-app/
  manager/         Gherkin specs
  designer/        Mockups and wireframes
  cto/             (no dir -- writes to shared/)
  qa/              Automated tests
  developer/       Implementation code
  shared/          Cross-role knowledge
    stack.md         Technology decisions (CTO)
    setup.md         How to run the project (CTO/Developer)
    api.md           API conventions (CTO/Developer)
    qa-report.md     Test results for Developer (QA)
  status.json      Current state
```

## Why

When one AI writes code AND tests, it tests its own assumptions -- same blind spots. By splitting into roles with separate contexts and separate prompts, the QA tests *requirements* while the Developer implements *solutions*. Neither can see the other's code.

The Developer can't read test source -- only test results via `shared/qa-report.md` and `bash qa/run-tests.sh`. The QA can't read implementation -- it writes tests from specs alone. Gherkin `.feature` files are the contract between roles: readable by you, parseable by the AI.

## License

MIT
