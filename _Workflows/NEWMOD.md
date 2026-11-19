# NEWMOD - Create a Kingdom Inc. Mod from `_ModTemplate`

## Purpose

`_ModTemplate` is the starting point for a new mod folder. It contains `mod.json`, a blank root `README.md` (exactly matching the blank Nexus description), a root `.gitignore`, local-only issue reference forms, blank Nexus page documents, and the approved-assets/AI-working folder layout. Copy the template for each new mod; leave the original template unchanged.

**Thumbnail generation is a required part of new-mod creation.** Reference the shared master in place, generate the image, move only the image into `_AI/Gen/Assets/Thumbnails/`, show it and ask explicitly for approval. After successful generation, remove temporary per-image data; leave only the image in the Gen thumbnail folder. Only after image approval, move it into `Assets/Thumbnails/`.

## Locations

```text
_Mods/
+-- _AI/
|   +-- _Workflows/
|       +-- NEWMOD.md
|       +-- _ModTemplate/
|           +-- mod.json
|           +-- README.md             # Exact mirror of Nexus/DESCRIPTION.md
|           +-- .github/ISSUE_TEMPLATE/
|           |   +-- bug_report.yml
|           |   +-- feature_request.yml
|           +-- .gitignore
|           +-- src/                   # Source code only
|           +-- Assets/                # Approved mod assets only
|           |   +-- Screenshots/
|           |   +-- Thumbnails/
|           +-- Nexus/                 # Player-facing pages, initially blank
|           |   +-- DESCRIPTION.md
|           |   +-- CHANGELOG.md
|           |   +-- PREREQUISITES.md
|           |   +-- COMPATIBILITY.md     # Class.Method, Hook Type, Impact (blank)
|           +-- _AI/
|               +-- Gen/
|               |   +-- Assets/        # Unapproved generations/prompts
|               |       +-- Thumbnails/ # Generated image only, pending approval
|               +-- Prompts/
|               +-- Media/
|               +-- Notes/
|               +-- Scratch/ #Clean this folder up when outdated.
+-- {ModName}/
    +-- mod.json
    +-- README.md               # Exact copy of Nexus/DESCRIPTION.md
    +-- .github/ISSUE_TEMPLATE/ # Local-only references; NEVER uploaded
    +-- .gitignore             # TRACKED; ignores _AI, Nexus and issue forms
    +-- {ModName}.csproj       # Project file (when created)
    +-- {ModName}.slnx         # Solution file (when created)
    +-- src/
    |   +-- ...               # Source code only
    +-- Assets/
    |   +-- Thumbnails/        # Approved final thumbnail only
    |   +-- {category}/        # Approved final artwork/images/assets
    +-- Nexus/                 # Player-facing release documentation
    |   +-- DESCRIPTION.md    # No dev/AI/build/artifact information
    |   +-- CHANGELOG.md      # Changes meaningful to players
    |   +-- PREREQUISITES.md   # Requirements for players
    |   +-- COMPATIBILITY.md    # Class.Method, Hook Type, Impact
    +-- _AI/                   # AI-only working area (gitignored)
        +-- Gen/
        |   +-- Assets/
        |       +-- Thumbnails/   # Image only until approved, then move to Assets
        |       +-- {category}/   # AI generations, prompts, drafts
        +-- Prompts/
        +-- Media/
        +-- Notes/
        +-- Scratch/ #Clean this folder up when outdated. Should only contain relevant for the version that we are working on. We do not to run outdated scripts against our code.
```

- **Template:** `_Mods/_AI/_Workflows/_ModTemplate/`
- **New mod:** `_Mods/{ModName}/`
- **Instructions:** `_Mods/_AI/_Workflows/NEWMOD.md` (this file)

## Create a New Mod

1. Choose the mod's actual name and folder name, such as `BetterBuilding`.
2. Create `_Mods/{ModName}/`. Do not replace an existing mod folder.
3. **Copy the contents** of `_AI/_Workflows/_ModTemplate/` into the new mod folder, **including `.gitignore`, blank `README.md`, `.github/ISSUE_TEMPLATE/`, and empty folders**. Do not move or modify `_ModTemplate` itself.
4. Ensure `_Mods/{ModName}/src/` exists. Put **source code only** inside `src/` (for example, `.cs` files and source subfolders). Keep **project files** (`.csproj`) and **solution files** (`.sln` / `.slnx`) directly in `_Mods/{ModName}/`, not in `src/`. Follow `_AI/_shared/CODING_STANDARDS.md`: **one class per file**, keeping its methods together, and **one job per method**. Do not stack multiple classes in one file or interpret the method rule as one method per file.
5. Ensure `{ModName}/Assets/` exists for **approved finalized mod assets only**. The template includes `Assets/Thumbnails/` (plural) and `Assets/Screenshots/`. When needed, place approved artwork/images/other assets in `{ModName}/Assets/{category}/`. **Never put AI prompts, drafts, development notes, or other generation files in `Assets/`.**
6. Ensure `{ModName}/_AI/Gen/Assets/` and `_AI/Prompts/`, `Media/`, `Notes/`, `Scratch/` exist. Put generated artwork and its generation-specific prompts, drafts, variants, source media, previews, and other intermediates in `{ModName}/_AI/Gen/Assets/{category}/`. Put other AI-only files in the matching `_AI/` category. **Never put any of this in the mod root, `src/`, or approved `Assets/`.**
   Keep the copied `_AI/Prompts/RepositoryWorkflow.md` with the mod. It routes
   repository work to the `KingdomIncModding` organization and the verified
   destination in `mod.json`; it must remain Git-ignored.
7. **Generate and present the new mod's thumbnail during creation, then ask explicitly for image approval.** Follow the required thumbnail step below. Reference the master in place; move only the generated image into `_AI/Gen/Assets/Thumbnails/` and remove temporary per-image data. After approval, move that image into `Assets/Thumbnails/`. No thumbnail hashes, saved per-image prompts, reference copies, generation records or other sidecars are needed.
8. Ensure `{ModName}/Nexus/DESCRIPTION.md`, `CHANGELOG.md`, `PREREQUISITES.md`, and `COMPATIBILITY.md` exist and are initially blank. They hold **only player-facing** Nexus page text; never place AI verification, build information, artifact details, or other development content in `DESCRIPTION.md`. Read `_AI/_Nexus/MOD_DESCRIPTIONS.md` before filling them. `COMPATIBILITY.md` must use only `Class.Method`, `Hook Type`, and `Impact` (the brief behavioral effect and any relevant compatibility concern), verified from source; never claim physical edits to game files. Keep drafts, prompts, and review notes in `{ModName}/_AI/` instead.
9. Ensure the copied `{ModName}/.gitignore` includes `/_AI/`, `/Nexus/`,
   `/.github/`, `/~tmp/`, and `/AI_SETUP_PROMPT.md`.
   The `.gitignore` file itself MUST be committed to GitHub, while those
   directories remain local. Do not ignore approved `Assets/`.
10. Ensure `{ModName}/README.md` exactly matches `Nexus/DESCRIPTION.md`. Both start blank. When populating them, add the confirmed compatibility table from `Nexus/COMPATIBILITY.md` to a `## Compatibility` section in DESCRIPTION, then copy DESCRIPTION over README byte-for-byte. Never add development content. Read `_AI/_GitHub/CONVENTIONS.md`.
11. Open the copied `mod.json` and enter the mod's known metadata. The intended GitHub owner is `KingdomIncModding`, the prescribed repository name is `{ModName}`, and remote URLs/branches remain `null` until verified.
12. Keep unknown GitHub/Nexus values as `null` until those destinations actually exist or are confirmed.
13. When ready to build the mod, add source code under `src/` and create the project (`.csproj`) and solution (`.sln` / `.slnx`) at the mod root. The template establishes metadata and folder rules; it does **not** create a GitHub repository, Nexus page, or buildable mod project.

### Required C# source organization

Read `_AI/_shared/CODING_STANDARDS.md` and the copied `_AI/Prompts/SourceLayout.md` before writing source. **One class per file, all its methods together; one job per method.** Preserve responsibility folders such as `Configuration/`, `Lifecycle/`, `Research/`, `Patches/`, `Rendering/`, and `UI/` when they apply. Give each real helper or patch class a complete file in its proper folder. The plugin/component keeps its required Unity entry points and delegates work to those helpers.

Never create method-per-file partials, wrap a helper file in a partial parent class, or flatten existing responsibility folders during consolidation. If a class has grown across several folders, extract cohesive helper classes there rather than gathering all feature code into the plugin.

After creating or reorganizing source, run from `_Mods/`:

```powershell
& .\_AI\_Workflows\Tools\SourceLayout\Check-SourceLayout.ps1 -ModFolder .\MyNewMod
```

The checker uses the installed .NET 10 SDK and rejects partial type declarations and multiple top-level types per file. Build artifacts stay under the new mod's ignored `_AI/Scratch/SourceLayout/`. The standard `BuildMod.ps1` workflow runs this check before compiling/staging. Review folder placement and method responsibilities too; the parser cannot determine them automatically.

Restrict the mod project's C# compile items to its source tree so ignored `_AI/` experiments and checker-generated files cannot become mod code:

```xml
<PropertyGroup>
  <EnableDefaultCompileItems>false</EnableDefaultCompileItems>
</PropertyGroup>
<ItemGroup>
  <Compile Include="src\**\*.cs" />
</ItemGroup>
```

Keep any verification-only sources explicitly excluded from the player project and included only by their verification project/configuration.

### Required thumbnail step

1. Read the new mod's `mod.json` and use its exact public `name` as `MOD_NAME`. A Nexus page URL is not needed to prepare the thumbnail.
2. Read `_AI/_shared/ThumbnailGen/README.md` and `PROMPT.md` in place. Reference the existing shared `thumbnail-master.png` directly in the image-generation tool; do not copy or overwrite it. Keep its artwork, frame and layout. Use `BADGE = NONE` unless the user explicitly requests a badge. The only default text is `KINGDOM .INC` on the top banner and the exact mod name on the central parchment.
3. After successful generation, move only the generated PNG into `{ModName}/_AI/Gen/Assets/Thumbnails/`. Remove temporary per-image data, leaving only the image there. Do not create or retain thumbnail hashes, saved per-image prompts, reference copies, generation records or other sidecars. Keep the shared master and shared prompt where they are.
4. Inspect the result for exact spelling, readable centered text, the master's aspect ratio, unchanged decorative layout and an empty bottom green area. Show the image inline and ask, "Do you approve this thumbnail?"
5. Only after explicit approval of that image, move it from Gen into `{ModName}/Assets/Thumbnails/`. Do not leave a duplicate in Gen. A general "Publish" instruction is not thumbnail approval. Continue independent coding/build work while image approval is pending. Nexus gallery upload remains a separate user action.

These thumbnail-specific rules override general requirements to save prompts, copy references or preserve generation material. For thumbnails, retain only the image after successful generation.

If image generation is unavailable, report the thumbnail as pending with the specific tool failure; do not silently skip it or report the whole creation workflow complete.

### PowerShell example

Run from the `_Mods` directory, replacing `MyNewMod` with the new folder name:

```powershell
$modName = 'MyNewMod'
$template = Join-Path (Get-Location) '_AI\_Workflows\_ModTemplate'
$destination = Join-Path (Get-Location) $modName

if (-not (Test-Path -LiteralPath $template -PathType Container)) {
    throw "Mod template not found: $template"
}
if (Test-Path -LiteralPath $destination) {
    throw "Mod folder already exists: $destination"
}

Copy-Item -LiteralPath $template -Destination $destination -Recurse -Force
New-Item -ItemType Directory -Path (Join-Path $destination 'src') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $destination 'Assets') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $destination 'Assets\Thumbnails') -Force | Out-Null
$nexus = Join-Path $destination 'Nexus'
New-Item -ItemType Directory -Path $nexus -Force | Out-Null
foreach ($name in @('DESCRIPTION.md', 'CHANGELOG.md', 'PREREQUISITES.md', 'COMPATIBILITY.md')) {
    $doc = Join-Path $nexus $name
    if (-not (Test-Path -LiteralPath $doc)) {
        New-Item -ItemType File -Path $doc | Out-Null
    }
}
New-Item -ItemType Directory -Path (Join-Path $destination '_AI\Gen\Assets') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $destination '_AI\Gen\Assets\Thumbnails') -Force | Out-Null
foreach ($category in @('Prompts', 'Media', 'Notes', 'Scratch')) {
    New-Item -ItemType Directory -Path (Join-Path $destination "_AI\$category") -Force | Out-Null
}
$gitignore = Join-Path $destination '.gitignore'
if (-not (Test-Path -LiteralPath $gitignore)) {
    throw 'Template is missing .gitignore; add /_AI/ to the mod root .gitignore.'
}
foreach ($rule in @('/_AI/', '/Nexus/', '/.github/', '/.agents/', '/.claude/', '/.codex/', '/AGENTS.md', '/CLAUDE.md', '/GEMINI.md', '/~tmp/', '/AI_SETUP_PROMPT.md')) {
    if (-not ((Get-Content -LiteralPath $gitignore) -contains $rule)) {
        throw ('Template .gitignore is missing rule: {0}' -f $rule)
    }
}
```

The command copies the template (including hidden `.gitignore`), creates `src/`, `Assets/Thumbnails/`, `Nexus/` with its four blank Markdown files, `_AI/Gen/Assets/Thumbnails/`, and the four other mod-local `_AI/` categories, and verifies that `/_AI/` is ignored. Add other asset-specific `{category}/` subfolders on demand. This creates the thumbnail folders only; perform the required image-generation and preview step separately. It does **not** create project or solution files; when those are created, they belong directly in `_Mods/MyNewMod/`.

## Mandatory AI material policy

**NEVER place prompts, AI development notes, generated reference media, or temporary AI artifacts in `_Mods/` root, `{ModName}/` root, or `src/`.** Put them in `{ModName}/_AI/Prompts/`, `Media/`, `Notes/`, `Scratch/`, or a new category inside that same mod-local `_AI/` directory. Redirect tools that default to saving in the working directory.

Every new mod must have a **root** `.gitignore` containing:

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

This ignores **every category and file** inside that mod-local `_AI/`; it does **not** ignore the shared `_Mods/_AI/` workspace documentation. Do not commit or publish mod-local `_AI/`. For an **existing** mod, add this rule to its current root `.gitignore` rather than overwriting existing ignore rules; create its mod-local `_AI/` categories. If AI files were already tracked by Git, review and untrack them with `git rm -r --cached -- _AI` from the **mod repository root**; do not delete local content.

**Approved-versus-generated asset rule:** Finalized, **explicitly approved** mod artwork/images/assets belong under `{ModName}/Assets/{category}/` and may be committed. Any AI generation work, including category-specific prompts, drafts, previews, variants, references, and intermediates, **must be created in `{ModName}/_AI/Gen/Assets/{category}/` and is Git-ignored**. Do not save generation output directly to `Assets/` or auto-promote a draft; copy an approved final asset there only after explicit approval. General prompts unrelated to asset creation belong in `_AI/Prompts/`.

**Thumbnail exception:** Follow the required thumbnail step above instead of the general prompt/reference preservation rule. Reference the shared master in place, keep only the generated image in `_AI/Gen/Assets/Thumbnails/`, show it and ask for approval. After approval, move that image into `Assets/Thumbnails/` rather than copying it.

Normal, intentional project files (`mod.json`, `.csproj`, `.slnx`, `.gitignore`, public README) remain in the mod root. Put Nexus player-facing pages under `Nexus/`, never at the root. `DESCRIPTION.md` must NEVER contain AI verification, build info, artifacts, or development material; `CHANGELOG.md`, `PREREQUISITES.md`, and `COMPATIBILITY.md` are also public-facing. `COMPATIBILITY.md` documents confirmed runtime hooks using only `Class.Method`, `Hook Type`, and `Impact`, without claiming physical file modification. See `_AI/_Nexus/MOD_DESCRIPTIONS.md`. Actual mod source stays in `src/`. Only AI-only working material is routed to `_AI/`.

## Configure `mod.json`

Edit the copy in the **new mod's** folder, not the template.

| JSON field | What to enter |
|---|---|
| `id` | Stable identifier for this mod. |
| `name` | Display name. |
| `version` | Actual current mod version; otherwise `null`. |
| `author` | Actual author or team; otherwise `null`. |
| `description` | Short description; otherwise `null`. |
| `repository.platform` | `GitHub` for the GitHub repository. |
| `repository.owner` | Intended GitHub owner: `KingdomIncModding`. |
| `repository.name` | Canonical repo name `{ModName}` once chosen; otherwise `null`. |
| `repository.topics` | Accurate chosen GitHub repository topics, otherwise `[]`; topics are not applied without authorization. |
| `repository.latestTag` | Last actually verified version tag, otherwise `null`; not a proposed release. |
| `repository.url` | Exact repository URL once known; otherwise `null`. |
| `repository.branch` | Actual working/default branch; otherwise `null`. |
| `repository.visibility` | Actual visibility (`public` or `private`); otherwise `null`. |
| `distribution.nexus.game` | Existing template value: `kingdominc`. |
| `distribution.nexus.modId` | Exact Nexus Mods page ID once published; otherwise `null`. |
| `distribution.nexus.url` | Exact URL supplied by the user after manually creating the Nexus mod page; otherwise `null`. |
| `distribution.nexus.tags` | Desired Nexus tags; template requires `AI-Generated Content`. Add other accurate tags for the mod and AI-related page media. These are NOT proof of applied tags. |
| `distribution.nexus.tagsVerified` | `false` until the required tags are confirmed on the live Nexus page; only then `true`. Reset to `false` if desired tags or the Nexus URL change. |
| `distribution.nexus.requirements` | Array of confirmed player dependencies; required Nexus mods must include their exact verified Nexus page URLs. Leave `[]` when none have been identified. Each entry uses `name`, `url`, `minimumVersion`, and `notes` (`null` for unknown optional values). Keep it consistent with `Nexus/PREREQUISITES.md`. |
| `distribution.nexus.requirementsVerified` | `false` until all required Nexus mods appear as linked entries in the live Nexus Requirements section (or no linked mod requirements are applicable); reset after requirements or URL change. |
| `development.framework` | Framework used by the mod, if any; otherwise `null`. |
| `development.language` | Language used by the project (template defaults to `C#`). |
| `development.target` | Actual target framework, such as `netstandard2.1`, if applicable; otherwise `null`. |
| `development.dependencies` | Array of confirmed dependencies, or `[]` if none are recorded yet. |
| `publishing.githubReleases` | `true` or `false` when the choice is known; otherwise `null`. |
| `publishing.nexusMods` | `true` or `false` when the choice is known; otherwise `null`. |

`null` means **not yet specified**, not `false` or an invented default. Keep the JSON valid; do not add comments or trailing commas. The `requirements` array is the structured source for Nexus prerequisites; keep `Nexus/PREREQUISITES.md` consistent with it when writing the public-facing page. Do not invent links, version requirements, or dependencies.

## Rules for AI Agents and Workflows

- Read `_Mods/{ModName}/mod.json` before GitHub, Nexus, or release actions.
- Treat that file as the source of truth for the mod's repository and Nexus page. **Never guess** a URL, branch, page ID, or publishing destination from the folder name.
- Do not publish, create remote repositories, push code or tags, or upload releases merely because a new mod folder was created. Those are separate, explicitly requested operations. At major milestones, SUGGEST a push; do not perform one until explicitly approved.
- Never create, update, comment on, label, assign, close, or reopen GitHub issues without explicit instruction. A bug discovered locally is not an automatic GitHub issue. Read/list issues only when requested.
- Never add a feature to the mod or create a feature request issue until the user explicitly requests it. Feature issues are not permission to implement them.
- GitHub `README.md` must remain an EXACT copy of the public `Nexus/DESCRIPTION.md` with no AI verification, dev notes, or GitHub-only text. See `_AI/_GitHub/README.md`.
- When a GitHub repository or Nexus page is created or changed, update only the affected `mod.json` fields with the confirmed values. For Nexus, the USER creates the page manually, supplies its URL, and the agent follows `_AI/_Nexus/PUBLISHING.md` for verified API content updates and tag checks.
- Keep credentials and tokens out of `mod.json`.
- Keep shared AI guidance in `_Mods/_AI/`; keep **mod-specific AI-only working material** in `{ModName}/_AI/` (ignored by that mod's Git) and the mod's metadata in its root `mod.json`.
- **Mandatory project layout:** `src/` contains **only source code and its source subfolders**. The mod's `.csproj`, `.sln`, and `.slnx` files belong **directly in `_Mods/{ModName}/`**, alongside `mod.json`. Never place source code or project files in `_AI/`.
- **Mandatory Nexus layout:** `Nexus/DESCRIPTION.md`, `Nexus/CHANGELOG.md`, `Nexus/PREREQUISITES.md`, and `Nexus/COMPATIBILITY.md` hold public-facing Nexus content. `DESCRIPTION.md` must contain no AI checks, build notes, artifacts, or developer material. Drafts and AI prompt content stay in the gitignored `_AI/`.
- **Mandatory asset layout:** Approved mod assets go only to `Assets/{category}/`; generation work and associated prompts go only to `_AI/Gen/Assets/{category}/`. Never place generation files in the approved assets tree.

## Notes

- **Do not decompile the game.** The decompiled `Assembly-CSharp` source is already extracted at `KingdomInc/Extracted/Source/` (one folder per namespace, e.g. `Assets.Behaviour.UI/`). Read it directly when researching hooks, UI, or game behavior; do not run `ilspycmd` or write decompiled output into a mod's `_AI/Scratch/`.

## Completion

A new mod is initialized from the template when its own folder exists, blank `README.md` identical to blank `Nexus/DESCRIPTION.md`, `.github/ISSUE_TEMPLATE/`, `src/`, `Assets/`, all four blank `Nexus/*.md` files, and mod-local `_AI/Gen/Assets/` and other category folders exist, root `.gitignore` contains `/_AI/`, the copied `mod.json` is valid JSON, and its known identity fields have been entered. GitHub/Nexus connections can be filled in later.

Before reporting **new-mod creation complete**, generate, inspect and show the required thumbnail and ask explicitly for image approval. Until approval, leave only the image in `_AI/Gen/Assets/Thumbnails/`. After approval, move it into `Assets/Thumbnails/`. Do not create per-thumbnail sidecars or require approval before finishing independent coding/build work.

## Nexus page creation and synchronization

1. Do not create a Nexus page when initializing a mod. Leave `distribution.nexus.url` and `modId` as `null`.
2. The user creates the Nexus page manually and then supplies its URL. Validate the link and save the confirmed URL and mod ID in `mod.json`.
3. When asked to populate the page, read `_AI/_Nexus/PUBLISHING.md` and the four mod-specific `Nexus/*.md` files. Use supported authenticated API operations for the existing page only.
4. From `PREREQUISITES.md`, link each confirmed required Nexus mod as an actual entry in the page's Requirements section, through a supported requirement API for the correct requirement mode or by giving the user exact links to add manually. A simple description link is not enough. Keep `requirementsVerified` false until the live page is checked.
5. Required desired tag: `AI-Generated Content` (already listed in the template). Add other relevant tags, including `AI Media` for AI-written page content or generated promotional media. If tags are not settable through an available documented API, have the user set them in the website editor and verify the result.
6. `distribution.nexus.tagsVerified` remains `false` until the required tags have been confirmed on the live page. Never mistake an API description update for tag completion.
7. The four template Nexus Markdown files stay blank until real player-facing content is ready; do not prefill boilerplate, development reports, or invented requirements.

## GitHub boundary

The `.github/ISSUE_TEMPLATE/` folder is PRIVATE LOCAL REFERENCE MATERIAL.
No `.github/` file, AI agent instruction/config, prompt, local issue plan,
or Nexus draft is uploaded to GitHub. `.gitignore` itself is tracked.
The user's local agent manages work and may read GitHub issues only when
requested; GitHub does not run or manage AI automation.

## Local build outputs

Create `/Release/` and `/Debug/` as needed. Both must be ignored by the mod root `.gitignore`. Use `_Workflows/Tools/BuildMod/BuildMod.cmd` for drag-and-drop build/install and opt-in Release publishing. Always copy `mod.json` alongside the compiled DLL into `{ModName}/Release/`, `KingdomInc/BepInEx/plugins/{ModName}/`, and inside the release ZIP (`BepInEx/plugins/{ModName}/mod.json`). Never commit compiled build outputs to GitHub.
