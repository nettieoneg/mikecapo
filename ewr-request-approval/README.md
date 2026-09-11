# EWR Request & Approval Routing — MVP

Submit Engineering Work Requests through Microsoft Forms and route them for
approval based on the request type selected on the form.

Deliberately minimal: **one form, one SharePoint list, one flow (~10 actions).**
Approver names are hardcoded in the flow and edited by hand when people change.
That tradeoff is intentional — see [Known limits](#known-limits).

---

## Architecture

```
Microsoft Form  ──▶  Power Automate flow  ──▶  SharePoint list (record + audit)
 (7 questions)         (route + approve)   ──▶  Approvals (Teams / email)
                                           ──▶  Email to requester
```

---

## Step 1 — SharePoint list: `EWR Requests`

Create a blank list in the team's SharePoint site. Rename the default **Title**
column to `Request Title`, then add:

| Column            | Type                | Notes                                        |
|-------------------|---------------------|----------------------------------------------|
| `Request Title`   | Single line of text | Renamed default Title column                 |
| `RequestType`     | Choice              | EHS, Maintenance, IT, Facilities, Engineering |
| `Requester`       | Single line of text | Email captured by the form automatically      |
| `Location`        | Single line of text |                                              |
| `Description`     | Multiple lines      | Plain text                                   |
| `Justification`   | Multiple lines      | Plain text                                   |
| `NeedByDate`      | Date only           |                                              |
| `EstimatedCost`   | Single line of text | Text, not currency — lets people write "unknown" |
| `Status`          | Choice              | Submitted, Approved, Rejected — default Submitted |
| `Approvers`       | Single line of text | Who the request was sent to                  |
| `DecisionComments`| Multiple lines      | Plain text                                   |
| `DecisionDate`    | Date and time       |                                              |

The list's built-in **ID** column is the EWR number. Free, unique, no counter to
maintain. Add it to the default view.

Optional 2-minute win: save a view called **Pending** filtered to
`Status = Submitted`, sorted oldest-first. That is the whole follow-up system for v1.

---

## Step 2 — Microsoft Form

**Create the form from the SharePoint site or Team, not from your personal
Forms page.** A group-owned form survives if you change roles; a personal one
does not. This is the one setup detail worth getting right on day one.

Seven questions:

1. **Request Type** — Choice, required: EHS / Maintenance / IT / Facilities / Engineering
2. **Short title for this request** — Text, required
3. **Location or area** — Text (or Choice if the site list is short and stable)
4. **Describe the work requested** — Long text, required
5. **Why is it needed?** — Long text, required
6. **Need-by date** — Date
7. **Estimated cost, if known** — Text

Leave the form set to "Only people in my organization can respond" — it then
records the submitter's email automatically, so no "your email" question is needed.

Skip file uploads in v1. Attachments land in the form owner's OneDrive and need
extra flow actions to move onto the list item; if a drawing is needed, the
approver can ask for it. Add uploads in v2 once the routing is trusted.

---

## Step 3 — Power Automate flow: `EWR — Route for Approval`

Automated cloud flow. Actions in order:

**1. Trigger — Microsoft Forms → When a new response is submitted**
Pick the form.

**2. Microsoft Forms → Get response details**
Same form; Response Id = `Response Id` from the trigger.

**3. Variables → Initialize variable**
- Name: `Approvers`
- Type: String
- Value: leave empty

**4. Control → Switch**
On: the **Request Type** answer from step 2. One case per type, each containing a
single **Set variable** action on `Approvers`:

| Case          | `Approvers` value (semicolons, no spaces)             |
|---------------|-------------------------------------------------------|
| EHS           | `ehs.manager@company.com;ops.director@company.com`    |
| Maintenance   | `maint.manager@company.com;plant.manager@company.com` |
| IT            | `it.manager@company.com`                              |
| Facilities    | `facilities.manager@company.com`                      |
| Engineering   | `eng.manager@company.com;plant.manager@company.com`   |
| **Default**   | `you@company.com`                                     |

The Default case is the safety net: an unmatched answer routes to you rather
than vanishing. Never delete it.

This Switch is the only thing you edit when approvers change — one value per row.

**5. SharePoint → Create item** (list `EWR Requests`)
Map the form answers to the columns. Set `Status` = `Submitted`,
`Requester` = *Responder's Email*, `Approvers` = `Approvers` variable.

**6. Approvals → Start and wait for an approval**
- **Approval type:** `Approve/Reject – Everyone must approve`
- **Title:** `EWR #<ID from step 5> – <Request Type> – <Short title>`
- **Assigned to:** the `Approvers` variable
- **Details:** paste the answers as markdown, and include a link to the list item
  so approvers can see the record:
  ```
  **Requester:** <Responder's Email>
  **Location:** <Location>
  **Need by:** <Need-by date>
  **Estimated cost:** <Estimated cost>

  **What is being requested**
  <Description>

  **Why**
  <Justification>

  [Open in SharePoint](<Link to item from step 5>)
  ```

One action covers the manager and the boss: both are notified at once, and the
flow waits until every person listed has responded.

**7. Control → Condition** — `Outcome` *is equal to* `Approve`

**If yes:**
- SharePoint → **Update item**: `Status` = `Approved`,
  `DecisionDate` = `utcNow()`, `DecisionComments` =
  `join(body('Start_and_wait_for_an_approval')?['responses'], ' | ')`
  — or simply map the first response's Comments if that expression is fiddly.
- Outlook → **Send an email (V2)** to `Requester`: "EWR #ID approved."

**If no:**
- Same two actions with `Status` = `Rejected` and a rejection email that includes
  the approver's comments.

---

## Step 4 — Test before announcing

1. Put **your own email** in every Switch case and submit one request per type.
   Confirm the right branch fires and the list item is created correctly.
2. Approve one, reject one. Check both emails arrive and `Status` updates.
3. Swap in the real approver emails.
4. Walk one real approver through their first approval in the Teams **Approvals**
   app so they know it is not spam.

---

## Known limits

Accepted on purpose, each with the workaround for now:

| Limit | Workaround in v1 | Fix in a later version |
|---|---|---|
| Approver emails hardcoded in the flow | Edit the Switch when someone changes roles | Move to a SharePoint routing list the flow reads |
| No cost thresholds — a $2K and a $200K request route identically | Approvers escalate verbally | Add a cost condition, or walk the org chart with *Get manager (V2)* |
| No reminders or escalation if an approver sits on it | Check the **Pending** list view weekly | Add a parallel timeout branch that emails a nudge |
| Forms responses cannot be edited; rejection means resubmit | Requester submits a new form | Power App edit form over the list item |
| No attachments | Approver requests drawings by email | Add file upload + a *Add attachment* action |
| If an approver is on leave the request stalls | Add the backup person to that Switch case | Alternate-approver lookup |

## When to outgrow this design

Move off Forms when you need any of: live dropdowns from an equipment or
approver list, saved drafts, editing a submitted request, more than a handful of
conditional sections, or external (non-tenant) requesters. Until then, Forms is
the reason people will actually use it.
