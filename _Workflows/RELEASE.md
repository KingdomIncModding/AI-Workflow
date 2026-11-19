# Local Release & Publishing Package

All release and publishing operations are handled by the self-contained PowerShell script package in `_Mods/_AI/_Workflows/Tools/BuildMod/`.

> **Strict Agent Rule — Single-Mod Scope & Zero Spec Reading:**
> When asked to build or publish a mod, **NEVER read `_Mods/_AI/Notes/nexus_v3_openapi.yaml` and NEVER read or touch any other mod's directory.** All Nexus v3 API endpoints, payload schemas, BBCode conversion/validation, changelog extraction, dependency linking, and GitHub release commands are built into the PowerShell script package below. Read only `{ModName}/mod.json` and `{ModName}/Nexus/*.md`, update them if needed, and run the scripts.

## Script Package (`_Mods/_AI/_Workflows/Tools/BuildMod/`)

| Script | Role |
| --- | --- |
| `PublishMod.ps1` | **Primary single-mod orchestrator** for CLI/agent use. Syncs docs/BBCode, optionally cleans & pushes source (`-PushSource`), builds Release, installs, packages ZIP, publishes to GitHub & Nexus, and writes `_AI/Notes/LastPublishReceipt.json`. |
| `BuildMod.cmd` / `BuildMod.ps1` | Interactive drag-and-drop (or CLI) builder, installer, archiver, and release dispatcher. |
| `NexusFormat.ps1` | Syncs `Nexus/DESCRIPTION.md` → `README.md` (SHA-256 byte equality), generates/validates `Nexus/DESCRIPTION.bbcode.txt` with `[color=#...]` spans, and extracts version-specific changelog notes. |
| `PublishGithub.ps1` | Publishes GitHub Release `v{Version}` with version-specific notes, optionally syncs repo metadata (`-SyncRepoMetadata`), verifies uploaded asset size, and updates `mod.json` (`repository.latestTag`, `publishing.githubReleases`). |
| `PublishNexus.ps1` | Uploads ZIP to Nexus v3 (`/uploads`), creates/updates file versions using the mod's `publishing.archivePreviousReleases` policy, links file-level dependencies, updates summary & BBCode description (`PATCH /mods/{id}`), appends version changelog (`POST /mods/{id}/changelogs`), verifies live page/colors/tags/scan status, and updates `mod.json`. |

## Interactive Menu (`BuildMod.cmd`)

Drag `_Mods/{ModName}/` onto `BuildMod.cmd` and select **Release** to access the publishing menu after the optional installation decision:

1. **Release to all (GitHub + Nexus file & metadata)** - GitHub Release then full Nexus file upload + page metadata sync.
2. **Release to GitHub** - publish a GitHub Release archive and verify asset.
3. **Release to Nexus (file + page metadata)** - upload the archive, link dependencies, and update description/changelog on Nexus.
4. **Sync Nexus page metadata only (no binary upload)** - update Nexus summary, BBCode description, changelog, and dependencies without uploading a new ZIP.
5. **Skip publishing** - leave the DLL and `mod.json` in `{ModName}/Release/` only.

Only Release builds are eligible; Debug builds cannot be published.

An archive of the built DLL and `mod.json` is created under `{ModName}/Release/` with install-ready layout `BepInEx/plugins/{ModName}/{AssemblyName}.dll` and `BepInEx/plugins/{ModName}/mod.json`. Its filename is `{ModName}-v{Version}.zip`.

For a new Nexus file, the publisher resolves the create response against that mod's live file groups and versions; the returned ID can be a version ID. It records accepted creation in `_AI/Notes/NexusUploadReceipt.json` before follow-up reads. After a partial failure, inspect the live files and resume metadata-only instead of re-uploading an already accepted version. A verified file on a draft page is reported as `NEXUS_UPLOADED_DRAFT`, not a published mod; check page visibility, required tags and artwork separately.

Dependency verification reads the live ranges response at its root and confirms each required mod's game, page ID, file group and configured minimum version. Foundation requirements specify `fileId: 8358756` for the runtime; the SDK is a separate file group. `requirementsVerified` stays false if the target file or the minimum-version record belongs to a different group, even when the mod page and version text match.

## Agent / CLI Commands (After Explicit User Approval)

- **Validate & sync docs/BBCode only (no build or network calls):**
  ```powershell
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "_Mods\_AI\_Workflows\Tools\BuildMod\NexusFormat.ps1" -ModFolder "_Mods\{ModName}"
  ```
- **Build, install, and package locally without publishing:**
  ```powershell
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "_Mods\_AI\_Workflows\Tools\BuildMod\PublishMod.ps1" -ModFolder "_Mods\{ModName}" -Target LocalPrepOnly
  ```
- **Verify live Nexus status, tags, colors, and dependencies (read-only API check):**
  ```powershell
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "_Mods\_AI\_Workflows\Tools\BuildMod\PublishMod.ps1" -ModFolder "_Mods\{ModName}" -Target VerifyOnly
  ```
- **Update Nexus page description/changelog/dependencies only (no binary upload):**
  ```powershell
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "_Mods\_AI\_Workflows\Tools\BuildMod\PublishMod.ps1" -ModFolder "_Mods\{ModName}" -Target NexusMetadataOnly -ConfirmPublish
  ```
- **Full Release (GitHub Release + Nexus File Upload & Page Sync, plus optional source push):**
  ```powershell
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "_Mods\_AI\_Workflows\Tools\BuildMod\PublishMod.ps1" -ModFolder "_Mods\{ModName}" -Target All -PushSource -SyncRepoMetadata -ConfirmReplace -ConfirmPublish -ConfirmUpload
  ```
  *(Omit `-PushSource -ConfirmReplace` if the GitHub source repository does not need to be replaced/pushed.)*

## Required Metadata

- `mod.json` with a confirmed `version`.
- For GitHub: `repository.url` for the real GitHub repository.
- For Nexus: `distribution.nexus.modId`, `distribution.nexus.game`, and optionally `distribution.nexus.fileId` (auto-resolved and saved to `mod.json` when a single active main file exists or after selection).
- `Nexus/DESCRIPTION.md`, `Nexus/CHANGELOG.md`, `Nexus/PREREQUISITES.md`, and `Nexus/COMPATIBILITY.md`. `NexusFormat.ps1` automatically syncs `README.md` and generates/validates `Nexus/DESCRIPTION.bbcode.txt`.

**No metadata is invented.** A missing field stops the requested publish action. All release archives are local-only and Git-ignored.

## Credentials & Approvals

- **GitHub:** Requires GitHub CLI (`gh`) installed and signed in (`gh auth login`).
- **Nexus Mods:** Reads `NEXUS_API_KEY` (or `NEXUSMODS_API_KEY`) from Process, User, or Machine environment variables, or prompts securely in memory. Never store credentials in `mod.json`, a repository, or workspace documentation.
- **Approvals:** Remote publication requires explicit user instruction. Interactive runs require typing `PUBLISH` (and `UPLOAD` for Nexus binary transfer); CLI runs pass `-ConfirmPublish` / `-ConfirmUpload` only when the user has explicitly authorized publishing that mod.
- Nothing is automatically posted to GitHub Issues, changed in feature requests, or managed by GitHub Actions.
## Repository ownership before publishing

Read the mod's ignored `_AI/Prompts/RepositoryWorkflow.md` and `mod.json`.
Kingdom Inc repositories belong to `KingdomIncModding`. Verify the live
repository and default branch before publishing; use metadata rather than
the authenticating user's login to construct source, release or SDK URLs.
For ownership migrations, follow `_GitHub/REPOSITORIES.md`: update mod-local
workflows first, then shared workflows, then transfer and verify before
changing metadata. A link migration alone does not require a new version,
build or binary upload.

