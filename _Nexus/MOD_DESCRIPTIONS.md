# Nexus Mods - Public Page Content Rules

## Purpose and locations

Every mod keeps its public page text in these local, player-facing documents:

```text
_Mods/{ModName}/
+-- README.md                       <- Exact byte copy of Nexus/DESCRIPTION.md
+-- Nexus/
    +-- DESCRIPTION.md              <- Canonical player-facing Markdown (includes ## Compatibility)
    +-- DESCRIPTION.bbcode.txt      <- Generated/validated Nexus BBCode (used for live Nexus page)
    +-- CHANGELOG.md                <- Player-facing version history
    +-- PREREQUISITES.md            <- Player installation/runtime requirements
    +-- COMPATIBILITY.md            <- Class.Method | Hook Type | Impact table
```

The four `.md` files are copied **empty** from `_AI/_Workflows/_ModTemplate/Nexus/` for new mods. `DESCRIPTION.bbcode.txt` is automatically generated and validated from `DESCRIPTION.md` by `_AI/_Workflows/Tools/BuildMod/NexusFormat.ps1`.

> **Strict Agent Rule:** When editing or publishing a mod's Nexus documents, work **only** inside that mod's `{ModName}/` directory. Never read `_AI/Notes/nexus_v3_openapi.yaml` and never inspect or modify other mods.

## DESCRIPTION.md & DESCRIPTION.bbcode.txt - STRICT CONTENT BOUNDARY

**NEVER add AI verification, AI-generated checks, validation/audit reports, build information, compiled artifacts, artifact paths, development progress, source-level implementation notes, test results, diagnostic logs, internal checklists, generation prompts, or ANY other developer-facing content to DESCRIPTION.md or DESCRIPTION.bbcode.txt.**

`DESCRIPTION.md` is exclusively for players browsing the mod page. Include only verified, player-relevant material:

- What the mod does, stated in user-facing language.
- Features and visible changes players can expect.
- How to install and use the mod, when helpful.
- Relevant in-game controls or configuration instructions.
- `## Compatibility` containing the exact 3-column table from `COMPATIBILITY.md`.

### Markdown-to-BBCode and Color Preservation

- `Nexus/DESCRIPTION.md` and root `README.md` are **byte-for-byte identical GitHub-Flavored Markdown**.
- Live Nexus mod descriptions use **BBCode** (`Nexus/DESCRIPTION.bbcode.txt`).
- Run `_AI/_Workflows/Tools/BuildMod/NexusFormat.ps1 -ModFolder "_Mods\{ModName}"` after editing `Nexus/DESCRIPTION.md`. It automatically:
  1. Verifies `## Compatibility` in `DESCRIPTION.md` matches `COMPATIBILITY.md`.
  2. Copies `DESCRIPTION.md` to `README.md` and verifies SHA-256 equality.
  3. Generates `Nexus/DESCRIPTION.bbcode.txt` with `[color=#F2B552][b]{Title}[/b][/color]`, `[color=#65C7E8][b]{Heading}[/b][/color]`, `[size=4][b]Compatibility[/b][/size]`, `[list][*]...[/list]`, `[table][tr][td]...`, and `[url=...]...[/url]` (preserving any custom hex colors already in `DESCRIPTION.bbcode.txt`).
  4. Validates that all BBCode tags are balanced and no raw Markdown (`#`, `**`, `[text](url)`, `|---|`) remains.

## CHANGELOG.md

Record release-to-release changes players care about under version headings (`## 1.0.0`) with `- ` bullet items. Do not include compilation output, test/verification results, AI implementation commentary, paths to build artifacts, or internal commit/task summaries. `NexusFormat.ps1` automatically extracts the current version's section for GitHub Releases and strips leading `- ` bullets when `PublishNexus.ps1` posts to the Nexus changelog API.

## PREREQUISITES.md - Linked Nexus Mod Requirements

Record only confirmed **player installation/runtime requirements**. Required mods hosted on Nexus must be identified here and in `mod.json`'s `distribution.nexus.requirements`:

```json
{
  "name": "Foundation",
  "url": "https://www.nexusmods.com/kingdominc/mods/18",
  "minimumVersion": "0.11.0",
  "type": "nexus"
}
```

- **Required Nexus mods**: `PublishNexus.ps1` automatically links entries with `"type": "nexus"` as file-level dependencies on the uploaded Nexus file version and verifies them (`requirementsVerified: true`).
- **Off-site requirements**: use `"type": "offsite"` (e.g. BepInEx 5).
- **Source of truth**: keep `PREREQUISITES.md` and `mod.json`'s `distribution.nexus.requirements` entries in agreement.

## COMPATIBILITY.md - Runtime Hooks

`COMPATIBILITY.md` gives players a brief list of the game methods that the mod hooks at runtime. Use **only these three columns**:

```markdown
# Compatibility

| Class.Method | Hook Type | Impact |
|---|---|---|
| <Class.Method> | <Hook Type> | <Behavior affected and any relevant compatibility impact> |
```

Do not add assembly names, DLL paths, build data, verification notes, or separate "reason" columns. Use one row per confirmed hook; inspect the actual `src/` implementation before populating the table.
