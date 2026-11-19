# Kingdom Inc. Local Mod Build Tool

The drag-and-drop build tool is located at:

`_Mods/_AI/_Workflows/Tools/BuildMod/BuildMod.cmd`

Drag `_Mods/{ModName}/` onto `BuildMod.cmd`. Do not drag the `src/` folder or a `.csproj` file.

## Build menu

1. Release - build with `dotnet build -c Release` and copy the compiled main DLL and `mod.json` to `{ModName}/Release/`.
2. Debug - build with `dotnet build -c Debug` and copy the compiled main DLL and `mod.json` to `{ModName}/Debug/`.

Projects and solutions must be in the mod root; source code belongs in `src/`. If more than one root project exists, select the one you want to build. The program uses MSBuild TargetPath to find the built DLL rather than guessing the assembly name.

Before compiling, `BuildMod.ps1` runs `Tools/SourceLayout/Check-SourceLayout.ps1`. It rejects partial types and multiple top-level types in a source file. Keep each complete class in its responsibility folder; see `../_shared/CODING_STANDARDS.md`. The checker needs the installed .NET 10 SDK and writes its own build outputs only under the selected mod's ignored `_AI/Scratch/SourceLayout/`. A failed check stops the build before staging or installation.

## Install menu

After a successful build:

1. Install - copy the DLL and `mod.json` to `KingdomInc/BepInEx/plugins/{ModName}/`.
2. Continue without install - keep only the local build copy.

The DLL and `mod.json` are copied rather than removed from the local output folder. Close the game before installing or replacing any in-use DLL.

## Release-only publishing

After a Release build, see `RELEASE.md` for optional manual publishing choices. Debug builds are not published by this tool. Neither build configuration automatically uploads files.

## Prerequisites

- Windows with PowerShell (included with Windows).
- .NET SDK and required game/mod assembly references installed.
- Game installed in the expected structure: `KingdomInc/_Mods/{ModName}/` and `KingdomInc/BepInEx/plugins/`.
- A `.csproj` in the mod root.

The script sets the MSBuild `GameRoot` property to the actual KingdomInc directory. Your project can use that value when referencing assemblies.

## .gitignore

The script ensures each mod root `.gitignore` includes these exact lines:

```gitignore
/Release/
/Debug/
```

The central `_Workflows/_ModTemplate/.gitignore` also has both exclusions. Keep `.gitignore` tracked on GitHub. If old build files are already tracked, new ignore rules alone do not remove them from Git history or the index; clean their tracking separately after review.

## Foundation SDK packaging

After a Foundation Release build has been staged in `Foundation/Release/`, run `Foundation/Tools/Build/Package-FoundationSdk.ps1` to create `Foundation-SDK-v{Version}.zip` beside the runtime package. It checks that the SDK library matches the staged runtime, includes the complete public guides and five examples, checks packaged documentation links, and builds all five examples from a clean extraction. Scratch and extraction folders stay under `Foundation/_AI/Scratch/` and are cleaned afterward. The SDK does not bundle game, Unity or BepInEx assemblies. This local packaging command does not publish either archive.

## Safety

- Build failure stops before copying a DLL.
- Installation requires selection 1.
- Publishing requires a Release build, selected destination, and the literal `PUBLISH` confirmation.
- Nexus upload requires a second `UPLOAD` confirmation.
- Build and installation never commit or push source code.
- GitHub Actions are not used.
- The script does not modify source files or project files.
- Release and Debug directories are local-only and never meant for source commits.

## Pipe Wrench runtime verification

With Kingdom Inc closed, `PipeWrench/Tools/Verify-Runtime.ps1` builds the separate `Foundation/PipeWrench.RuntimeVerification.csproj` helper and tests the installed Pipe Wrench toolbar lifecycle inside the actual game. The helper source is in `Foundation/src/Verification/`, outside the production source include. It uses an isolated test-save directory, restores Pipe Wrench config, checks user-save hashes and removes its temporary plugin and app-id file. Reports and Unity toolbar render captures go under `PipeWrench/_AI/Notes/Runtime-0.1.5/`. This local check does not publish either mod.
