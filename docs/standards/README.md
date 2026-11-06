# Project standards

Owned by the project architect. Every developer and coding agent follows them.

| File | Covers |
|---|---|
| [requirements-and-questions.md](requirements-and-questions.md) | What is decided by standard, what is worth a question, the question budget |
| [naming-conventions.md](naming-conventions.md) | Names for every kind of metadata and for Apex/JS code |
| [apex-standards.md](apex-standards.md) | Sharing, security, queries, errors, triggers, async, REST |
| [apex-testing-standards.md](apex-testing-standards.md) | Coverage, test data, security tests, bulk tests, async tests |
| [lwc-standards.md](lwc-standards.md) | Lightning Web Components and their Jest tests |
| [branching-and-commits.md](branching-and-commits.md) | Branch strategy, branch names, commits, pull requests |

## How a standard changes

- A standard changes only by pull request, approved by the architect.
- Change the one file that owns the rule. Do not repeat a rule in another file; link to it.
- A standard is never changed inside a feature pull request "on the way".
