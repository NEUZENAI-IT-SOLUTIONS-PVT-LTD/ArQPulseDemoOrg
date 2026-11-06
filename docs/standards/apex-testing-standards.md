# Apex testing standards

## Coverage

- Every new or changed class: **at least 90%** line coverage from its own test class.
- Coverage is a floor, not the goal: each acceptance criterion has at least one test.

## Structure

- Test class `<ClassUnderTest>Test`, `@IsTest private`.
- Shared records in one `@TestSetup` method, built through `TestDataFactory`.
- Never `@IsTest(SeeAllData=true)`.
- Arrange → `Test.startTest()` → act → `Test.stopTest()` → assert.
- Use the `Assert` class (`Assert.areEqual`, `Assert.isTrue`) with a message on every assertion.

## What every test class covers

| Case | Required when |
|---|---|
| Happy path, checking the actual values returned (fields, order) | Always |
| Empty result | The method reads data |
| Null / invalid input | The method takes input |
| Error path, asserting the message | The method can throw |
| Limit respected (create more than `MAX_ROWS`) | The query has a `LIMIT` |
| Bulk: 200 records | Triggers, batch, queueable, services |

## Security tests

- Every method that reads with `USER_MODE` has one test that runs as a restricted user
  (`System.runAs`, a user on the `Minimum Access - Salesforce` profile with no extra
  permission sets) and asserts that the user gets no data or a security exception — whichever the
  method's contract says.
- Do not test platform behaviour beyond that one check.

## Async tests

- Batch, queueable and scheduled work is asserted after `Test.stopTest()`.
- Schedulers: assert the `CronTrigger` (expression and job name), not the batch result.
- Callouts use `HttpCalloutMock`. Tests never call a real endpoint.

## Test data

- `TestDataFactory` creates records with only the required fields, plus parameters for what the test cares about.
- No hardcoded ids. Look users and profiles up in the test.
