# Kingdom Inc Modding — AI Workflow

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/urakkaamyx/tip)

Shared AI agent instructions, mod template, source-layout validator, and local build/publish PowerShell tooling for **Kingdom Inc** mod development.

## Installation

Clone or copy this repository into your Kingdom Inc game directory at:

```text
<KingdomIncDir>\_Mods\_AI\
```

## Contents

- `AGENTS.md` — Primary entry point and workspace rules for AI coding agents.
- `_Workflows/` — Mod creation (`NEWMOD.md`), build (`BUILD.md`), archive (`ARCHIVE.md`), release (`RELEASE.md`), shared `_ModTemplate/`, and local automation scripts:
  - `Tools/BuildMod/` — `PublishMod.ps1`, `BuildMod.ps1`, `NexusFormat.ps1`, `PublishGithub.ps1`, `PublishNexus.ps1`.
  - `Tools/SourceLayout/` — C# source layout validator (`Check-SourceLayout.ps1`).
- `_GitHub/` — Repository conventions, issue/feature templates, and `RepoReplace/` migration tooling.
- `_Nexus/` — Nexus Mods description formatting and v3 publishing guides.
- `_shared/` — Coding standards, modding guidelines, and thumbnail generation prompts/master template.
- `Notes/` — Reference Nexus Mods v3 OpenAPI specification.

## Support

If you enjoy these Kingdom Inc mods and tools, consider supporting development on Ko-fi!

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/urakkaamyx/tip)
