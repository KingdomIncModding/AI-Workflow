# Kingdom Inc. Mod Coding Standards

## C# source organization

- **One class per file.** Put each class in its own clearly named source file, such as `BuildingHotbar.cs`, with all of that class's fields, constructors, and methods together. Do not stack multiple classes in a single file.
- Do not create a separate file for every method, constructor, or Harmony prefix/postfix. Avoid layouts such as `BuildingHotbar.Build.cs`, `BuildingHotbar.Refresh.cs`, and `BuildingHotbar.OnDestroy.cs`.
- Use folders to group related classes by responsibility. Give helper classes their own files too.
- **Preserve responsibility folders when consolidating.** Keep configuration in `Configuration/`, research in `Research/`, patches in their existing `Patches/` folders, and UI/rendering code in their established folders. Combine a class's method fragments inside its owning folder. Do not pull separate patch/helper classes into a plugin or parent class file, or flatten the folder tree.
- If a partial class spans responsibilities in different folders, extract real helper classes in those folders and let the entry-point class call them. Keep Unity lifecycle entry points on the plugin/component and delegate the relevant work. Separately filed nested patch/helper classes should become complete classes in their existing folders; preserve hook registration and update their references and required internal access.
- Do not split a handwritten class across multiple `partial` files. Existing method-per-file layouts are not a convention to copy into new work.
- This rule applies during new-mod creation, migration, and ordinary development. When consolidating existing source, preserve attributes, interfaces, visibility, and behavior, update explicit project includes if needed, and verify the affected project builds. Keep unrelated source restructuring out of focused changes.

## Method responsibilities

- **One method, one function:** each method performs one clear job or responsibility. Here, "function" means what the method does; it does not mean a source file.
- A class can contain multiple methods in its single file. If a method does several independent jobs, extract focused helper methods and keep them in that same class file.
- Do not turn this rule into one method per file, one method per class, or a separate wrapper class for each function.

## Required source-layout check

Run `_AI/_Workflows/Tools/SourceLayout/Check-SourceLayout.ps1 -ModFolder <mod-root>` after source creation or reorganization. `BuildMod.ps1` runs this check before compiling or staging the mod. It rejects partial types and multiple top-level types in one file; it does not rewrite source. Review folder placement and each method's responsibility separately, then build the affected projects. Keep source backups and verification material under the mod's ignored `_AI/`.

Use explicit `src/**/*.cs` compile items with default compile discovery disabled. Verification-only source must be explicitly gated/excluded from the player build. Never let `_AI/` experiments, backups or checker build outputs become mod compile items.
