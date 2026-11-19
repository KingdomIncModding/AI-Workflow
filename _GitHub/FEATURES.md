# Features - User-Directed Only

## Rules

- A feature may be suggested for the user's consideration, but agents
  must NEVER begin implementing, adding, or publishing new features
  unless the user explicitly requests that feature work.
- New feature requests and implementation require direct authorization.
  Updates to an existing feature issue addressed by authorized work follow
  the standing progress, verification and completion workflow in `ISSUES.md`.
- An existing `enhancement` issue is NOT automatic approval to implement
  the feature. Reading that issue is allowed when requested.
- Do not turn a discovered idea or bug into a new feature without the
  user choosing it. A bug fix must not quietly introduce new behavior.
- No feature release, tag push, repo push, or unrelated GitHub write is
  authorized merely because the implementation is done locally. Issue
  maintenance within the standing `ISSUES.md` workflow is authorized.

## When the user requests feature work

1. Read the mod's `mod.json`, actual source, and the feature request.
2. If the user references a GitHub issue, read that existing issue.
3. Implement only what the user requested, using the mod's actual
   code and requirements. Keep private plans/notes in
   `{ModName}/_AI/Notes/Features/`.
4. If requested, prepare player-facing feature text in the Nexus
   description/changelog and mirror README from DESCRIPTION exactly.
5. Report the local outcome. Suggest pushing after a substantial
   milestone, but WAIT for approval.
6. Mark progress, explain the change and actual checks in plain language,
   and close the addressed feature issue as completed when its requested
   behavior is finished and verified. Leave partial work open. See `ISSUES.md`.

## Public feature request language (ONLY when authorized)

- Name the change in plain words.
- Explain what players would be able to do and why it is useful.
- Include a clear example of the requested experience if helpful.
- Do not add AI verification, architecture analysis, build results,
  internal planning notes, or development artifact links.

`_ModTemplate/.github/ISSUE_TEMPLATE/feature_request.yml` is an
local-only reference form. It is not uploaded to GitHub and does not
authorize the local agent to submit issues or implement features.
