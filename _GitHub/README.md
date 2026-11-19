# GitHub Workspace Workflow

All Kingdom Inc. mod repositories belong to the GitHub organization `KingdomIncModding`.
Repository names use `{ModName}`, e.g.
`https://github.com/KingdomIncModding/GlobalLedger`.
This is a naming convention, NOT evidence that a given repository exists.

## Read these files

- `REPOSITORIES.md`: naming, local vs. remote setup, and `mod.json`.
- Ownership migrations: update each mod's ignored repository workflow first,
  then shared workflows and tools; follow `REPOSITORIES.md` before transfer.
- `CONVENTIONS.md`: README synchronization, Git rules, clean repository content.
- `TAGS.md`: version tags, repository topics, and issue labels.
- `ISSUES.md`: read/export all issues, triage and user-approved issue changes.
- `FEATURES.md`: user-approved feature work and feature requests.

## Absolute rules

- Never run `git push`, `git push --tags`, publish a release, create or
  update a remote repository, or change GitHub settings without the user's
  explicit approval for that operation. Local work is not approval to push.
- Recommend a push at the end of a substantial task or milestone, but wait
  for the user to authorize it. Never quietly push before moving on.
- Apply the user's standing issue workflow from `ISSUES.md`: mark addressed
  issues with plain-language progress and actual checks, report immediately
  observed regressions in the affected mod's repo, and close verified completed
  issues as completed. No separate confirmation is needed within that scope.
- Unrelated issue writes, labels and assignments still require authorization.
- NEVER create a feature request, add a new feature to the code, or put
  feature work on GitHub unless the user explicitly requests it.
- GitHub issue text must describe the problem in ordinary language.
  Include concise player-relevant checks and results, not AI process reports,
  build artifacts or agent jargon.
- `{ModName}/README.md` MUST contain exactly the same bytes as
  `{ModName}/Nexus/DESCRIPTION.md`. Include the concise compatibility
  table from `Nexus/COMPATIBILITY.md` in DESCRIPTION first, then copy
  DESCRIPTION to README. Never append to README alone.
  Both are public, player-facing documents; no internal development text.
- Keep `/_AI/`, `/Nexus/`, and the ENTIRE `/.github/` ignored by
  the mod-root `.gitignore`, which itself MUST be committed to GitHub.
  Source goes in `src/`; project/solution files stay in the mod root;
  approved assets go in `Assets/{category}/`.

## Basic sequence

1. Read `_AI/AGENTS.md`, these GitHub docs, and `{ModName}/mod.json`.
2. For a new mod, initialize using `_AI/_Workflows/NEWMOD.md`.
3. Calculate the proposed `{ModName}` repository name and
   verify the actual remote exists before recording a live URL or branch.
4. Ensure `README.md` exactly matches `Nexus/DESCRIPTION.md`.
5. Work locally. You may read/triage existing issues if requested.
6. Maintain addressed issues under `ISSUES.md`. Suggest pushing after a
   significant milestone; wait for approval before pushes, tags or publication.

## Local agent owns all automation

GitHub is a code host, not the mod's AI agent or task manager. Never upload
AGENTS.md, prompts, agent settings, generated working media, AI planning,
`.github/` workflows/templates/actions, or any other AI automation file.
The local agent reads issues and features only when the user asks. A local
agent action does not require a GitHub issue or feature request. No GitHub
Actions, bots, Copilot instruction files, or GitHub-managed AI setup.
