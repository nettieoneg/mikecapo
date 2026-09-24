# Mask Line — Product Audit Launcher

Change notes for the Power Automate flow `Mask Line - Product Audit Launcher`.

---

## Version 2 — Completion is signalled, not assumed

**Summary:** the flow no longer waits a fixed 60 minutes before generating the
PDF record. It now waits until someone clicks **Mark Audit Complete** on the
Teams card.

### Why this changed

Version 1 slept for 60 minutes after the audit sheet was created, then converted
whatever was in the workbook to PDF and announced `Status: Complete`.

That assumption fails whenever an audit takes longer than an hour — an auditor
pulled to a line issue, a shift change, a sheet opened late. When it fails, the
flow files a PDF of a **partially completed audit** into *Completed Audits* and
notifies three people that it is finished. Nothing detects this, and the
resulting document looks as authoritative as a real one.

For a quality record, a silent wrong answer is worse than a loud failure. The
fix makes "complete" something a person asserts rather than something the clock
infers.

### What changed in the flow

| Action | Change |
|---|---|
| `Delay` (60 minutes) | **Removed** |
| `Post card in a chat or channel` (opening card) | **Removed** — replaced by the action below |
| `Post adaptive card and wait for a response` | **Added** after `Create sharing link for a file or folder` |
| `Get file content using path 1` | **Re-pointed** to run after the new wait action |

The new card carries both buttons: **Open Audit Sheet** (the same sharing link
the v1 card used) and **Mark Audit Complete** (an `Action.Submit`, which is what
resumes the flow — an `Action.OpenUrl` cannot).

Settings on the wait action:

- **Update message:** replaces the card once clicked, so no stale clickable card
  is left in the channel.
- **Timeout:** `P2D`. Without a timeout the run holds open for up to 30 days.
- `Get file content using path 1` is also configured to run on **has timed out**,
  so an abandoned audit surfaces instead of disappearing.

### What people will notice

- **Auditors:** one card in the channel instead of one at the start and silence
  afterwards. Open the sheet from it, work at their own pace, come back and click
  Complete. No time pressure, and no new tool.
- **Shift handover now works.** The card lives in the channel, not a DM, so
  whoever is actually on the line can mark the audit complete — including someone
  who took over mid-shift.
- **Completion notifications are accurate.** The PDF is generated from a sheet
  someone confirmed was finished.

### What to test before trusting it

1. Submit a form, complete the sheet, click **Mark Audit Complete**. Confirm the
   PDF matches the finished sheet, not a blank template.
2. Submit and click Complete **immediately**, with the sheet untouched. Confirm
   the flow still runs cleanly — this is the path most likely to be taken by
   accident.
3. Submit and **do not click**. Confirm the card is still clickable the next day
   and the run is still waiting.
4. Confirm the card's **Update message** replaces it after clicking.

### Rolling back

Re-add a `Delay` action set to 60 minutes between
`Create sharing link for a file or folder` and `Get file content using path 1`,
restore the original single-button channel card, and delete the wait action.
No data migration is involved — the change is entirely in flow control.

### Still open after v2

Known issues carried forward, none of which this change addresses:

- **Filenames are not unique.** `Mask_Audit_{part}_{auditor}{date}.xlsx` collides
  when the same part is audited twice by the same person on the same day, and
  breaks entirely on an auditor name containing `/ \ : * ? " < > |`. Process
  Order is already captured and is unique — use it.
- **Three duplicated completion cards.** `Post card 1/2/3` are identical except
  for the recipient and run in sequence, so a failure in the first stops the
  rest. Replace with one card inside an `Apply to each` over a recipient array.
- **File lookup by reconstructed path.** `Get file content using path 1` rebuilds
  the path from the created file's name; use the returned item ID instead.
- **Temp file cleanup is conditional.** `Delete file` runs only when
  `Convert file` succeeds, so failures leave orphaned files in OneDrive root.
- **No failure paths anywhere**, and flow failure alerts are off.
- **The edit sharing link is org-wide.** Anyone in the organization with the link
  can edit a live audit sheet.

---

## Version 1 — Initial release

Form submission copies the master checklist template into the audit library,
creates an edit link, announces it in Teams, waits 60 minutes, converts the
workbook to PDF, files it, and notifies three people.
