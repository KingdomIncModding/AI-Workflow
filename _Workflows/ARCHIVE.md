# Mod Archive Workflow

## Trigger

When the user says **"Archive"**, archive the mod currently being worked on. When the user says **"Archive {ModName}"**, archive that specific mod.

This is a **move**, not a copy. Do not rebuild, refactor, clean, reformat, or otherwise change the mod's files as part of archiving.

## Paths

**Active mods root:**

```text
<KingdomIncDir>\_Mods
```

**Source mod directory:**

```text
<KingdomIncDir>\_Mods\{ModName}
```

**Archive destination:**

```text
<KingdomIncDir>\_Mods\_Archived\{ModName}\{Version}\
```

`{ModName}` is the existing mod folder name. `{Version}` is the mod's actual declared version, without inventing or incrementing it. Resolve it from the mod's authoritative source metadata (for example, its BepInEx plugin version or project version). If the version cannot be determined reliably, request the version before moving anything.

## Required behavior

1. Identify the target mod from the command or the active mod context. Do not guess if multiple mods are possible.
2. Confirm that `_Mods\{ModName}` exists and is a mod source/project directory. Never treat `_Archived` itself as a mod.
3. Determine `{Version}` from the existing mod files. Do not change the version during archiving.
4. Check whether `_Archived\{ModName}\{Version}` already exists. **If it does, stop**; never overwrite, merge, or silently rename an archive.
5. Create `_Archived\{ModName}\` if needed.
6. **Move the entire `_Mods\{ModName}` directory** to `_Archived\{ModName}\{Version}`. This preserves everything *inside* the original mod folder—source code, project files, documentation, assets, subdirectories, and hidden files—at the same relative paths. The original `_Mods\{ModName}` folder is no longer present after a successful move.
7. Report the mod name, version, and resulting archive path. If the move fails, report the error rather than claiming success.

Only the selected mod source directory is affected. Do not move files belonging to another mod, change the installed game's files, or touch anything already in `_Archived`.

## Example

Before:

```text
_Mods\
├── ExampleMod\
│   ├── src\
│   │   └── ExampleModPlugin.cs
│   ├── ExampleMod.csproj
│   └── README.md
└── _Archived\
```

After **Archive ExampleMod** (if its declared version is `1.2.0`):

```text
_Mods\
└── _Archived\
    └── ExampleMod\
        └── 1.2.0\
            ├── src\
            │   └── ExampleModPlugin.cs
            ├── ExampleMod.csproj
            └── README.md
```

## PowerShell move operation

After identifying the mod and resolving its real version, use an equivalent of the following operation. The example deliberately refuses to overwrite an existing archive.

```powershell
$modsRoot = '<KingdomIncDir>\_Mods'
$modName  = 'ExampleMod'  # Replace with the selected mod directory name
$version  = '1.2.0'     # Replace with the version read from the mod source

$source      = Join-Path $modsRoot $modName
$archiveRoot = Join-Path (Join-Path $modsRoot '_Archived') $modName
$destination = Join-Path $archiveRoot $version

if ($modName -in @('', '.', '..', '_Archived') -or
    $modName -match '[\\/]' -or
    $version -in @('', '.', '..') -or
    $version -match '[\\/]') {
    throw 'Invalid mod name or version.'
}
if (-not (Test-Path -LiteralPath $source -PathType Container)) {
    throw "Mod source folder not found: $source"
}
if (Test-Path -LiteralPath $destination) {
    throw "Archive already exists; nothing moved: $destination"
}

New-Item -ItemType Directory -Path $archiveRoot -Force | Out-Null
Move-Item -LiteralPath $source -Destination $destination -ErrorAction Stop
Write-Output "Archived $modName ($version) to $destination"
```

**Important:** Moving the directory, rather than moving individual `src` files, preserves the exact original folder contents and structure and leaves no partially populated source folder behind when successful.
