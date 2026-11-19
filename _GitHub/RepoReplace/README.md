# RepoReplace - Existing Mod Migration and GitHub Replacement

This standalone tool is located in `_Mods/_AI/_GitHub/RepoReplace/`.
It is NOT a general `_Workflows/` action. It only works on an existing
`KingdomIncModding/{ModName}` GitHub repository.

## First drag: prepare the local mod (no push)

1. Drag an existing local mod folder onto `ReplaceRepo.cmd`.
2. The tool derives the repo from the folder name and checks that it exists.
3. Type `PREPARE` after verifying the repository displayed.
4. The tool adds missing new-format files without replacing any existing
   project files or source code. It creates or updates `mod.json`, the Nexus
   docs, `.gitignore`, LOCAL-ONLY issue reference forms, and needed directories.
5. Your existing README is backed up to `_AI/Notes/Legacy_README.md` and
   copied to `Nexus/DESCRIPTION.md` only if that description is blank.
   This is a draft: it still needs to be cleaned up and rewritten.
6. A temporary `AI_SETUP_PROMPT.md` appears in the mod root. Give it to your
   AI agent. A permanent copy is in `_AI/Prompts/RepositorySetup.md`.
7. The agent reads the mod code and your existing README, fills the new Nexus
   documents and metadata, and rewrites the public-facing README in the
   new format. The README and Nexus DESCRIPTION must be byte-identical,
   and both must include the exact player-facing compatibility table from
   `Nexus/COMPATIBILITY.md` (or a brief no-hooks note).
8. When complete, the agent removes the temporary root prompt.

The temporary root prompt is a one-time exception requested for migration.
It is explicitly ignored by Git. All permanent AI documents remain in the
mod-local `_AI/` directory and NEVER appear on GitHub.

## Second drag: replace the existing repository

1. Drag the mod folder onto the same CMD again.
2. The tool refuses to proceed while `AI_SETUP_PROMPT.md` still exists.
3. It checks that `src/` is nonempty, all required docs have content, the
   repository URL is correct, and README exactly matches DESCRIPTION.
4. Review the repository and type `REPLACE` to explicitly authorize the
   commit and push. Any other response cancels.
5. The tool clones the default branch into `{ModName}/~tmp/`, removes its
   old files while preserving Git history, copies the new local mod files,
   stages them, and checks that `Nexus/`, the entire `.github/` directory,
   `_AI/`, and temporary/build files are NOT uploaded.
6. It commits and pushes to the existing default branch without force-push.
   On success it cleans up `~tmp/`. On failure it leaves the checkout for
   manual inspection. It never deletes your local mod source.

Subsequent drags use the upload step directly; the local migration marker is
in `_AI/Notes/RepoReplace_Initialized.flag`.

## Safety and conventions

- Windows PowerShell 5.1 and Git for Windows with an authenticated account
  that has push permission are required.
- The CMD requires `PREPARE` before it changes local files and `REPLACE`
  before it commits/pushes anything. There is no unattended push.
- The derived repository name is `{ModName}`, under `KingdomIncModding`.
- A local folder starting with `KingdomInc_` maps to its unprefixed name;
  for example, `KingdomInc_VortexExt` maps to `KingdomIncModding/VortexExt`.
- `mod.json` must never point at a different repository.
- All `.cs`, `.fs`, etc. source files belong under `src/`; solution and
  project files stay in the mod root. No source is automatically moved.
- `Assets/` holds approved mod assets only. AI candidate images and prompts
  belong under `_AI/Gen/Assets/` and `_AI/Prompts/`.
- Existing nonempty Nexus docs, README, project files, and code are preserved
  during migration. The AI updates text after inspecting the actual mod.
- `_AI/`, `Nexus/`, all `.github/`, `.agents/`, `.claude/`, `.codex/`,
  AGENTS.md, CLAUDE.md, GEMINI.md, `~tmp/`, `.git/`,
  `bin/`, `obj/`, common secrets, and the temporary prompt are excluded.
- The root `.gitignore` MUST be included in the GitHub repository; it is
  the file that tells Git which local paths to ignore.
- Remote files absent from the local mod WILL BE REMOVED by the replacement
  commit. Git history is not rewritten and there is no force-push.
- The tool does not create or alter GitHub issues, feature requests, tags,
  releases, or Nexus pages.
- User-facing README and Nexus DESCRIPTION must not contain developer or AI
  verification information.

RepoReplace uses ONLY `_Mods/_AI/_Workflows/_ModTemplate/` for mod
metadata, documentation, `.gitignore`, and GitHub issue templates.
There is NO `RepoReplace/Template/` directory and NO fallback copy.
Update the shared `_ModTemplate` once; both live PREPARE and offline MOCK
read that same source. The shared template is never modified by this tool.

Required template files are checked before PREPARE writes to the mod.
Missing required files produce a clear error with the expected path.
The LOCAL issue reference forms are optional and are NEVER sent to GitHub. PREPARE enumerates the actual files under
`_ModTemplate/.github/ISSUE_TEMPLATE/`, accepts `.yml`, `.yaml`, and `.md`,
and copies every file not already present in the mod. It does not assume
specific names such as `bug_report.yml` and never overwrites existing forms.
It reports the exact source directory and each installed/preserved filename.
If the directory is empty or missing, a diagnostic warning identifies it.
There are no fallback templates or duplicate copies in RepoReplace.

## Offline mock test (recommended before live PREPARE or REPLACE)

Drag a local mod folder onto `MockRepoReplace.cmd`, then type `MOCK`.

- The mock never connects to GitHub and never writes to the original mod.
- It copies your mod to a unique folder under the Windows TEMP directory.
- It creates a local bare Git repository with an old file to simulate your
  existing GitHub repository.
- It runs the SAME `ReplaceRepo.ps1` PREPARE and REPLACE implementation against
  the isolated mod and the local-only repository.
- No AI is run: fake content is inserted in the temporary copy solely to
  exercise the upload checks. Your real documents still need to be completed.
- It checks that old repository files disappeared, replacement files appear,
  and no `_AI/`, `~tmp/`, prompt, or build folders were committed.
- It writes `REPORT.txt` and shows the location of the test folder.
- The fake commit and fake push go ONLY to the LOCAL bare test repository.

Once the mock passes, drag the real mod onto `ReplaceRepo.cmd` and follow the
normal PREPARE process. The live tool still requires typed confirmation before
any remote push. The mock's pass does not authorize a live GitHub operation.

### Missing template files

The tool never maintains duplicate templates. If a required document or
`mod.json` is absent from `_Mods/_AI/_Workflows/_ModTemplate/`, PREPARE
stops before modifying the dragged mod and displays the expected path.

PREPARE copies the actual `.yml`, `.yaml`, and `.md` files found under the
shared `_ModTemplate/.github/ISSUE_TEMPLATE/` directory; it never depends
on two hardcoded template names. Existing mod-specific forms are preserved.
The offline mock verifies the discovered forms are copied to its temporary
mod but are excluded from its local-only simulated Git repository.

If no forms are found, check the printed absolute shared directory path.
Use this PowerShell diagnostic without changing anything:

```powershell
Get-ChildItem -LiteralPath '<KingdomIncDir>\_Mods\_AI\_Workflows\_ModTemplate\.github\ISSUE_TEMPLATE' -Force | Select-Object Name, FullName
```

## Repair an already-prepared mod (v4 issue template warning)

If an earlier version already created `AI_SETUP_PROMPT.md` and the initialized
marker, drag the mod onto `ReplaceRepo.cmd` again. When it says the migration
is pending, type `REPAIR` to copy missing issue forms locally. The script
lists each file it installs or preserves; no GitHub push occurs in REPAIR.

If migration is already complete and the one-time prompt has been removed,
missing shared issue forms will be copied only after you explicitly confirm
`REPLACE`. The tool never changes remote repositories without that prompt.

## Pager behavior

RepoReplace disables Git's interactive pager. The staged change summary prints directly in the CMD window without a `:` prompt or `(END)` screen. The existing `REPLACE` confirmation still authorizes both commit and push.

If you are stuck in an older running copy at `(END)`, pressing `q` exits the pager and lets that run CONTINUE to commit and push. Press Ctrl+C instead if you intend to abort before a push, then inspect GitHub to confirm its state.

## Absolute GitHub content boundary

GitHub receives source, project/solution files, approved assets, `mod.json`,
`.gitignore`, and the player-facing README. It does NOT receive prompts,
AI instructions, agent configs, Nexus drafts, GitHub Actions, issue forms,
or any `.github/` files. GitHub issues and features are read only on the
user's instruction and are never automatically updated. The user's local
agent handles all development workflow, issue triage, and feature planning.
