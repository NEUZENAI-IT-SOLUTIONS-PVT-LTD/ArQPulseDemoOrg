# Naming conventions

All metadata lives under `force-app/main/default/<type>/`. No namespace.

## Apex classes

PascalCase. The suffix says the role. One top-level class per role.

| Role | Pattern | Example |
|---|---|---|
| Controller for LWC/Aura (`@AuraEnabled`) | `<Subject>Controller` | `ContactController` |
| Business logic | `<Subject>Service` | `ContactService` |
| Shared SOQL queries | `<Object>Selector` | `ContactSelector` |
| Trigger handler | `<Object>TriggerHandler` | `ContactTriggerHandler` |
| Batch Apex | `<Object><Purpose>Batch` | `ContactEmailCleanupBatch` |
| Queueable | `<Verb><Subject>Queueable` | `SyncContactPhoneQueueable` |
| Schedulable | `<Purpose>Scheduler` | `ContactEmailCleanupScheduler` |
| REST resource | `<Subject>Resource` | `ContactSummaryResource` |
| Invocable (Flow action) | `<Verb><Subject>Action` | `CloseOpenCasesAction` |
| Custom exception | `<Subject>Exception` | `ContactServiceException` |
| Test class | `<ClassUnderTest>Test` | `ContactControllerTest` |
| Test data | `TestDataFactory` (one per project) | `TestDataFactory` |

## Apex code

| Item | Rule | Example |
|---|---|---|
| Methods | camelCase, starts with a verb | `getContactsByAccount` |
| Variables | camelCase, full words | `accountIds`, not `accIds` |
| Collections | plural | `contacts` |
| Maps | `<values>By<Key>` | `contactsByAccountId` |
| Constants | UPPER_SNAKE_CASE, `private static final` | `MAX_ROWS` |
| Booleans | `is` / `has` / `can` prefix | `hasMailingAddress` |
| Test methods | `<behaviour>_<condition>` or a plain sentence in camelCase | `returnsEmptyList_whenAccountIdIsNull` |

## Triggers

- `<Object>Trigger`, one per object: `ContactTrigger`, `InvoiceTrigger` for `Invoice__c`.

## Lightning Web Components

| Item | Rule | Example |
|---|---|---|
| Bundle folder | camelCase | `contactList` |
| JS class | PascalCase of the folder | `ContactList` |
| HTML tag in markup | kebab-case with `c-` | `<c-contact-list>` |
| Custom events | lower case, no hyphens, a verb in past tense | `contactselected` |
| Jest test | `__tests__/<bundle>.test.js` | `__tests__/contactList.test.js` |

## Objects, fields and other metadata

| Item | Rule | Example |
|---|---|---|
| Custom object | `Words_Joined_By_Underscore__c`, singular | `Invoice_Line__c` |
| Custom field | Same pattern; a lookup ends with the object name | `Due_Date__c`, `Primary_Contact__c` |
| Boolean field | `Is_` / `Has_` prefix | `Is_Active__c` |
| Labels | Title Case words, no underscores | `Invoice Line` |
| Description | Required on every object and field: what it holds, who uses it | |
| Record-triggered flow | `<Object>_<When>_<Purpose>` | `Contact_BeforeSave_SetDefaults` |
| Screen flow | `<Purpose>_Screen` | `Create_Case_Screen` |
| Permission set | `<App_Or_Feature>_<Access>` | `Contact_Management_Edit` |
| Custom label | `<Area>_<Message>` | `ContactList_NoContacts` |
| Custom metadata type | `<Purpose>_Setting__mdt` | `Integration_Setting__mdt` |
| REST URL mapping | kebab-case nouns | `/contact-summary/*` |
| Scheduled job name | `<Purpose> - <Frequency>` | `Contact Email Cleanup - Nightly` |
