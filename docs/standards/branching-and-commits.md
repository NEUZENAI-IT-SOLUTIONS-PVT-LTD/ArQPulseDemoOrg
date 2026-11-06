# Branching, commits and pull requests

## Strategy — short-lived branches off `main`

```
main ──●──────────●──────────●──►   always deployable, protected
        \        /  \        /
         feature/…   bugfix/…        one story or bug each, merged by pull request
```

- `main` is protected: no direct pushes, merge only by an approved pull request with passing checks.
- One branch per story or bug, created from the latest `main`.
- A branch lives days, not weeks. Rebase on or merge `main` before opening the pull request.
- Hotfixes branch from `main` like any other change and go through the same pull request.

## Branch naming

Branch naming: `<type>/<key>-<slug>`

| Part | Rule | Example |
|---|---|---|
| `<type>` | `feature` (story), `bugfix` (bug), `hotfix` (production fix), `chore` (tooling, docs) | `feature` |
| `<key>` | Jira key (`PROJ-123`) or GitHub issue as `GH-<number>` | `GH-1` |
| `<slug>` | 2–6 words of the title, lower case, hyphens, at most 40 characters | `contact-controller` |

Examples: `feature/GH-1-contact-controller`, `bugfix/GH-8-soql-injection-account-helper`.

Never name a branch `main`, `master`, `develop`, `release/*` or `production`.

## Commits

Commit format: Conventional Commits, e.g. `feat(contact): add ContactController (GH-1)`

- Types: `feat`, `fix`, `test`, `refactor`, `docs`, `chore`.
- Scope: the object or feature area, lower case (`contact`, `account`).
- Summary: imperative, at most 72 characters, no full stop.
- End with the issue key in brackets.
- Small commits that each build. Never commit secrets, `.sf/`, `.sfdx/` or `.scan/`.

## Pull requests

- Title: same format as a commit.
- Body:
  - **What changed** — files and why.
  - **How it was tested** — Apex test classes run, Jest tests, coverage numbers.
  - **Assumptions** — every standard default applied instead of asking.
  - **Issue** — `Closes #<n>` or the Jira link.
- At least one approving review from a developer who did not write the change.
- Required checks: Apex tests, `npm run lint`, `npm run prettier:verify`, `npm run test:unit`.
- **Coding agents may open pull requests. They never approve or merge them, and never push to `main`.**

## Deploying

- Feature branches deploy to a developer sandbox or scratch org only.
- Only `main` deploys to shared sandboxes and production, through the release process.
