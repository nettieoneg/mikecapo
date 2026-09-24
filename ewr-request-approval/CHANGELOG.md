# EWR Request & Approval Routing

Change notes for the Power Automate flow `EWR — Route for Approval`.

---

## Version 2 — Correct outcomes, real records

**Summary:** fixes the routing condition, the approval record, and the rejection
path. Version 1 could send an approved request down the rejected path, lose all
but one approver's comment, and tell a rejected requester nothing at all.

### What was wrong, and why

**Approvals routed to the rejection branch.** The condition read
`outcome = Approve` **OR** `outcome = Reject`, which is true for every completed
approval and therefore discriminates nothing. The `outcome` token was also
unbound and resolving empty, so the whole thing evaluated false and every request
— approved or not — fell to the else branch. Now a single clause,
`Outcome is equal to Approve`, with the token bound to the approval action.

**Comments were overwritten.** The status update ran inside a loop over the
approval responses, patching the same list item once per approver. With four
approvers the record kept only the last comment. The update now runs once,
outside any loop, against a `Select` action that collects every comment into one
value.

**Rejected requests died silently.** The rejection branch set `Status = Rejected`
and nothing else — no reason recorded, no email, no date. A requester was never
told their request was refused. The branch now records the reason and date and
sends an email leading with why.

**The confirmation email claimed things that had not happened.** It fired before
the list item was created and before routing was decided, while asserting the
request was "logged into the system" and "routed to the appropriate review
queue". Moved to run after `Create item`, which also lets it name the approvers
and carry the real request number.

**The PDF blocked the status update.** Inside the approved branch the document
generation ran *before* the item was marked Approved, so a failure in PDF
conversion left the request un-updated and the requester un-notified. Order
inverted: record and notify first, generate the document last. A nice-to-have
never gates the essential path.

**One PDF per approver.** Document generation also sat in a loop, producing a
near-identical PDF for each approver. Moved out; one document lists all
approvers, built from a `Select` over the responses.

**The PDF filename was the PDF.** `Create file` used the entire HTML document as
the filename where the EWR ID was intended — an immediate failure on filename
length and illegal characters. Filenames are now the EWR ID alone, which cannot
contain a character SharePoint rejects. Free-text titles no longer appear in any
filename; a request titled "Replace motor - Line 4/5" used to break the step.

**The request number was random.** `EWR-` plus `rand(100000, 999999)` is neither
unique nor ordered — collisions become likely within a few hundred requests. Now
derived from the SharePoint list `ID`, which is unique, sequential and free.

### Smaller corrections

- `join(body('Select')?['body'], …)` → `join(body('Select'), …)`. A Select's
  `body()` already returns the array; the extra `?['body']` indexes an array with
  a string key and fails at runtime.
- Approval decision emails went to the flow author rather than the requester.
- An empty `"" equals ""` clause left in the condition builder was removed.
- Placeholder text (`[Submission time / utcNow…]`) was printing literally on
  generated PDFs.
- Optional date fields are now guarded with `if(empty(…), …)` before
  `formatDateTime`, which otherwise throws and fails the whole email action.
- `Importance: High` removed from routine messages and kept for rejections.

### What people will notice

- **Requesters** are told who has their request and roughly how long to expect,
  and are told when it is refused and why. Previously a rejection was silence.
- **Approvers** see no change. Their comments now actually survive into the
  record.
- **Everyone** gets a request number that means something — sequential, so you
  can tell which request came first.

### Still open after v2

- Approver addresses remain hardcoded in the Switch. Editing them is a one-line
  change per request type, which is the accepted tradeoff for v1/v2.
- No reminders or escalation on a late approval. A weekly review of the Pending
  view is the current mechanism.
- No cost thresholds — a $2,000 and a $200,000 request route identically.
- No attachments, and a rejected request is resubmitted rather than edited.
- Notifications still send from the flow owner's mailbox pending a shared mailbox
  and Send As permission.
- Failure paths are configured on some actions but not yet all.

---

## Version 1 — Initial build

Form submission routes by request type through a Switch to a hardcoded approver
list, creates a SharePoint list item, waits for an everyone-must-approve
approval, updates the record, and generates a PDF.
