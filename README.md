# Hats

BDD-driven AI dev team. Five roles, one [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

```
manager -> designer -> cto -> qa -> developer
   |          |         |      |       |
 specs     mockups    stack  tests    code
```

## Quick Start

```bash
cd ~/Code                          # your projects folder
git clone https://github.com/deadsimple-xyz/hats.git

cd my-app                          # your project (or mkdir my-app && cd my-app && git init)
claude --plugin-dir ../hats        # start Claude Code with Hats plugin
/hats:init                         # creates .hats/ directory structure
/hats:manager                      # "What are we building?"
```

Requires [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI. Official marketplace listing is pending review.

## Commands

```
/hats:init          # set up project (new or existing)
/hats:manager       # specs & planning
/hats:designer      # wireframes & UI descriptions
/hats:cto           # stack decisions
/hats:qa            # automated tests from specs
/hats:developer     # implementation (TDD)
/hats:autopilot     # run the full pipeline autonomously
/hats:solo          # exit role mode, work as plain Claude
/hats:doctor        # diagnose and fix project structure
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

| Role | Can read | Can write |
|------|----------|-----------|
| **Manager** | `.hats/manager/`, `.hats/designer/`, `.hats/shared/` | `.hats/manager/`, `.hats/shared/manager2team.md` |
| **Designer** | `.hats/manager/`, `.hats/designer/`, `.hats/shared/` | `.hats/designer/`, `.hats/shared/designer2team.md` |
| **CTO** | `.hats/manager/`, `.hats/designer/`, `.hats/shared/` | `.hats/shared/stack.md`, `setup.md`, `api.md`, `cto2team.md` |
| **QA** | `.hats/manager/`, `.hats/designer/`, `.hats/shared/`, `.hats/qa/` | `.hats/qa/`, `.hats/shared/qa-report.md`, `qa2dev.md`, `qa2designer.md` |
| **Developer** | `.hats/manager/`, `.hats/designer/`, `.hats/shared/` + project root | project root, `.hats/shared/setup.md`, `api.md`, `dev2qa.md`, `dev2designer.md` |

Permissions are enforced by hooks -- the Developer literally *can't* read tests, and the QA *can't* read source code. QA writes a plain-language report (`.hats/shared/qa-report.md`) so the Developer understands what failed and why, without seeing test code.

## Project Structure

After `/hats:init`:

```
my-app/
  .hats/
    manager/         Project specs (.feature files)
    designer/        Mockups and wireframes
    cto/             (empty -- CTO writes to shared/)
    qa/              Automated e2e tests
    shared/          Cross-role knowledge
      stack.md         Technology decisions (CTO)
      setup.md         How to run the project (CTO/Developer)
      api.md           API conventions (CTO/Developer)
      qa-report.md     Test results for Developer (QA)
      manager2team.md  Manager → team announcements
      cto2team.md      CTO → team stack announcements
      designer2team.md Designer → team responses
      qa2dev.md        QA → Developer messages
      dev2qa.md        Developer → QA messages
      dev2designer.md  Developer → Designer questions
      qa2designer.md   QA → Designer questions
    status.json      Current state and message counters
    role             Active role (managed by hooks)
  src/               Your code lives at project root
```

## Debug Logging

Enable debug logging to see exactly what each role does — every tool use, command, file read/write, and guard block:

```bash
touch .hats/debug          # enable
rm .hats/debug             # disable
```

Logs go to `.hats/logs/YYYY-MM-DD.jsonl` (one JSON object per line). Zero overhead when disabled — the hook checks for the flag file and exits immediately.

Example log:
```jsonl
{"ts":"2026-03-04T14:30:00Z","role":"none","tool":"Write","file":".hats/role"}
{"ts":"2026-03-04T14:30:01Z","role":"manager","tool":"Read","file":"agents/manager.md"}
{"ts":"2026-03-04T14:30:05Z","role":"manager","tool":"Agent","description":"Write feature specs"}
{"ts":"2026-03-04T14:30:07Z","role":"manager","tool":"Write","file":".hats/shared/manager2team.md"}
{"ts":"2026-03-04T14:30:15Z","event":"write_block","role":"designer","file":"src/index.ts","tool":"Write","reason":"designer can only write inside .hats/"}
```

See [self-learning.md](self-learning.md) for how to use logs to improve Hats itself.

## Why

When one AI writes code AND tests, it tests its own assumptions -- same blind spots. By splitting into roles with separate contexts and separate prompts, the QA tests *requirements* while the Developer implements *solutions*. Neither can see the other's code.

The Developer can't read test source -- only test results via `.hats/shared/qa-report.md` and `bash .hats/qa/run-tests.sh`. The QA can't read implementation -- it writes tests from specs alone. Gherkin `.feature` files are the contract between roles: readable by you, parseable by the AI.

## License

MIT
