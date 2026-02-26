# 🎩 Hats

BDD-driven AI dev team. Three hats, one Claude Code.

```
You ←→ Manager        ./update-tests       ./dev-loop
   (plan & spec)      (QA writes tests)    (dev codes until green)
        ↓                    ↓                    ↓
  features/*.feature → automated tests → implementation
                                              ↓
                                         tests pass? → done
                                         tests fail? → fix & retry
                                         stuck?      → ask you
```

## Quick Start

```bash
git clone git@github.com:deadsimple-xyz/hats.git my-project
cd my-project

# 1. Talk to the manager — plan your project, create specs
claude

# 2. QA generates tests from specs
./update-tests

# 3. Developer codes until tests pass
./dev-loop
```

That's it. Three commands.

## How It Works

### 🎩 Manager (`claude`)

You open Claude Code in the project root and talk. Discuss what to build, architecture, constraints. The manager creates `features/*.feature` files in [Gherkin](https://cucumber.io/docs/gherkin/) format:

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

  @edge-case
  Scenario: Invalid password
    Given a user "test@mail.com" exists
    When user sends POST /auth/login with wrong password
    Then response status is 401
```

Gherkin is readable by you AND parseable by the QA. It's your spec, your contract, your source of truth. Edit it freely.

### 🧪 QA (`./update-tests`)

Opens a Claude Code session as QA engineer. Reads your `.feature` files and generates real, runnable test code. You watch the process and can help.

Tests are written **from specs, not from code** — this is the key. QA doesn't know how the developer will implement things. It tests the contract.

### 💻 Developer (`./dev-loop`)

Opens a Claude Code session as developer. Reads the specs, looks at the tests, writes code to make them pass. Runs tests, fixes failures, repeats.

Rules the developer follows:
- Cannot modify QA's tests
- Cannot modify `.feature` files
- Can only write implementation code
- If stuck, asks you for help

### 📊 Status (`status.json`)

The manager can read this to tell you how things are going:

```json
{
  "phase": "developing",
  "cycle": 2,
  "summary": "Developer working on implementation"
}
```

## Project Structure

```
my-project/
├── features/            ← your specs (Gherkin .feature files)
├── manager/CLAUDE.md    ← manager personality
├── qa/CLAUDE.md         ← QA personality
├── developer/CLAUDE.md  ← developer personality
├── update-tests         ← script: specs → tests
├── dev-loop             ← script: code until green
└── status.json          ← current state
```

## The Idea

When one AI writes code AND tests, it tests its own assumptions — same blind spots. By splitting into roles with **separate contexts and separate instructions**, the QA tests *requirements* while the developer implements *solutions*. Neither can see the other's prompt.

Gherkin `.feature` files are the bridge: human-readable, machine-parseable, and owned by you.

## License

MIT
