# Kingdom Inc. Mod Workspace - Agent Instructions

This file is the **starting point for AI agents** working in the Kingdom Inc. `_Mods` workspace. Read it before creating, changing, building, or publishing a mod. Keep it current whenever the workspace layout or a documented workflow changes.

## 1. Workspace layout

All paths below are relative to `_Mods/`.

Game-level reference material is under `../_Tools/`: `ModdingDocs/` (modding reference), `Wiki/` (offline wiki and decompiled source), and `Screenshots/` (relocated screenshot collection).

Game-update migration records, backups and verification outputs belong under the game root's `../_ModUpdates/{ModName}/`, as requested by the user. The game root's `../_SrcExtraction/` is strictly read-only: never create, edit, delete, or run output-producing tools inside it. Public SDK migration guidance stays with the SDK documentation.

```text
_Mods/
+-- _AI/
|   +-- AGENTS.md                       <- This file: workspace entry point
|   +-- _GitHub/
|   |   +-- README.md
|   |   +-- REPOSITORIES.md
|   |   +-- CONVENTIONS.md
|   |   +-- TAGS.md
|   |   +-- ISSUES.md
|   |   +-- FEATURES.md
|   |   +-- RepoReplace/                 <- Standalone existing-repo migration tool
|   |       +-- ReplaceRepo.cmd
|   |       +-- ReplaceRepo.ps1
|   |       +-- MockRepoReplace.cmd
|   |       +-- MockRepoReplace.ps1
|   |       +-- README.md
|   +-- _Nexus/
|   |   +-- README.md
|   |   +-- MOD_DESCRIPTIONS.md
|   |   +-- PUBLISHING.md
|   +-- _Workflows/
|   |   +-- README.md
|   |   +-- NEWMOD.md
|   |   +-- BUILD.md
|   |   +-- CLEAN.md
|   |   +-- RELEASE.md
|   |   +-- Tools/BuildMod/              <- Self-contained build & publish PowerShell package
|   |   |   +-- PublishMod.ps1           <- Single-command mod build/release/sync orchestrator
|   |   |   +-- BuildMod.cmd
|   |   |   +-- BuildMod.ps1
|   |   |   +-- NexusFormat.ps1          <- README sync, BBCode generator/validator, changelog parser
|   |   |   +-- PublishGithub.ps1        <- GitHub Release publisher & verifier
|   |   |   +-- PublishNexus.ps1         <- Nexus v3 file upload, page PATCH, changelog & dependency sync
|   |   +-- Tools/SourceLayout/          <- Required C# layout check; invoked before builds
|   |   +-- _ModTemplate/
|   |       +-- mod.json
|   +-- _shared/
|       +-- README.md
|       +-- WORKSPACE.md
|       +-- CODING_STANDARDS.md
|       +-- MODDING_GUIDELINES.md
|       +-- ThumbnailGen/
|           +-- README.md
|           +-- PROMPT.md
|           +-- thumbnail-master.png
+-- _Archived/
|   +-- {ModName}/{Version}/             <- Entire archived mod source/project directory
|   +-- Originals/                      <- Moved original project collection
|   +-- Unmanaged/                      <- Moved unmanaged project collection
+-- {ModName}/
    +-- mod.json                         <- Identity and publishing destinations
    +-- README.md                        <- Exact copy of Nexus/DESCRIPTION.md
    +-- .github/ISSUE_TEMPLATE/           <- LOCAL issue/feature references (ignored)
    +-- .gitignore                       <- Must ignore /_AI/
    +-- {ModName}.csproj                 <- Project file, when applicable
    +-- {ModName}.slnx                   <- Solution file, when applicable
    +-- src/                             <- Source code ONLY
    |   +-- ...
    +-- Assets/                          <- APPROVED mod artwork/images/assets
    |   +-- {category}/                  <- Only finalized, approved assets
    +-- Nexus/                           <- Public, player-facing Nexus page text
    |   +-- DESCRIPTION.md              <- Mod description (no development content)
    |   +-- DESCRIPTION.bbcode.txt      <- Generated/validated Nexus BBCode with [color=#...]
    |   +-- CHANGELOG.md                <- Player-visible release changes
    |   +-- PREREQUISITES.md             <- Player installation requirements
    |   +-- COMPATIBILITY.md            <- Class.Method, Hook Type, Impact
    +-- _AI/                             <- Mod-local AI material (GITIGNORED)
        +-- Gen/
        |   +-- Assets/
        |       +-- {category}/          <- AI-generated asset work and prompts
        +-- Prompts/                     <- General AI prompts and context
        +-- Media/                       <- Development-only reference media
        +-- Notes/                       <- AI-only analysis and working notes
        +-- Scratch/                     <- Temporary experiments/intermediates
```

`_AI/` holds **instructions and reusable workflow documentation**, not mod source, repository checkouts, generated binaries, or release packages. Each mod has its own directory directly under `_Mods/`.

`Unstacker/` is a Foundation consumer: Ctrl+Shift+left-click removes one building stack level and refunds its current building price. Its project/solution files are at the mod root, source is in `src/`, and local verification material is under `_AI/`.

`PipeWrench/` is a local-only Foundation consumer. New pipes default to right-angle routing. Connections remain selected until clicking away from their grabbers; P cycles Center/Near Start/Near End/Freeform before and after connection; = / − adjust requested bends in pairs from 2 to 12; Tap Shift cycles Buildings, Overlap (crossings allowed), Both (crossings allowed), and Strict (no crossings). A four-button toolbar appears on the first frame of a pipe connection beneath the mod bar, stays visible after connecting until clicking away, and renders the user's embedded Assets/UI/PipeWrenchToolbar.kingdom-ui.json export using the Foundation JSON parser. Alt+P activates a section-based Grab Inserter for vanilla or tool-laid pipes, including bent connections, port-side runs and diagonal sections; right-click removes markers. Slider ownership/removals are strictly in-memory per loaded kingdom/session, with no config/save serialization. Native preview primitives and drag hooks use the local Foundation 0.14.2 pipe-drag/HUD-anchor extension; behavior stays in Pipe Wrench. The root verification project tests routing, edit/session state, visibility and the actual toolbar parser; production excludes `src/Verification/`. `Tools/Build-Local.ps1` stages and optionally installs both required DLLs and removes legacy config marker identities. `PipeWrench/Tools/Verify-Runtime.ps1` builds the isolated Foundation/src/Verification helper, checks the toolbar lifecycle inside the game using temporary saves, restores config, and removes the helper afterward; it requires the game closed.

`Undo/` adds Ctrl+Z Undo and Ctrl+Shift+Z Redo for factory edits, including grouped moves/deletes and optional Better Deconstruct batch deletion. Source and isolated verification source are in `src/`; project/solution files are at the mod root. Generated diagnostics and verification results stay under `Undo/_AI/`.

`GlobalLedgerV2/` is the separate Cleaner, Crisper HD edition of Global Ledger. The user authorized public publication on 2026-11-13, superseding the earlier local-only prototype scope. Its own GitHub repository and release are separate from Global Ledger. Its Nexus download belongs on the existing Global Ledger page (19) as a separate optional file; preserve the original primary file, every existing version and original page content. Use explicit new-file selection and disable primary-download and page-version replacement. It uses Foundation 0.14.2+, batched accounting and cached locations. Verification source is excluded from the production project. See its `Docs/` and ignored `_AI/Prompts/RepositoryWorkflow.md`.

Global Ledger HD 0.2.1+ takes runtime priority over the original edition: it unloads the original plugin component and its registrations without deleting installed files or settings. Subsequent HD releases update the configured optional file group, preserving the original primary download and page version.

`GlobalLedger/` 0.1.13 locally brings V2 accounting/cache and table controls into the original pixel edition. Its identity and native font/frames remain separate from HD. `Tools/Build-Local.ps1` explicitly builds/packages V1 without installation or publication. `GlobalLedger.Verification.csproj` and `Tools/Verification/Run-Verification.ps1` provide isolated synthetic integration/render checks; `src/Verification/` is excluded from production. See `GlobalLedger/_AI/Notes/V1-0.1.13-LocalTesting.md`. Do not include HD in a V1 test runtime, because HD unloads V1.

Global Ledger V1 0.1.14 local feedback revision restores net-only Basic, uses a viewport-sized row pool, separates rate units from history, sorts only expanded sources, and keeps search/filtering outside Settings. Natural-width numeric spacing and native coin icons remain at pixel scale. See `GlobalLedger/_AI/Notes/V1-0.1.14-Feedback.md` for local test evidence and scope; publication remains separate.

The other Markdown documents are currently placeholders unless they have subsequently been filled in. **An empty file is not an implemented process.** Do not assume an automation, policy, command, or publishing integration exists just because its documentation filename exists.

## 2. Where to look first

1. Read `_AI/AGENTS.md` (this file).
2. Identify the mod and read `{ModName}/mod.json` before any mod-specific or external action.
3. Read only the task-relevant documentation in `_AI/`:
   - **New mod:** `_Workflows/NEWMOD.md`; template in `_Workflows/_ModTemplate/`. Generate the standard thumbnail during creation, keep only the image in Gen, show it and ask explicitly for image approval; move it to approved assets only after approval.
   - **Build:** `_Workflows/BUILD.md` and local `_Workflows/Tools/BuildMod/BuildMod.cmd` (drag the mod root).
   - **Clean:** `_Workflows/CLEAN.md`.
   - **Archive:** `_Workflows/ARCHIVE.md`; move the entire selected mod into `_Archived/{ModName}/{Version}/` using its declared version. Performance, AsyncSave, DiagnosticProfiler, FastSaveHash, and KingdomInc_VortexExt are archived there. Originals and Unmanaged are directly under `_Archived/`.
   - **Release & Publish:** `_Workflows/RELEASE.md` and the PowerShell script package in `_Workflows/Tools/BuildMod/` (`PublishMod.ps1`, `BuildMod.ps1`, `NexusFormat.ps1`, `PublishGithub.ps1`, `PublishNexus.ps1`). **Never read `_AI/Notes/nexus_v3_openapi.yaml` or inspect other mods when publishing a mod.**
   - **GitHub:** `_GitHub/README.md`, `REPOSITORIES.md`, `CONVENTIONS.md`, `TAGS.md`, `ISSUES.md`, and `FEATURES.md`.
   - **Existing local mod migration and repository replacement (standalone):** `_GitHub/RepoReplace/README.md`. This utility uses ONLY `_Workflows/_ModTemplate/` as its template. Mock uses a local test repository; live operations require explicit confirmation.
   - **Nexus Mods:** `_Nexus/MOD_DESCRIPTIONS.md` for public page text rules and `_Nexus/PUBLISHING.md` for the PowerShell publishing package (`PublishMod.ps1` / `PublishNexus.ps1`). Read both before any Nexus action; `_Nexus/README.md` may be a placeholder.
   - **Nexus thumbnail generation (required during new-mod creation):** `_shared/ThumbnailGen/README.md`, then `_shared/ThumbnailGen/PROMPT.md`; use its unchanged `thumbnail-master.png` as the reference image. The top banner text is `KINGDOM .INC`.
   - **General workspace/mod coding:** `_shared/WORKSPACE.md`, `CODING_STANDARDS.md`, `MODDING_GUIDELINES.md`. One class per file, with all its methods together; each method performs one job. Preserve responsibility folders and keep patch/helper classes in complete files there. Extract real helpers when a class spans folders; do not flatten the tree or split a class into method-per-file partials. Run `_Workflows/Tools/SourceLayout/Check-SourceLayout.ps1 -ModFolder <mod-root>`; the build workflow also enforces this check. See `CODING_STANDARDS.md` for details.
4. For code changes, inspect the mod's root project/solution files and relevant `src/` files. Use the actual code and SDK rather than assuming undocumented APIs exist.

If a referenced document is blank, use only established workspace rules and the user's current instructions; do **not** invent missing workflow steps.

## 3. Mandatory mod layout

Foundation owns native game integration (calls, fields, reflection and hook targets), while mods own their feature behavior. See `_shared/MODDING_GUIDELINES.md` and `Foundation/Docs/Framework-Boundary.md`. Use the boundary audit for migrated consumers; do not move whole mod processes into Foundation.

Every mod is organized as `_Mods/{ModName}/`.

- `{ModName}/README.md`: exact byte-for-byte mirror of `{ModName}/Nexus/DESCRIPTION.md`; both include the same player-facing `## Compatibility` section with confirmed `Class.Method | Hook Type | Impact` table when hooks exist. Do not add GitHub-specific or developer information.
- `{ModName}/.github/ISSUE_TEMPLATE/`: local issue and feature suggestion forms. They are **Git-ignored**, not published to GitHub. Their presence does NOT authorize posting issues.
- `{ModName}/mod.json`: mod identity and connections to its GitHub repository and manually created Nexus page. Store confirmed Nexus requirements in `distribution.nexus.requirements`; set `requirementsVerified` true ONLY after all required Nexus mods are linked in the live page's Requirements section; set the desired Nexus tags in `distribution.nexus.tags` (including `AI-Generated Content`); mark `tagsVerified` true ONLY after confirming the live page has those tags. Do not guess dependencies, URLs, or tag status.
- `{ModName}/*.csproj`: project file(s) at the **mod root**, never in `src/`.
- `{ModName}/*.sln` or `*.slnx`: solution file(s) at the **mod root**, never in `src/`.
- `{ModName}/src/`: **source files only**, plus folders organizing those source files. Do not put project/solution files, release archives, AI working files, or build output here.
- `{ModName}/Assets/{category}/`: **all approved/finalized mod artwork, images, and other assets** intended for the mod itself. Keep categories aligned with the mod's actual needs. Only approved deliverables belong here; no prompts, candidate generations, AI logs, scratch files, or other development-only artifacts.
- **Nexus thumbnail exception:** Reference the shared master in place without copying it. After successful generation, move only the image into `{ModName}/_AI/Gen/Assets/Thumbnails/` and remove temporary per-image data. Leave only the image there: no copied references, hashes, saved per-image prompts, generation records or other sidecars. Show it and ask explicitly for approval. Only after image approval, move it into `{ModName}/Assets/Thumbnails/`, leaving no duplicate in Gen. A general publishing instruction is not thumbnail approval. These rules override general generation-material preservation requirements. See `_AI/_shared/ThumbnailGen/README.md` and `PROMPT.md`.
- `{ModName}/Nexus/`: mod-specific, **player-facing** Nexus page text only. The required files are `DESCRIPTION.md`, `CHANGELOG.md`, `PREREQUISITES.md`, and `COMPATIBILITY.md`. Keep these files locally and use them for authorized Nexus publishing, but **Git-ignore the entire `/Nexus/` directory**. Their template copies begin empty. See `_AI/_Nexus/MOD_DESCRIPTIONS.md` for mandatory content restrictions.
- `{ModName}/_AI/Gen/Assets/{category}/`: AI-generated asset work for that category, including generation-specific prompts, source/reference material used for generation, drafts, variants, previews, intermediate outputs, and rejected/unapproved results. This location is Git-ignored. Thumbnails are the explicit exception above: retain only the generated image after success.
- `{ModName}/_AI/`: **exclusive location for other mod-specific AI working material**, including general prompts, generated reference media, AI notes, drafts, and experiments. Create further category folders there as needed.
- `{ModName}/.gitignore`: **must be committed to GitHub** and include `/_AI/`, `/Nexus/`, `/.github/`, `/~tmp/`, `/Release/`, `/Debug/`, and `/AI_SETUP_PROMPT.md`.
- Keep mod-specific work inside that mod's directory; do not put actual source under `_AI/`. The workspace-wide `_Mods/_AI/` contains shared instructions, not per-mod working material.

This layout applies to Foundation as well as other mods. Do not move existing project files into `src/` just to match another repository convention.

## Nexus new-mod publishing gate

1. The USER creates the Nexus mod page manually and provides its exact URL. Never create a Nexus mod page for the user or invent a URL or mod ID.
2. Read and verify that URL, the target game, the page identity, and the authenticated account's permission to edit it. Record the verified game-scoped mod ID and URL in `{ModName}/mod.json`; resolve the API's internal mod ID when required.
3. Read all four `{ModName}/Nexus/` files. `DESCRIPTION.md` is player-facing only; `PREREQUISITES.md` identifies confirmed player requirements and linked required Nexus mods; `COMPATIBILITY.md` uses `Class.Method | Hook Type | Impact`; `CHANGELOG.md` holds release changes. Never publish invented or empty placeholders.
4. Link required Nexus mods as actual entries in the Nexus Requirements section, using a supported API if available for the correct requirement mode, or asking the user to add the exact verified links on the website. Mentioning a required mod only in DESCRIPTION does NOT satisfy this requirement. Confirm the live list before setting `requirementsVerified` to true; otherwise report requirements pending.
5. Build the on-page description from `DESCRIPTION.md` (which already includes the public Compatibility section) and the separate Prerequisites content if not already present. Do not duplicate Compatibility; send the current version's Changelog through the supported changelog API when appropriate. Preserve already existing hand-edited page content and embedded media links. Never publish AI validation, build info, artifact paths, or other development text.
6. Required Nexus tag: `AI-Generated Content`. Select additional accurate tags for the mod, including `AI Media` if its public page text or promotional media is AI-generated. Observe Nexus's current disclosure rules. The documented API currently does not establish a supported mod-tag update operation: if automated tags are unavailable, instruct the USER to select tags in the Nexus page editor, then verify them. **Do not report Nexus setup complete while mandatory tags remain unverified.**
7. The official API supports editing an existing page's summary/description and appending a version changelog; this does not imply API support for gallery uploads, tag changes, creating pages, or every kind of requirement management. Never guess or fake an endpoint. See `_AI/_Nexus/PUBLISHING.md` for the precise sequence.

## 4. Non-negotiable AI file placement and Git privacy

**NEVER, NEVER, NEVER place mod-specific AI prompts, generated AI media, agent context, scratch documentation, development analysis, or temporary outputs directly in `_Mods/` or at `{ModName}/` root.** Do not put them in `{ModName}/src/` either. All AI-only material for one mod goes under **`_Mods/{ModName}/_AI/`**, categorized by purpose:

- `Prompts/`: prompts, instruction drafts, agent conversations, and prompt-oriented Markdown.
- `Gen/Assets/{category}/`: AI asset-generation prompts, inputs, generated images/artwork/media, source files, variations, previews, and intermediates, grouped by the intended asset category. Save generated asset work here first; never save it directly into the approved `Assets/` tree. For thumbnails, move only the successful image into `Gen/Assets/Thumbnails/` and remove per-image temporary data; do not copy references or retain sidecars.
- `Media/`: non-shipping development reference media unrelated to a specific generated asset (asset-generation material goes to `Gen/Assets/{category}/`).
- `Notes/`: AI-only technical analysis, exploration, planning, investigation, and draft documentation.
- `Scratch/`: experiments, intermediate outputs, and temporary AI work.

Create other categories **inside `{ModName}/_AI/`** when necessary; never add miscellaneous AI files to the mod root simply because they do not fit a category. If an AI tool would otherwise write to the current working directory, redirect its output to the appropriate subfolder first. **Do not commit or publish mod-local `_AI/` content.**

Each mod's **root-level `.gitignore`** must be committed to GitHub and include these root-anchored rules:

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

These rules apply to each individual mod repository. **Do not ignore the workspace-wide `_Mods/_AI/` instructions**, which are separate and intentionally maintained. `gitignore` does not stop tracking files already committed; if mod-local `_AI/` content was previously tracked, untrack it with `git rm -r --cached -- _AI` from that repository root (after reviewing the change). This does not remove local files, but the removal from Git must be deliberate. Never delete the user's AI working data to enforce the rule.

**Strict asset boundary:** `{ModName}/Assets/{category}/` is for **approved mod assets only** and may be tracked in Git. Never put AI prompts, prompt metadata, in-progress generations, rejected versions, source experiments, scratch notes, or development-only reference images in `Assets/`. For image/artwork/asset generation, create files under `{ModName}/_AI/Gen/Assets/{category}/` first. **Only after the user explicitly approves a final asset** may an agent copy the approved deliverable into `{ModName}/Assets/{category}/` (preserving the generation material under `_AI/`); never automatically promote drafts. Do not gitignore the approved `Assets/` directory as part of the AI privacy rule. The existing `/_AI/` ignore covers generation work.

**Thumbnail handling overrides the general copying/preservation rule:** reference the shared master in place; after successful generation keep only the image in `_AI/Gen/Assets/Thumbnails/`; show it and ask explicitly for approval; after approval move that image into `Assets/Thumbnails/`. Do not retain thumbnail hashes, per-image prompts, copied references, generation records or other sidecars. Keep the shared master and shared prompt intact during cleanup.

**Non-negotiable Nexus description rule:** `{ModName}/Nexus/DESCRIPTION.md` is exclusively for players. NEVER include AI verification, validation or audit results, build commands or build status, compiled artifacts or artifact paths, development notes, test output, prompt details, internal implementation checklists, or other developer-facing content. `CHANGELOG.md` records player-visible changes; `PREREQUISITES.md` records only real player-facing dependencies and installation requirements and identifies every required Nexus mod to link in the live Requirements section. `COMPATIBILITY.md` is a concise, three-column table: `Class.Method`, `Hook Type`, and `Impact` (brief behavioral effect and relevant compatibility concern). Derive each hook from actual source; never guess targets or claim physical edits to game files. Keep all AI-only working material under the mod-local ignored `_AI/`. See `_AI/_Nexus/MOD_DESCRIPTIONS.md` before writing any Nexus page content.

**Distinguish AI working files from real project deliverables.** `{ModName}/mod.json`, `.gitignore`, root `.csproj`/`.slnx`, and intentionally public `README.md`/release documentation may live in their normal repository locations. Actual mod source belongs in `src/`; finalized approved artwork/images/assets belong in `Assets/{category}/`. An AI-generated reference image or prompt draft is **not** a shipping asset just because it was created during development.

## 5. `mod.json` is the authoritative mod identity file

Before creating a remote repository, inspecting a mod's existing remote, preparing a release, or publishing to Nexus, read that mod's `mod.json`.

| Field | Meaning |
| --- | --- |
| `id`, `name`, `version`, `author`, `description` | Identity and current metadata |
| `repository.platform`, `repository.owner`, `repository.name`, `repository.url`, `repository.branch`, `repository.visibility` | Intended owner/name and verified GitHub destination (unverified URLs and branches stay `null`) |
| `repository.topics`, `repository.latestTag` | Intended GitHub topics and the last actually verified Git version tag (not authorization to publish) |
| `distribution.nexus.game`, `distribution.nexus.modId`, `distribution.nexus.url` | Nexus Mods game, page ID, and page URL |
| `development.framework`, `development.language`, `development.target`, `development.dependencies` | Development context and confirmed dependencies |
| `publishing.githubReleases`, `publishing.nexusMods` | Intended publishing targets |

Rules:

- Use **confirmed** values. Leave unknown fields `null`; never guess a URL, repository owner, branch, Nexus mod ID, version, or dependency.
- `null` means unknown/unset, not `false` and not authorization to create a remote destination.
- Update `mod.json` when a verified GitHub or Nexus destination changes.
- Never store passwords, tokens, or other credentials in `mod.json`.
- Keep the file valid JSON (no comments or trailing commas).
- A publishing flag or URL is **configuration, not permission** to publish. Require the user's instruction before remote creation, pushing, or release uploads.

## 6. Creating a new mod

Follow `_AI/_Workflows/NEWMOD.md` as the detailed procedure. In brief:

1. Copy `_AI/_Workflows/_ModTemplate/` to `_Mods/{ModName}/` without altering the original template, including its **root `.gitignore`**.
2. Make sure `{ModName}/README.md` starts blank to match blank `Nexus/DESCRIPTION.md`; copy the public Nexus description exactly when it is populated. Include LOCAL-ONLY `.github/ISSUE_TEMPLATE/` reference forms (never commit). Ensure `{ModName}/src/`, `{ModName}/Assets/`, `{ModName}/Nexus/` (with blank `DESCRIPTION.md`, `CHANGELOG.md`, `PREREQUISITES.md`, `COMPATIBILITY.md`), `{ModName}/_AI/Gen/Assets/`, and `{ModName}/_AI/{Prompts,Media,Notes,Scratch}/` exist. Create `{category}/` folders only as actual asset categories are needed.
3. Verify the new mod root `.gitignore` contains `/_AI/`; the copied mod-local `_AI/` must not be committed. Keep approved `Assets/` eligible for normal source control.
4. Fill in known fields in the new mod's `mod.json`; leave unknowns `null`.
5. When creating a C# project or solution, place `.csproj`, `.sln`, and `.slnx` files at the **mod root**; place `.cs` and other actual source files under `src/`. Follow the template's `_AI/Prompts/SourceLayout.md`: complete classes in responsibility folders, one job per method, no method-per-file partials. Run the source-layout checker before considering source creation complete.
6. Do not automatically create GitHub repos or Nexus pages during mod initialization.
7. As part of creation, reference the shared thumbnail master in place, generate the image and move only that image into `{ModName}/_AI/Gen/Assets/Thumbnails/`. Remove temporary per-image data after success. Show the image and ask explicitly for approval; after approval move it into `{ModName}/Assets/Thumbnails/`. Follow `_shared/ThumbnailGen/README.md` and `PROMPT.md`. A separate thumbnail request or Nexus page URL is not required.

If the template changes, update `NEWMOD.md` and this file's layout/rules at the same time.

## 7. Build, clean, and release work

- **Build:** use `_Workflows/BUILD.md` and the local drag-and-drop `_Workflows/Tools/BuildMod/BuildMod.cmd`. It builds root `.csproj` files and copies the main DLL and `mod.json` to the Git-ignored `/Release/` or `/Debug/` folder; installation requires a user menu choice and installs both the DLL and `mod.json` into `BepInEx/plugins/{ModName}/`.
- **Clean:** consult `_Workflows/CLEAN.md` when it contains instructions. Typical temporary directories are `bin/` and `obj/`, but inspect the specific operation before deleting anything else.
- **Foundation SDK:** after building/staging the runtime, `Foundation/Tools/Build/Package-FoundationSdk.ps1` packages the matching library, XML documentation, public guides and five verified examples. See `_Workflows/BUILD.md`; staging is private and cleaned automatically. SDK publication is separate from the runtime upload.
- **Framework release availability:** Foundation sets `publishing.archivePreviousReleases: false` in `mod.json`; the Nexus publisher honors this unless explicitly overridden. Preserve older runtime downloads because installed mods may still require them. See `_Nexus/PUBLISHING.md` before changing this policy.
- **Foundation Nexus updates:** read `Foundation/_AI/Prompts/Release-Preferences.md` before publishing Foundation. The user wants the current downloads replaced without changing the displayed version; preserve supported 0.11.0 downloads and keep the runtime/SDK synchronized. Publication still needs a user request.
- **Release:** consult `_Workflows/RELEASE.md` and use `_Workflows/Tools/BuildMod/PublishMod.ps1` (or `BuildMod.cmd`) for opt-in Release-only publishing to GitHub, Nexus, or both. **Never read `_AI/Notes/nexus_v3_openapi.yaml` or bleed into other mods' directories during a build or publish.** All Nexus v3 API calls, BBCode generation, changelog parsing, dependency linking, and GitHub release verification are built into `_Workflows/Tools/BuildMod/`.
- **GitHub:** read `_GitHub/README.md` and the task-specific GitHub guides. For existing mod migrations read `_GitHub/RepoReplace/README.md` (outside `_Workflows/`). Repositories follow `KingdomIncModding/{ModName}`, but verify each real remote before recording it in `mod.json`; do not treat a naming pattern as an existing remote. README is an exact copy of Nexus/DESCRIPTION. Apply the standing issue lifecycle in `_GitHub/ISSUES.md` during authorized work. Pushes, tags/releases and new feature implementation still require explicit authorization.
- **Nexus:** edit player-facing page text only in `{ModName}/Nexus/DESCRIPTION.md`, `CHANGELOG.md`, `PREREQUISITES.md`, and `COMPATIBILITY.md`, then run `_Workflows/Tools/BuildMod/NexusFormat.ps1 -ModFolder "_Mods\{ModName}"` to sync `README.md` and generate/validate `Nexus/DESCRIPTION.bbcode.txt`. Read `_Nexus/MOD_DESCRIPTIONS.md` first; use `mod.json` for the exact Nexus page. Publishing is a separate authorized step via `PublishMod.ps1` / `PublishNexus.ps1`.
- Do not report a build, upload, installation, or release as complete without having actually performed it.

## 8. Keep the documentation synchronized

**Treat `AGENTS.md` as a living index, not a one-time setup note.** Whenever work introduces or changes any of the following, update the affected documentation in the **same change**:

| Change made | Documentation to update |
| --- | --- |
| Workspace folder added, renamed, or moved | `_AI/AGENTS.md` and `_shared/WORKSPACE.md` if populated |
| New workflow added or workflow renamed | `_AI/AGENTS.md` routing section and `_Workflows/README.md` if populated |
| New mod template or initialization rules | `_Workflows/NEWMOD.md`, template contents, and relevant parts of `AGENTS.md` |
| Build / clean / release procedure changes | Matching `_Workflows/*.md`; update `AGENTS.md` only if the entry point or overall rule changes |
| GitHub or Nexus procedure changes | Matching platform `.md`; update `AGENTS.md` if routing or cross-platform rules change |
| GitHub issue/feature intake forms or README sync policy | `_GitHub/CONVENTIONS.md`, `ISSUES.md`, `FEATURES.md`, `_Workflows/_ModTemplate/.github/`, and `_Workflows/NEWMOD.md` |
| Nexus description, changelog, prerequisites, or compatibility content/layout changes | `_Nexus/MOD_DESCRIPTIONS.md`, `_Workflows/NEWMOD.md`, `_ModTemplate/Nexus/`, and affected `AGENTS.md` rules |
| Mod's repository, Nexus page, or metadata changes | **That mod's `mod.json`**; avoid duplicating the values in `AGENTS.md` |
| Shared coding or modding rules change | Matching `_shared/*.md`; update `AGENTS.md` if the required rule or reading order changes |
| Nexus thumbnail generator instructions or asset naming change | `_shared/ThumbnailGen/README.md`, `_shared/ThumbnailGen/PROMPT.md`, relevant template folders, and `AGENTS.md` routing |
| AI working-file categories, generated/approved asset placement, or ignore policy change | `_AI/AGENTS.md`, `_Workflows/NEWMOD.md`, and `_Workflows/_ModTemplate/` structure/`.gitignore` |

Keep `AGENTS.md` compact and navigational: link to the detailed file for a subject rather than copying the entire procedure into multiple places. Do not fill otherwise blank `.md` files unless the user requests their content or the relevant procedure is being established.

## 9. Agent completion expectations

When completing a workspace-related task, preserve existing files, report exactly what changed, and distinguish created files from proposed changes. If a change affects the workspace structure, mod metadata, or the way a workflow is invoked, update `AGENTS.md` and the directly affected instructions before considering the task finished.

## Required Nexus page synchronization rules

- `mod.json` is the source for the page URL, game-scoped Nexus mod ID, desired tags, and recorded requirements; the live Nexus page is the source for whether required-mod links, an API update, or tag selection actually succeeded.
- Do not treat desired `distribution.nexus.tags` as proof the live page contains those tags. `tagsVerified` is false until checked, and must be reset if tags change. Likewise, `requirementsVerified` stays false until all required Nexus mods are actually linked in the live Nexus Requirements section; reset after any requirement or page URL change.
- If no supported API route for a required field exists, mark that action as manual and report it clearly; never assert full publication while a required manual action is pending.
- Nexus page artwork is added by the user in the Nexus editor. Move a generated thumbnail from `_AI/Gen/Assets/Thumbnails/` into `Assets/Thumbnails/` only after explicit approval of that image. Never upload images through an undocumented API call.
- All publication staging notes, API errors, and temporary formatted payloads belong under `{ModName}/_AI/Notes/` or `{ModName}/_AI/Scratch/`, not the mod root or `Nexus/DESCRIPTION.md`.

## Required GitHub approval and issue policies

- Organization ownership migrations: update every affected mod's
  `_AI/Prompts/RepositoryWorkflow.md` and existing setup prompts first,
  then shared master workflows and tools. Follow
  `_GitHub/REPOSITORIES.md` for transfers, verification and link updates.
  The repository owner is `KingdomIncModding`; the personal login used to
  authenticate is not the repository owner.

- GitHub naming: `https://github.com/KingdomIncModding/{ModName}` is the prescribed pattern, not proof of a live repository. Verify before setting the real URL or branch in `mod.json`.
- `README.md` MUST match `Nexus/DESCRIPTION.md` byte-for-byte and must never contain internal AI/development information. See `_GitHub/CONVENTIONS.md`.
- Never push code, branches, tags, or releases until the user explicitly authorizes that push/publication. Suggest a push at major task boundaries; wait for approval.
- Standing user instruction (2026-11-14): when addressing a GitHub issue during authorized work, visibly mark progress, explain the fix and actual checks in nontechnical language, and close it with reason `completed` once complete and verified. Keep partial work open. If the fix immediately causes another observed problem, create/link a separate issue in the affected mod's verified repo, checking for duplicates first. This includes regressions caught and fixed before release. Follow `_GitHub/ISSUES.md`; no repeated permission request is required within this scope. Unrelated issue activity, labels and assignments remain separately authorized.
- Never initiate a new feature or enhancement issue, feature development, or feature publication without the user's explicit request. Existing feature requests do not authorize implementation.
- Use Git tags for approved versions, repository topics for discovery, and issue labels only for issue classification. Remote changes to any require authorization. See `_GitHub/TAGS.md`, `ISSUES.md`, and `FEATURES.md`.

## Mandatory: no AI management on GitHub

GitHub is used only to host the mod's source, approved assets, project files,
`mod.json`, `.gitignore`, and player-facing `README.md`. It must NOT host
AI instructions, agent prompts, local work plans, AI-generated working
materials, GitHub Actions workflows, `.github/` issue templates,
Copilot instructions, bot configurations, or any AI automation whatsoever.

The USER'S LOCAL AGENT owns issue/feature triage, planning and execution.
Maintain issues addressed by authorized work using the standing progress,
plain-language verification, regression reporting and completed closure
workflow in `_GitHub/ISSUES.md`. This supersedes older blanket mod-local
prohibitions on these issue updates. Pushes and tags require explicit approval. Treat the
entire `{ModName}/.github/` folder and AI agent files/directories as local,
Git-ignored content. `.gitignore` itself belongs in the repository.

## Local build and release script package

`_Workflows/Tools/BuildMod/` provides the self-contained PowerShell script package (`PublishMod.ps1`, `BuildMod.cmd` / `BuildMod.ps1`, `NexusFormat.ps1`, `PublishGithub.ps1`, `PublishNexus.ps1`). `BuildMod.cmd` accepts a mod root folder for interactive use, while `PublishMod.ps1` provides single-command execution for CLI/agent workflows. It syncs `README.md` and `Nexus/DESCRIPTION.bbcode.txt`, builds the root project in Release or Debug, copies the main DLL and `mod.json` into `/Release/` or `/Debug/`, optionally installs both into `KingdomInc/BepInEx/plugins/{ModName}/`, packages `BepInEx/plugins/{ModName}/{AssemblyName}.dll` and `mod.json` into `{ModName}-v{Version}.zip`, publishes & verifies GitHub Releases and Nexus v3 file uploads + page metadata (`PATCH /mods/{id}`, changelogs, file-level dependencies, tag/color verification), and updates `mod.json` + `_AI/Notes/LastPublishReceipt.json`. Never read `_AI/Notes/nexus_v3_openapi.yaml` or inspect other mods when publishing. For current details read `_Workflows/BUILD.md` and `_Workflows/RELEASE.md`.
