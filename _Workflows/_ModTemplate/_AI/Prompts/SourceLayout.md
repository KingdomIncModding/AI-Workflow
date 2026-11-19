# C# source layout

Read the shared `_Mods/_AI/_shared/CODING_STANDARDS.md` before creating source.

- One class per file, with all that class's methods together.
- Each method performs one job. This does not mean one method per file or class.
- Keep classes in their proper responsibility folders under `src/`: configuration, lifecycle helpers, research, patches, rendering and UI as applicable. Preserve established folder organization during edits.
- If a class spans several responsibility folders, extract real helper classes in those folders. Keep required Unity entry points on the plugin/component and delegate work to the helpers.
- Do not create handwritten partial types, method-named fragments, or partial-parent wrappers around patch/helper classes. Do not flatten responsibility folders into a plugin file.
- Keep project and solution files at the mod root, source under `src/`, and development work under this ignored `_AI/` directory.
- Disable default C# compile discovery in the mod project and include only `src/**/*.cs`, with explicit gates/exclusions for verification code. `_AI/` source and generated checker outputs must never compile into the mod.

After writing or reorganizing source, run `_Mods/_AI/_Workflows/Tools/SourceLayout/Check-SourceLayout.ps1 -ModFolder <mod-root>`, review folder placement and method responsibilities, and build the affected projects. The standard build workflow runs the same check automatically.
