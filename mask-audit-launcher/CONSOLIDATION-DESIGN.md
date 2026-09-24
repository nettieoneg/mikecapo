# Product Audit Launcher — consolidation design

A proposal to replace ~15 per-cell audit flows with **one form, one flow, and a
configuration list**. Not yet built.

---

## Why

The 15 flows are the same process with different parameters. The forms are
launchers — they capture Process Order, Part Number and Auditor; the audit
content lives in the Excel template, not the form. Everything that differs
between cells is configuration: a template path, two destination folders, a
Teams channel, a recipient list, a cell name.

The cost of that duplication is measurable: adding the completion step took an
afternoon across 15 flows, with the same one-character JSON mistakes made
repeatedly. The next change costs the same again, and the fleet drifts a little
further apart each time.

After consolidation, a change is one edit and a new cell is one list row.

---

## Configuration list: `Audit Config`

One row per production cell. The **FormChoice** value must match the form's
choice text exactly — that is the lookup key, and a mismatch is the single most
likely failure.

| Column | Type | Example | Notes |
|---|---|---|---|
| `FormChoice` | Single line of text | `Masks (911)` | Renamed Title column. Lookup key — must match the form choice text character for character |
| `CellCode` | Single line of text | `911` | Used in filenames |
| `CellName` | Single line of text | `Masks` | Used in card headings |
| `Active` | Yes/No | Yes | Retire a cell without deleting its history |
| `SiteAddress` | Single line of text | `https://…/teams/ProductQualityAudits` | Allows cells on different sites later |
| `TemplatePath` | Single line of text | `/Shared Documents/Master Templates (QE Managed)/Product_Audit_Checklist_Masks_911.xlsx` | Full server-relative path |
| `ExcelFolder` | Single line of text | `/Shared Documents/911 - Masks/Audits - Excel` | Working copy destination |
| `PdfFolder` | Single line of text | `/Shared Documents/911 - Masks/Completed Audits - PDF` | Record destination |
| `DocLibraryId` | Single line of text | `a4d8ca07-…` | Library GUID the sharing-link action needs |
| `TeamsGroupId` | Single line of text | `f308a059-…` | |
| `TeamsChannelId` | Single line of text | `19:e5b9b84…@thread.tacv2` | |
| `NotifyRecipients` | Multiple lines, plain text | `a@x.com;b@x.com` | Semicolon-separated |
| `Owner` | Person | | Who to contact when a cell's config is wrong |

**Not included on purpose:** a per-cell timeout. The wait action's timeout is a
static setting rather than an expression, so one value applies to every cell. If
a cell genuinely needs a different window, that is an argument for keeping it
separate, not for adding a column that cannot be honoured.

---

## The form

One form replaces 15. Questions:

1. **Production Cell** — Choice, required. One option per active cell, text
   matching `FormChoice` exactly.
2. **Process Order** — Text, required.
3. **Part Number** — Text, required.

**Drop the "Auditor Name" question.** The form already records the submitter's
identity; use `body/responder` instead. That removes a field, removes a typo
surface, and makes the auditor on the record the person who actually submitted
rather than a name someone typed.

---

## Flow: `Product Audit Launcher`

```
When a new response is submitted            (the one form)
  ↓
Get response details
  ↓
Get items — Audit Config                    (no OData filter; ~15 rows)
  ↓
Filter array                                FormChoice = the cell answer
                                            AND Active = true
  ↓
Condition — config found?
  ├─ No  → notify the process owner, Terminate
  └─ Yes → Compose "Config" = first(body('Filter_array'))
             ↓
           Get file content by path          Config TemplatePath
           Create file                       Config ExcelFolder
           Create sharing link (edit)        Config DocLibraryId
           Post adaptive card and wait       Config TeamsGroupId / TeamsChannelId
             ↓  (auditor clicks Mark Audit Complete)
           Get file content by ID            from Create file
           Create file (OneDrive temp) → Convert to PDF → Delete temp
           Create file                       Config PdfFolder
           Create sharing link (view)
           Post completion card              Config channel
           Apply to each over recipients     split(Config NotifyRecipients, ';')
```

### Design decisions worth keeping

**Filter array, not an OData filter.** `Get items` with a `$filter` breaks on
apostrophes and quoting. With only ~15 rows, fetching all and filtering in the
flow is simpler, has no escaping rules, and shows its working in run history.

**One `Compose` holding the config object.** Every downstream action reads
`outputs('Config')?['ExcelFolder']` and similar. One place to look, and the run
history shows the entire resolved configuration in a single step — which is what
you will want the first time a cell misbehaves.

**A no-match branch that notifies and stops.** This is the equivalent of the
Default case in the EWR switch: a cell with no config row, or one marked
inactive, must reach a human rather than fail silently or half-run.

**Filenames from controlled values only:**

```
concat(Config CellCode, '_Audit_', ProcessOrder, '_', utcNow('yyyyMMdd-HHmm'), '.xlsx')
```

No free text, so no illegal characters; Process Order plus timestamp makes it
unique. The current scheme collides when the same part is audited twice by the
same person on a day, and breaks on a name containing `/`.

**One completion card definition, sent in a loop** over the recipient list —
replacing the three duplicated cards, which today also run in sequence so a
failure in the first stops the rest.

**Failure paths** on the three file actions and the conversion, routed to the
cell `Owner`.

---

## What this costs, honestly

**You lose per-cell form customization.** If any of the 15 forms capture extra
questions, one form cannot serve them unless those become optional questions
with branching. Check all 15 before committing: if three cells are genuinely
different, consolidate the twelve and leave those three alone. A 12-to-1
reduction is still most of the benefit.

**Every entry point has to be repointed** — QR codes, Teams tabs, bookmarks,
signatures. This is the bulk of the rollout effort, not the flow build.

**One flow is a single point of failure.** Today a broken flow affects one cell;
afterwards it affects all of them. That is a fair trade for having one correct
flow instead of fifteen drifting ones, but it raises the bar on testing and makes
the failure paths non-optional.

---

## Migration

1. **Audit the 15 forms first.** Confirm they capture the same fields. This
   decides whether the plan is 15-to-1 or 12-to-1.
2. **Build the config list** and fill one row per cell from each existing flow's
   parameters. Doing this is also a free inventory of what you actually have.
3. **Build the new form and flow** alongside the existing ones. Nothing is
   switched off.
4. **Pilot two cells** — one high volume, one low. Run both old and new in
   parallel for a week; the old forms keep working.
5. **Cut over the rest**, one at a time. Turn each old flow off rather than
   deleting it, so a rollback is one toggle.
6. **Repoint QR codes, Teams tabs and links.**
7. **Delete the old flows and forms** after a month of clean running — not
   before.
