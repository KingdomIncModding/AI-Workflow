# GitHub Issues - Read, Review, Fix

## Standing user authorization (2026-11-14)

For authorized mod work, the user requires the local agent to maintain the
affected GitHub issues without asking again for each routine update:

- When addressing an issue, add a visible progress note or checklist saying
  what is being addressed and how it will be checked.
- Explain the fix in ordinary player language, including an example when useful.
- Record what was actually checked and its result. Distinguish a small test
  kingdom, a source review and a test in the player's own kingdom; do not
  describe one as another or claim an untested outcome.
- If a fix immediately causes another observed problem, create a separate
  issue in the affected mod's verified repository and link it to the original.
  Check for an existing matching issue first. Record regressions caught and
  fixed before publication too, explicitly saying they were fixed before release.
- When the requested behavior is complete and verified, add the completion
  note and close the issue with state reason `completed`. Include the version
  and download link when released. Keep partial, blocked or unverified work open
  and state what remains. Do not close merely because code was changed.
- Re-read after writing to verify the note, state and completion reason.

This supersedes older mod-local blanket prohibitions on issue updates for
this workflow. It does not authorize unrelated issues, labeling/assignment,
new feature implementation, code pushes, tags or releases. A request to list
issues alone still does not authorize implementing them. Preserve existing
reports and comments; avoid duplicate progress/completion posts.

## Pull all issues for one mod

1. Read `{ModName}/mod.json`; confirm `repository.url` resolves to the
   intended GitHub repo, with access to the issues list.
2. Read ALL open and closed issues, including pagination, without
   modifying the repository. Do not confuse pull requests with issues.
3. Show issue number, plain-language title, open/closed status, labels,
   and URL; optionally include the issue text and relevant comments.
4. Offer a numbered work queue. Listing alone does not begin issue work.
5. If a local snapshot is needed, keep it in
   `{ModName}/_AI/Notes/Issues/` (ignored by Git), never the mod root.

GitHub CLI example, read-only. Set the verified full repo name first:

```powershell
$repo = 'KingdomIncModding/GlobalLedger'
gh api --paginate "repos/$repo/issues?state=all&per_page=100" --jq '.[] | select(.pull_request == null) | {number, title, state, html_url, labels}'
```

`gh issue list --repo $repo --state all --limit 1000` is convenient
for smaller repositories, but is not guaranteed to retrieve more than
its specified limit. The `gh api --paginate` example gets every page.
An authenticated GitHub connector's issue search/list actions may be
used instead; keep results scoped to the mod's verified repository.

## Work through issues

- Do only the issue(s) the user selects or explicitly authorizes in
  bulk. A request to *list* issues is not a request to fix all of them.
- Read the issue and real source, reproduce/understand the problem as
  possible, and make the requested local code change.
- Summarize the result to the user, noting anything still unresolved.
- Apply the standing progress, verification, regression and completion
  workflow above to issues addressed by the authorized work. Do not label
  or assign without permission.
- At major milestones, suggest that the user approve a push; do not
  push or publish anything until approved.

## Writing public issue text

Write in everyday language, as if a player described a problem:
- Title: brief statement of the visible problem.
- What happens and what should happen.
- Simple steps to observe it when known.
- Relevant mod/game version if known.
- For fixes, what changed for the player, what was checked, the result,
  and any remaining work. A short checkbox list can make status visible.

Never include AI process notes, prompt transcripts, "AI tested",
internal audits, source-file inventories, build outputs, artifacts,
agent status updates, or other irrelevant developer jargon. Avoid
guessing the cause. The local-only template provides a simple Bug Report reference form.

## Local agent only

GitHub does not manage the mod's work queue. The user's local agent may
read/export issues when requested; it keeps work notes under the mod-local
`_AI/Notes/` directory. Do not install GitHub Actions, AI instruction
files, automated issue triage, or issue/feature bots in a repository.
