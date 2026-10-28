# AGENTS.md — rules for every developer and coding agent

This file is the entry point for anyone who changes this repository: developers, the ArQPulse
Developer Agent, Claude Code, Copilot, Codex, Agentforce Vibes or any other coding agent.

The standards below are **decided**. Follow them without asking. Ask a person only what the
standards and the story cannot answer — see [Requirements and questions](docs/standards/requirements-and-questions.md).

## Read first

| Topic | File |
|---|---|
| What to ask, what never to ask | [docs/standards/requirements-and-questions.md](docs/standards/requirements-and-questions.md) |
| Names of classes, triggers, LWC, objects, fields, flows | [docs/standards/naming-conventions.md](docs/standards/naming-conventions.md) |
| Apex: sharing, security, queries, errors, async | [docs/standards/apex-standards.md](docs/standards/apex-standards.md) |
| Apex tests | [docs/standards/apex-testing-standards.md](docs/standards/apex-testing-standards.md) |
| Lightning Web Components | [docs/standards/lwc-standards.md](docs/standards/lwc-standards.md) |
| Branches, commits, pull requests | [docs/standards/branching-and-commits.md](docs/standards/branching-and-commits.md) |

## Order of authority

When two sources disagree, the higher one wins:

1. The story or bug's **acceptance criteria**.
2. **Answers** the product owner or developer gave on the issue or in chat.
3. These **project standards**.
4. Salesforce's own documented best practice.

If the story **conflicts with a standard** (for example, it asks for `without sharing`), do not
silently pick one: ask once, and say which standard it breaks.

## Non-negotiables

- **API version:** every new `-meta.xml` uses `sourceApiVersion` from `sfdx-project.json`.
- **Security:** classes are `with sharing`; SOQL runs `WITH USER_MODE`; DML runs `as user`.
- **No hardcoding:** no record ids, no user ids, no secrets, no endpoints in code.
- **Bulk-safe:** no SOQL or DML inside a loop.
- **Tests:** every Apex class ships with its test class, at least 90% coverage.
- **Formatting:** Prettier decides (`npm run prettier`). Do not hand-format.
- **Git:** work on a feature branch only. Never push to `main`. Agents never merge a pull request.
- **Scope:** build exactly what the story asks. No "future-proofing" unless the story asks for it.

## Definition of done

- The code meets every acceptance criterion and every standard above.
- Apex tests pass, and LWC Jest tests pass (`npm run test:unit`).
- `npm run lint` and `npm run prettier:verify` pass.
- The pull request links the issue and lists any assumptions made under a standard default.
