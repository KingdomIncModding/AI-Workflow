# GitHub Repository Conventions

## Public README is an exact Nexus description mirror

`{ModName}/README.md` and `{ModName}/Nexus/DESCRIPTION.md` MUST match
byte-for-byte. The Nexus description is the source for public mod copy.
The README and DESCRIPTION MUST include a short `## Compatibility` section,
containing the actual three-column table from `Nexus/COMPATIBILITY.md` when
hooks are present. Keep it player-facing and identical in both copies.
Never add a GitHub-only heading, badges, build notes, status reports,
repository management notes, installation tests, or AI terminology to
README. Never add those items to the Nexus description either.

After editing the public description, update the README with an exact
copy from the mod repository root (Windows PowerShell):

```powershell
Copy-Item -LiteralPath 'Nexus/DESCRIPTION.md' -Destination 'README.md' -Force
```

To check that they are identical:

```powershell
(Get-FileHash -Algorithm SHA256 'README.md').Hash -eq
    (Get-FileHash -Algorithm SHA256 'Nexus/DESCRIPTION.md').Hash
```

If a change starts in README, apply it to `Nexus/DESCRIPTION.md`, then
copy back. Both may start blank in `_ModTemplate` and are filled only
when real player-facing content is known.

## Files committed to each mod repository

- Mod root: `mod.json`, `.gitignore`, `README.md`, project/solution files.
- `src/`: source code ONLY.
- `Assets/{category}/`: explicitly approved assets ONLY.
- `Nexus/`: player-facing files kept locally for Nexus updates; NOT uploaded.
- `.github/`: local-only reference forms if present; NEVER uploaded.
- Agent instruction files and AI tool configs: NEVER uploaded.
- `/_AI/`: private, never tracked, never uploaded.
- The root `.gitignore` IS committed to GitHub. Its required rules are:

```gitignore
/_AI/
/Nexus/
/.github/
/.agents/
/.claude/
/.codex/
/AGENTS.md
/CLAUDE.md
/GEMINI.md
/~tmp/
/AI_SETUP_PROMPT.md
```

The ignore rules do not remove files already committed to GitHub. When
replacing a repository, RepoReplace stages deletions for previously tracked
Nexus docs and all `.github/` files while preserving them locally.

## Local Git work and approval

- Inspect `git status` and `.gitignore` before staging files.
- Never stage mod-local `_AI/`, generated candidates, prompts, or
  temporary files. Review staged files for player-facing accuracy.
- Local commits are distinct from pushing. A push requires permission,
  including pushes that would publish Git tags or branches.
- Suggest a push after a substantial task/milestone; do not initiate it.
- Apply the standing issue workflow in `ISSUES.md` during authorized work:
  progress, plain-language fix/check results, immediate regression reports
  in the affected repo, and completed closure after verification.
- Keep issue/feature prose understandable to players. See `ISSUES.md`
  and `FEATURES.md` for the workflow and authorization scope.

## No GitHub-managed AI

Repository automation is deliberately not used. Do not commit `.github/`
(including Actions, issue templates, workflows, or Copilot instructions),
AGENTS.md, CLAUDE.md, GEMINI.md, or local agent configuration directories.
Issue lists remain readable through the GitHub API when the user requests
that work, but all planning, triage, and implementation are driven by the
user's LOCAL agent. The standing issue workflow in `ISSUES.md` is authorized;
unrelated issue activity and label/assignment changes remain separate.
