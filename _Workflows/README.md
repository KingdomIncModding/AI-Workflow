# Local Workflows

These scripts and instructions run on the local Windows machine. They are not GitHub Actions and are not uploaded to any mod repository.

- `Tools/BuildMod/PublishMod.ps1` - single-command orchestrator for preparing docs/BBCode, pushing source, building, installing, and publishing a single mod to GitHub and Nexus Mods.
- `Tools/BuildMod/BuildMod.cmd` (`BuildMod.ps1`) - drag a mod folder (or call via CLI) to build Release or Debug, optionally install, and optionally publish a Release.
- `Tools/BuildMod/NexusFormat.ps1` - syncs `Nexus/DESCRIPTION.md` to `README.md`, converts/validates `Nexus/DESCRIPTION.bbcode.txt`, and extracts version-specific changelog notes.
- `Tools/BuildMod/PublishGithub.ps1` - GitHub Release publisher with version-scoped notes, asset verification, and `mod.json` updates.
- `Tools/BuildMod/PublishNexus.ps1` - Nexus v3 file uploader, dependency linker, BBCode description/changelog updater, and read-after-write verifier.
- `BUILD.md` - build and installation conventions.
- `RELEASE.md` - GitHub/Nexus release scripts, CLI invocations, and required approvals.
- `NEWMOD.md` - local mod initialization from the single `_ModTemplate/` directory, including complete classes in responsibility folders, required source-layout validation, thumbnail generation, image-only Gen cleanup, preview and explicit image approval; move the image into approved assets only after approval.
- `CLEAN.md` - cleaning procedure (see that file when populated).
- `_ModTemplate/` - the sole shared mod template. Do not copy it into tool folders.

GitHub repository replacement is a standalone tool at `_GitHub/RepoReplace/` (also invokable via `PublishMod.ps1 -PushSource`).
