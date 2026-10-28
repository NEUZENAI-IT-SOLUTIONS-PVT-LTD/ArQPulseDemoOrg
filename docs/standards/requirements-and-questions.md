# Requirements and questions

**Goal:** a developer or coding agent asks the product owner only what the story and these
standards cannot answer. Everything else is decided — apply the standard and list it as an
assumption.

## The rule

| Ask | Do not ask — decide by standard |
|---|---|
| A **missing requirement** that changes what users see or what data changes, with no standard default | Naming, folders, file headers, API version |
| A **conflict with existing code or org config** (the class already exists with another signature, the field does not exist, the object already has a trigger, a flow already updates the same field) | Sharing, SOQL security clause, CRUD/FLS, how errors reach the UI |
| A **conflict between the story and a standard** (the story asks for `without sharing`) | Test style, coverage target, how security is tested |
| A **bug that cannot be reproduced** from the issue text | Query ordering, tie-breakers, null ordering, row limits |
| A **business rule** the story leaves open (who may see it, what happens on approval) | "Should we also support X later?" — build what the story asks |
| | Anything the story's acceptance criteria already state |

## Question budget

- **At most 3 questions per story.** A well-written story needs none.
- Every question says **what will be built if nobody answers**:
  "If there is no answer, the method returns an empty list."
- Prefer an **assumption** to a question. List assumptions in the analysis and the pull request:
  "Assumed (standard): results ordered `LastName ASC NULLS LAST, Id`."
- When answers come back and the work is analysed again, **do not add new questions** — unless an
  answer itself created a new conflict. Questions the standards now answer are dropped.
- Never ask the same thing twice in different words.

## Standard defaults for common gaps

| Gap in the story | Default | Owner of the rule |
|---|---|---|
| Parent id matches no record | Return an empty list — no data is not an error | [apex-standards.md](apex-standards.md#queries) |
| Null or blank input to a read method | Return an empty list (or `null` for a single record) | [apex-standards.md](apex-standards.md#queries) |
| Invalid input to a write method | Throw `AuraHandledException` (UI) or a custom exception (service) | [apex-standards.md](apex-standards.md#errors) |
| Ordering ties and nulls | `NULLS LAST`, then `Id` as the last sort key | [apex-standards.md](apex-standards.md#queries) |
| Single id or list of ids? | What the story says; UI methods take one id, services take collections | [apex-standards.md](apex-standards.md#bulk-safety) |
| More fields "for later"? | Only the fields the story names | [apex-standards.md](apex-standards.md#queries) |
| Test security behaviour? | Yes — one restricted-user test for every `USER_MODE` read | [apex-testing-standards.md](apex-testing-standards.md#security-tests) |
| Where files go, what they are called | `force-app/main/default/...`, names per the naming standard | [naming-conventions.md](naming-conventions.md) |

## Worked example — issue #1 (ContactController)

The first run of the Developer Agent asked 10 questions. Under these standards it asks **none**:

| Question asked | Answered by |
|---|---|
| `WITH USER_MODE` or `WITH SECURITY_ENFORCED`? Minimum API version? | The story says `WITH USER_MODE`; API version is `sourceApiVersion` |
| Valid id with no matching account: empty list or error? | Standard default: empty list |
| Extra fields or FLS checks in tests? | Story names the fields; testing standard requires one restricted-user test |
| Naming or packaging conventions? | Naming standard |
| Single id or bulkified for the future? | Story says single id; no future-proofing |
| Minimum Apex API version? | `sourceApiVersion` (duplicate of question 1) |
| How should the error surface? | Error standard: `AuraHandledException` |
| Should tests assert security behaviour? | Testing standard: yes, with `System.runAs` |
| Repository, namespace, header conventions? | Naming standard; no namespace (duplicate) |
| Tie-breaker and null ordering? | Query standard: `NULLS LAST`, then `Id` |
