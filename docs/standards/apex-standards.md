# Apex standards

## API version

- Every new `.cls-meta.xml` and `.trigger-meta.xml` uses `sourceApiVersion` from `sfdx-project.json`.
- Do not change the API version of an existing file unless the story asks for it.

## Sharing

| Class kind | Declaration |
|---|---|
| Controllers, services, REST resources, batch, queueable, schedulable | `with sharing` |
| Utility code called from many places | `inherited sharing` |
| Anything else | `without sharing` only with a comment saying why **and** architect approval in the PR |

## Security (CRUD and field-level security)

- Static SOQL: `WITH USER_MODE`. Do not use `WITH SECURITY_ENFORCED` in new code.
- Dynamic SOQL: `Database.queryWithBinds(query, binds, AccessLevel.USER_MODE)`.
- DML: `insert as user`, `update as user`, `Database.update(records, false, AccessLevel.USER_MODE)`.
- System-mode access is an exception, with a comment and architect approval.
- **Never** build SOQL by joining user input into a string. Use bind variables.

## Queries

- Select only the fields the story needs. Do not add fields "for later".
- Every query that returns a list has a `LIMIT` held in a constant (`MAX_ROWS`).
- Ordering is deterministic: `ORDER BY <field> ASC NULLS LAST, Id`.
- **Read methods never fail because data is missing:**
  - null or blank input → empty list (or `null` when the method returns one record);
  - a valid id that matches nothing → empty list (or `null`).
- Queries used in more than one place go to `<Object>Selector`. A query used by one controller may stay there.

## Bulk safety

- No SOQL and no DML inside a loop. Collect ids in a `Set<Id>`, query once, use a `Map`.
- Triggers, services, batch and queueable code work on collections.
- `@AuraEnabled` UI methods may take a single id when the story says so. Do not add list
  versions "for the future".

## Errors

| Where | How |
|---|---|
| `@AuraEnabled` method, user-facing error | `AuraHandledException` with a plain message; call `setMessage()` with the same text so tests can read it |
| Service layer | A custom `<Subject>Exception` |
| Partial DML results | `Database.SaveResult` checked; failures logged, not silently dropped |

- No empty `catch` blocks.
- Never `System.debug` personal data (emails, phone numbers, names) or secrets.

## Controllers (`@AuraEnabled`)

- Thin: input checks, one call to a selector or service, return.
- Read-only methods are `@AuraEnabled(cacheable=true)`. Cacheable methods do no DML.
- Public methods have a short ApexDoc comment (`@param`, `@return`).

## Triggers

- One trigger per object, listing every event it handles.
- No logic in the trigger body: it calls `<Object>TriggerHandler`.
- The handler is bulk-safe and runs one query per event, not per record.

## Async

| Need | Use |
|---|---|
| Up to a few thousand records, follow-up work after a trigger | Queueable (not `@future`) |
| Large volumes | Batch Apex, default scope 200, `Database.Stateful` only when counting across chunks |
| Run on a schedule | `<Purpose>Scheduler` that only starts the job; cron expression in a constant; job name per the naming standard |
| Callouts | Queueable with `Database.AllowsCallouts`; endpoint from a Named Credential |

- Enqueue only when there is work (check the changed fields first).

## REST resources

- `@RestResource(urlMapping='/<kebab-case>/*')`, `with sharing`.
- Responses are JSON from a small inner response class, never a raw SObject.
- Status codes: 200 found, 400 invalid input, 404 not found, 500 unexpected error (message, no stack trace).

## Hardcoding

- No record ids, user ids, profile names, URLs or secrets in code.
- Use Custom Metadata, Custom Labels and Named Credentials.

## Formatting

- Prettier with `prettier-plugin-apex` (`.prettierrc`). Run `npm run prettier` before committing.
