# Lightning Web Components standards

## Data

| Need | Use |
|---|---|
| Read record fields | Lightning Data Service (`getRecord`, `lightning-record-form`) |
| Read a list from Apex | `@wire` on a `cacheable=true` method |
| Change data | Imperative Apex call or `updateRecord`, then `refreshApex` / `notifyRecordUpdateAvailable` |

## Every component handles four states

1. **Loading** — `lightning-spinner`.
2. **Data** — the content.
3. **Empty** — a plain message from a Custom Label (e.g. "No contacts yet").
4. **Error** — a readable message (`reduceErrors` helper), never a raw error object.

## Markup and style

- Base components first (`lightning-card`, `lightning-datatable`, `lightning-button`).
- SLDS classes and styling hooks; no hardcoded colours.
- User-visible text comes from Custom Labels.
- Accessible: every input has a label, every icon button has `alternative-text`.

## Metadata

- `isExposed` only when the story places the component on a page.
- `targets` limited to what the story asks (e.g. `lightning__RecordPage` with `<objects>` set).
- `apiVersion` = `sourceApiVersion`.

## JavaScript

- `@api` only for values a parent or page sets; everything else is private.
- No `document.querySelector` outside the component; use `this.template`.
- Prettier and ESLint (`npm run lint`) must pass.

## Jest tests

- `__tests__/<bundle>.test.js` for every component.
- Cover: data shown, empty state, error state, and every user action.
- Mock Apex with `jest.mock` and emit wire data with the wire adapter test utilities.
- Clean the DOM in `afterEach`.
