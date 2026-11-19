# Nexus Mods - Page & Release Publishing Workflow

## Goal

Use a Nexus page that the USER created manually. Once the user supplies the existing mod page URL (recorded in `{ModName}/mod.json`), use the workspace's self-contained PowerShell publishing package (`_Mods/_AI/_Workflows/Tools/BuildMod/`) to upload releases, update the summary and BBCode description, append version changelogs, link file-level dependencies, and verify tags and live rendering.

> **Strict Agent Rule — Do NOT Read OpenAPI YAML or Other Mods:**
> Do **not** read `_Mods/_AI/Notes/nexus_v3_openapi.yaml` and do **not** read or scan other mods' folders when publishing a mod. All Nexus v3 endpoints, schemas, BBCode conversion rules, changelog formatting, dependency linking, and read-after-write checks are already built into `_Mods/_AI/_Workflows/Tools/BuildMod/PublishNexus.ps1` and `NexusFormat.ps1`. Work strictly inside the target `{ModName}/` folder.

## Repository-link migrations

For an ownership migration, update only repository URLs in the current live
description. Do not publish an unrelated local draft, summary, changelog,
dependency change or file upload. Read and save the current description in
the target mod's ignored `_AI/Notes/` before editing.

The v3 GET description contains HTML-escaped characters and generated
`<br />` line-break markers. It is display text, not a raw PATCH payload.
Decode HTML entities and reverse the generated line-break markers to the
original BBCode/newlines before sending `PATCH /mods/{id}` with only the
`description` field. A successful PATCH may have an empty response body.
Re-read the page and require the display text to match the saved original
exactly, with only the authorized repository URLs replaced. Avoid repeatedly
escaping a GET response or publishing literal `<br />` text.

Keep local DESCRIPTION and README synchronized with `NexusFormat.ps1`.
The normal full publisher already sends raw local BBCode; this decoding
step applies when editing a description obtained from GET.

## Required Local Files

```text
_Mods/{ModName}/
+-- mod.json
+-- README.md                       <- Exact byte copy of Nexus/DESCRIPTION.md
+-- Nexus/
|   +-- DESCRIPTION.md              <- Canonical player-facing Markdown (includes ## Compatibility)
|   +-- DESCRIPTION.bbcode.txt      <- Generated/validated Nexus BBCode with [color=#...] spans
|   +-- CHANGELOG.md                <- Player-facing version history
|   +-- PREREQUISITES.md            <- Confirmed player prerequisites
|   +-- COMPATIBILITY.md            <- Class.Method | Hook Type | Impact table
+-- _AI/
    +-- Notes/
    |   +-- LastPublishReceipt.json <- Automatically written by PublishNexus.ps1
    +-- Scratch/                    <- Private temporary payloads
```

## Automated PowerShell Script Package (`_Mods/_AI/_Workflows/Tools/BuildMod/`)

1. **`NexusFormat.ps1`**
   - Validates `Nexus/DESCRIPTION.md`, `COMPATIBILITY.md`, `PREREQUISITES.md`, and `CHANGELOG.md`.
   - Verifies that `DESCRIPTION.md` includes `## Compatibility` and every row from `COMPATIBILITY.md`.
   - Copies `Nexus/DESCRIPTION.md` byte-for-byte to `README.md` and verifies SHA-256 equality.
   - Generates or updates `Nexus/DESCRIPTION.bbcode.txt` from `Nexus/DESCRIPTION.md` (preserving existing hex colors or applying `#F2B552` title, `#65C7E8` section headings, `[size=4][b]Compatibility[/b][/size]`, `[list]`, `[table]`, and `[url]`), and validates balanced tags and zero leftover Markdown markers.
   - Extracts version-specific changelog lines (`Get-ModVersionChangelog`) with leading `- ` stripped for Nexus.

2. **`PublishNexus.ps1`** (called directly or via `PublishMod.ps1` / `BuildMod.ps1`)
   - **Mod & File Group Resolution:** Calls `GET /games/{game}/mods/{modId}` to resolve internal `modUid` and `GET /mods/{modUid}/files` to match or auto-select `distribution.nexus.fileId` (self-healing if a version ID was stored).
   - **New-file response reconciliation:** A successful `POST /mod-files` may return a version ID. The script writes `_AI/Notes/NexusUploadReceipt.json`, then resolves the new file group and its expected version from the live mod file list. If follow-up resolution fails, inspect that receipt and server state; resume metadata-only for an existing upload rather than creating a duplicate.
   - **Single-Part Binary Upload:** Computes MD5 (hex + Base64), creates upload session (`POST /uploads`), uploads ZIP (`PUT {presigned_url}`), finalizes (`POST /uploads/{id}/finalise`), and polls `GET /uploads/{id}` until `state == "available"`.
   - **File Version Creation:** Calls `POST /mod-files/{fileId}/versions` (with `update_mod_version: true` and `archive_existing_file` from the mod's publishing policy) or `POST /mod-files` (for a new main file), and saves the resolved `fileId` to `mod.json`. Set `publishing.archivePreviousReleases` to `false` for frameworks whose consumers may require older versions. An explicit `-ArchiveExistingFile` argument overrides that policy; the default for mods without a policy remains `true`. Foundation preserves prior downloads. Restore already archived files through the Nexus file editor; changing this policy only affects future uploads.
   - **File-Level Dependency Linking:** Resolves required Nexus mods in `distribution.nexus.requirements`, switches to file-level requirements if needed (`PUT /mods/{modUid}/toggle-legacy-mod-requirements`), updates version dependency ranges (`PUT /mod-file-versions/{versionId}/dependencies/ranges`), verifies live definitions, and sets `distribution.nexus.requirementsVerified = true`.
     The ranges endpoint returns `dependency_definitions` at the response root (an enveloped response is also accepted). Requirements can specify `fileId` to select the required file group. Foundation consumers must pin `fileId: 8358756` (runtime); `8314821` is the optional SDK and must not be selected for players. Without a pin, resolution uses the required mod's primary file group. Minimum versions are resolved only inside that group, and a missing version fails instead of searching unrelated downloads. Verification checks the game, mod page, target file group, minimum-version file group and minimum version.
   - **Summary & BBCode Description Update:** Sends `PATCH /mods/{modUid}` with `summary` (from `mod.json` `description`, `<= 350` chars) and `description` (from `Nexus/DESCRIPTION.bbcode.txt`).
   - **Version Changelog Append:** Sends `POST /mods/{modUid}/changelogs` with the normalized version entries, using `_AI/Notes/LastPublishReceipt.json` to prevent duplicate appends on reruns.
   - **Read-After-Write Verification:** Re-reads `GET /games/{game}/mods/{modId}` and `GET /mod-file-versions/{versionId}` to verify live file version, `security_scan_status`, live BBCode color spans (`NEXUS_COLORS_PRESENT_VERIFIED`), and live tags against `distribution.nexus.tags` (`tagsVerified`), then updates `mod.json` and `_AI/Notes/LastPublishReceipt.json`.
   - **Draft visibility:** Records the live `pageStatus` separately. A verified uploaded version on a `not_published` page yields `NEXUS_UPLOADED_DRAFT`; it is not proof the mod page is public. Missing tags, artwork and final draft publication remain manual website actions.

## Standard Publishing Sequence

1. **User supplies or confirms the Nexus page URL** in `{ModName}/mod.json` (`distribution.nexus.url` and `modId`). Never invent a URL or mod ID.
2. **Update `{ModName}/mod.json` and `{ModName}/Nexus/*.md`** from the target mod's actual source and release version.
3. **Sync and validate formatting locally:**
   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File "_Mods\_AI\_Workflows\Tools\BuildMod\NexusFormat.ps1" -ModFolder "_Mods\{ModName}"
   ```
4. **Publish (with explicit user authorization):**
   - **Full Release (Build + Install + GitHub + Nexus File & Page):**
     ```powershell
     powershell.exe -NoProfile -ExecutionPolicy Bypass -File "_Mods\_AI\_Workflows\Tools\BuildMod\PublishMod.ps1" -ModFolder "_Mods\{ModName}" -Target All -ConfirmPublish -ConfirmUpload
     ```
   - **Nexus File + Page Only:**
     ```powershell
     powershell.exe -NoProfile -ExecutionPolicy Bypass -File "_Mods\_AI\_Workflows\Tools\BuildMod\PublishMod.ps1" -ModFolder "_Mods\{ModName}" -Target Nexus -ConfirmPublish -ConfirmUpload
     ```
   - **Nexus Page Metadata Only (Description, Summary, Changelog, Dependencies — no binary upload):**
     ```powershell
     powershell.exe -NoProfile -ExecutionPolicy Bypass -File "_Mods\_AI\_Workflows\Tools\BuildMod\PublishMod.ps1" -ModFolder "_Mods\{ModName}" -Target NexusMetadataOnly -ConfirmPublish
     ```
   - **Read-Only Live Verification:**
     ```powershell
     powershell.exe -NoProfile -ExecutionPolicy Bypass -File "_Mods\_AI\_Workflows\Tools\BuildMod\PublishMod.ps1" -ModFolder "_Mods\{ModName}" -Target VerifyOnly
     ```
5. **Check manual gates if flagged:**
   - **Tags:** `mod.json` must include `AI-Generated Content` in `distribution.nexus.tags` (plus `AI Media` when applicable). `PublishNexus.ps1` checks live tags via the API and sets `tagsVerified = true` when present; if any tag is missing on the live page, ask the user to enable it in the Nexus page editor and re-run `-Target VerifyOnly`.
   - **Images:** Gallery images and thumbnails are uploaded manually by the user in the Nexus editor. For thumbnails, reference the shared master in place, move only the successful generated image into `{ModName}/_AI/Gen/Assets/Thumbnails/`, and remove temporary per-image data. Show the image and ask explicitly for approval; after approval move it into `{ModName}/Assets/Thumbnails/`. Keep no thumbnail sidecars or duplicate references. A publishing instruction alone is not thumbnail approval.

## Separate editions on one existing page

Use `PublishNexus.ps1` directly with `-CreateNewFile -FileCategory optional -UpdateModVersion:$false -PrimaryModManagerDownload:$false -ArchiveExistingFile:$false` for an explicitly authorized optional edition that must preserve the original main download. The new edition metadata must have `fileId: null`. Do not pass `-AutoSelectMainFile`. A configured existing file is rejected when `-CreateNewFile` is supplied.

For a shared description, provide an already validated combined BBCode file with `-PageDescriptionPath` and use `-PreservePageSummary` to leave the page summary unchanged. Preserve and verify the complete original description and every original file/version. Metadata-only and verification calls resolve the configured file group's version rather than borrowing the page's original primary version.

Subsequent releases use the configured optional file group without `-CreateNewFile`, while retaining the preservation flags. Create-version responses may contain the new version ID in `data.file.id`; the publisher keeps the configured parent group unchanged and records accepted uploads before follow-up reads. Never substitute a version ID for the group ID in `mod.json`.
