# Kingdom Inc. drag-and-drop and CLI mod builder & publisher.
# Supports interactive menus (via BuildMod.cmd) and explicit CLI flags for agent/scripted execution.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ModFolder,
    [ValidateSet('', 'Release', 'Debug')][string]$Configuration = '',
    [switch]$Install,
    [switch]$SkipInstall,
    [ValidateSet('', 'All', 'GitHub', 'Nexus', 'NexusMetadataOnly', 'Skip')][string]$ReleaseMode = '',
    [switch]$ConfirmPublish,
    [switch]$ConfirmUpload,
    [switch]$AutoSelectMainFile,
    [switch]$SyncRepoMetadata,
    [switch]$UpdateExistingGithubRelease
)

$ErrorActionPreference = 'Stop'
$env:GIT_PAGER = 'cat'
$env:PAGER = 'cat'
$env:GH_PAGER = 'cat'

. (Join-Path $PSScriptRoot 'NexusFormat.ps1')

function Select-Choice {
    param([string]$Title, [string[]]$Choices)
    Write-Host ''
    Write-Host $Title
    for ($i = 0; $i -lt $Choices.Count; $i++) {
        Write-Host ("  {0}. {1}" -f ($i + 1), $Choices[$i])
    }
    while ($true) {
        $answer = (Read-Host 'Select').Trim()
        $index = 0
        if ([int]::TryParse($answer, [ref]$index) -and $index -ge 1 -and $index -le $Choices.Count) {
            return $index
        }
        Write-Host 'Invalid selection.' -ForegroundColor Yellow
    }
}

function Require-SafeVersion {
    param([string]$Value)
    if ($Value -notmatch '^[0-9A-Za-z][0-9A-Za-z.-]*$') {
        throw 'Publishing requires a real mod.json version containing only letters, digits, dots, and dashes.'
    }
    return $Value
}

function Add-IgnoreRules {
    param([string]$Root)
    $ignorePath = Join-Path $Root '.gitignore'
    if (-not (Test-Path -LiteralPath $ignorePath -PathType Leaf)) {
        [System.IO.File]::WriteAllText($ignorePath, "", ([System.Text.UTF8Encoding]::new($false)))
    }
    $current = [System.IO.File]::ReadAllText($ignorePath)
    $missing = @()
    foreach ($rule in @('/Release/', '/Debug/')) {
        if ($current -notmatch ('(?m)^\s*' + [regex]::Escape($rule) + '\s*$')) {
            $missing += $rule
        }
    }
    if ($missing.Count -gt 0) {
        $prefix = if ($current.Length -eq 0 -or $current.EndsWith("`n")) { '' } else { "`r`n" }
        [System.IO.File]::AppendAllText($ignorePath, $prefix + "# Local build outputs (never commit)`r`n" + (($missing -join "`r`n") + "`r`n"), ([System.Text.UTF8Encoding]::new($false)))
        Write-Host ('Updated .gitignore with: ' + ($missing -join ', '))
    }
}

function Get-BuiltDll {
    param([string]$Project, [string]$Configuration, [string]$GameRoot)
    $projectDirectory = Split-Path -Parent $Project
    $args = @('msbuild', $Project, '-nologo', "-p:Configuration=$Configuration", "-p:GameRoot=$GameRoot/", '-getProperty:TargetPath')
    $result = @(& dotnet @args 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "Could not locate the built DLL using MSBuild TargetPath:`n$($result -join "`n")"
    }
    $candidates = @($result | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ -match '(?i)\.dll$' })
    if ($candidates.Count -ne 1) {
        throw ('MSBuild did not return exactly one DLL TargetPath. Result: ' + ($result -join '; '))
    }
    $path = $candidates[0]
    if (-not [System.IO.Path]::IsPathRooted($path)) { $path = Join-Path $projectDirectory $path }
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Built DLL not found: $path" }
    return (Resolve-Path -LiteralPath $path).Path
}

function Create-ReleaseArchive {
    param([string]$Root, [string]$Name, [string]$Version, [string]$Dll)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $releaseDir = Join-Path $Root 'Release'
    $archiveName = ('{0}-v{1}.zip' -f ($Name -replace '[^a-zA-Z0-9._-]', '_'), $Version)
    $archive = Join-Path $releaseDir $archiveName
    $stage = Join-Path (Join-Path $Root '_AI') 'BuildStaging'
    if (Test-Path -LiteralPath $stage) {
        Remove-Item -LiteralPath $stage -Recurse -Force
    }
    try {
        $target = Join-Path (Join-Path (Join-Path $stage 'BepInEx') 'plugins') $Name
        New-Item -ItemType Directory -Path $target -Force | Out-Null
        Copy-Item -LiteralPath $Dll -Destination (Join-Path $target ([System.IO.Path]::GetFileName($Dll))) -Force
        $modJsonFile = Join-Path $Root 'mod.json'
        if (Test-Path -LiteralPath $modJsonFile -PathType Leaf) {
            Copy-Item -LiteralPath $modJsonFile -Destination (Join-Path $target 'mod.json') -Force
        }
        if (Test-Path -LiteralPath $archive -PathType Leaf) {
            Remove-Item -LiteralPath $archive -Force
        }
        [System.IO.Compression.ZipFile]::CreateFromDirectory($stage, $archive, [System.IO.Compression.CompressionLevel]::Optimal, $false)
        return $archive
    }
    finally {
        if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
    }
}

try {
    $root = (Resolve-Path -LiteralPath $ModFolder).Path.TrimEnd([char]'\', [char]'/')
    if (-not (Test-Path -LiteralPath $root -PathType Container)) { throw "Not a folder: $root" }
    $name = Split-Path -Leaf $root
    if ($name -in @('_AI', '_ModTemplate', '~tmp', 'Release', 'Debug')) { throw 'Drag the mod root folder, not a workspace/output folder.' }
    $modsRoot = Split-Path -Parent $root
    if ((Split-Path -Leaf $modsRoot) -ne '_Mods') { throw 'Expected the mod at KingdomInc\_Mods\{ModName}.' }
    $gameRoot = Split-Path -Parent $modsRoot
    $projects = @(Get-ChildItem -LiteralPath $root -File -Filter '*.csproj')
    if ($projects.Count -eq 0) { throw "No .csproj in the mod root. Project files belong outside src/: $root" }
    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) { throw 'dotnet CLI is not installed or not on PATH.' }

    Write-Host "Mod: $name"
    Write-Host "Location: $root"
    Write-Host "Game: $gameRoot"

    if ($projects.Count -eq 1) {
        $project = $projects[0].FullName
    }
    else {
        $idx = Select-Choice 'Select the project to build' @($projects | ForEach-Object { $_.Name })
        $project = $projects[$idx - 1].FullName
    }

    if ([string]::IsNullOrWhiteSpace($Configuration)) {
        $buildMode = Select-Choice 'Build configuration' @('Release', 'Debug')
        $configuration = if ($buildMode -eq 1) { 'Release' } else { 'Debug' }
    }
    else {
        $configuration = $Configuration
    }

    & (Join-Path $PSScriptRoot '..\SourceLayout\Check-SourceLayout.ps1') -ModFolder $root

    Write-Host "`nBuilding {$configuration}: $project"
    & dotnet build $project --configuration $configuration --nologo "-p:GameRoot=$gameRoot/"
    if ($LASTEXITCODE -ne 0) { throw 'Build failed. No DLL has been copied or installed.' }
    $dllPath = Get-BuiltDll -Project $project -Configuration $configuration -GameRoot $gameRoot
    Add-IgnoreRules -Root $root
    $outputFolder = Join-Path $root $configuration
    New-Item -ItemType Directory -Path $outputFolder -Force | Out-Null
    $outputDll = Join-Path $outputFolder ([System.IO.Path]::GetFileName($dllPath))
    Copy-Item -LiteralPath $dllPath -Destination $outputDll -Force
    Write-Host "`nCopied build DLL: $outputDll" -ForegroundColor Green
    $rootModJson = Join-Path $root 'mod.json'
    if (Test-Path -LiteralPath $rootModJson -PathType Leaf) {
        $outputModJson = Join-Path $outputFolder 'mod.json'
        Copy-Item -LiteralPath $rootModJson -Destination $outputModJson -Force
        Write-Host "Copied mod.json: $outputModJson" -ForegroundColor Green
    }

    $doInstall = $false
    if ($Install) {
        $doInstall = $true
    }
    elseif ($SkipInstall) {
        $doInstall = $false
    }
    else {
        $installChoice = Select-Choice 'Install to Kingdom Inc?' @('Install', 'Continue without install')
        $doInstall = ($installChoice -eq 1)
    }

    $pluginDir = Join-Path (Join-Path (Join-Path $gameRoot 'BepInEx') 'plugins') $name
    if ($doInstall) {
        $pluginRoot = Join-Path (Join-Path $gameRoot 'BepInEx') 'plugins'
        if (-not (Test-Path -LiteralPath $pluginRoot -PathType Container)) {
            throw "BepInEx plugins folder is missing: $pluginRoot"
        }
        New-Item -ItemType Directory -Path $pluginDir -Force | Out-Null
        $installedDll = Join-Path $pluginDir ([System.IO.Path]::GetFileName($outputDll))
        try {
            Copy-Item -LiteralPath $outputDll -Destination $installedDll -Force -ErrorAction Stop
            Write-Host "Installed: $installedDll" -ForegroundColor Green
        }
        catch {
            Write-Warning "Could not overwrite $installedDll (Kingdom Inc. may be running): $($_.Exception.Message). Using $outputDll for release packaging."
        }
        if (Test-Path -LiteralPath $rootModJson -PathType Leaf) {
            $installedModJson = Join-Path $pluginDir 'mod.json'
            try {
                Copy-Item -LiteralPath $rootModJson -Destination $installedModJson -Force -ErrorAction Stop
                Write-Host "Installed: $installedModJson" -ForegroundColor Green
            }
            catch {
                Write-Warning "Could not overwrite $installedModJson`: $($_.Exception.Message)"
            }
        }
    }
    else { Write-Host 'Installation skipped.' }

    if ($configuration -eq 'Debug') {
        Write-Host 'Debug build complete. Debug builds are not offered for public release.'
        exit 0
    }

    if ([string]::IsNullOrWhiteSpace($ReleaseMode)) {
        $modeIdx = Select-Choice 'Public release options' @(
            'Release to all (GitHub + Nexus file & metadata)',
            'Release to GitHub',
            'Release to Nexus (file + page metadata)',
            'Sync Nexus page metadata only (no binary upload)',
            'Skip publishing'
        )
        $ReleaseMode = switch ($modeIdx) {
            1 { 'All' }
            2 { 'GitHub' }
            3 { 'Nexus' }
            4 { 'NexusMetadataOnly' }
            default { 'Skip' }
        }
    }

    if ($ReleaseMode -eq 'Skip') {
        Write-Host 'Release build complete. Nothing published.'
        exit 0
    }

    $modJsonPath = Join-Path $root 'mod.json'
    if (-not (Test-Path -LiteralPath $modJsonPath -PathType Leaf)) { throw 'mod.json is required to publish. Build and installation already completed.' }

    # Sync & validate README.md and Nexus/DESCRIPTION.bbcode.txt before packaging
    $null = Sync-ModPublicDocs -ModFolder $root

    $metadata = Get-Content -LiteralPath $modJsonPath -Raw | ConvertFrom-Json
    $version = Require-SafeVersion -Value ([string]$metadata.version)
    $changelog = Join-Path (Join-Path $root 'Nexus') 'CHANGELOG.md'
    if (-not (Test-Path -LiteralPath $changelog -PathType Leaf)) { throw "Missing player-facing changelog: $changelog" }

    $isGithub = $ReleaseMode -in @('All', 'GitHub')
    $isNexus = $ReleaseMode -in @('All', 'Nexus', 'NexusMetadataOnly')
    $nexusMetadataOnly = ($ReleaseMode -eq 'NexusMetadataOnly')

    if ($isGithub) {
        $repo = [string]$metadata.repository.url
        if ($repo -notmatch '^https://github\.com/[a-zA-Z0-9-]+/[a-zA-Z0-9_.-]+/?$') { throw 'mod.json repository.url must be a verified GitHub repository URL.' }
        if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { throw 'GitHub CLI (gh) is needed for GitHub releases.' }
        $null = & gh auth status *> $null
        if ($LASTEXITCODE -ne 0) { throw 'GitHub CLI is not authenticated. Run gh auth login first.' }
    }
    if ($isNexus) {
        $nexus = $metadata.distribution.nexus
        if ($null -eq $nexus -or ([string]$nexus.modId) -notmatch '^\d+$') {
            throw 'Nexus publishing requires distribution.nexus.modId in mod.json.'
        }
        if ([string]$nexus.game -notmatch '^[a-z0-9-]+$') { throw 'Invalid distribution.nexus.game in mod.json.' }
    }

    Write-Host "`nPublishing destination(s):"
    if ($isGithub) { Write-Host "  GitHub: $($metadata.repository.url)" }
    if ($isNexus) { Write-Host "  Nexus: $($metadata.distribution.nexus.url) (ID $($metadata.distribution.nexus.modId), Mode: $ReleaseMode)" }
    Write-Host "  Version: $version"
    Write-Host '  Source: RELEASE DLL (never Debug)'

    if (-not $ConfirmPublish) {
        $authorization = (Read-Host 'Type PUBLISH to authorize these remote release actions').Trim()
        if ($authorization -cne 'PUBLISH') { Write-Host 'Publishing cancelled.'; exit 0 }
    }

    $archive = Create-ReleaseArchive -Root $root -Name $name -Version $version -Dll $outputDll
    Write-Host "Release archive: $archive"

    $publishedGithub = $false
    if ($isGithub) {
        $ghArgs = @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass',
            '-File', (Join-Path $PSScriptRoot 'PublishGithub.ps1'),
            '-RepositoryUrl', $repo,
            '-Version', $version,
            '-Archive', $archive,
            '-Changelog', $changelog,
            '-ModJson', $modJsonPath,
            '-Approved'
        )
        if ($SyncRepoMetadata) { $ghArgs += '-SyncRepoMetadata' }
        if ($UpdateExistingGithubRelease) { $ghArgs += '-UpdateExisting' }
        & powershell.exe @ghArgs
        if ($LASTEXITCODE -ne 0) { throw 'GitHub release failed. Nexus publishing was not started.' }
        $publishedGithub = $true
    }

    if ($isNexus) {
        try {
            $nxArgs = @(
                '-NoProfile', '-ExecutionPolicy', 'Bypass',
                '-File', (Join-Path $PSScriptRoot 'PublishNexus.ps1'),
                '-ModJson', $modJsonPath,
                '-Archive', $archive,
                '-ModName', $name,
                '-Version', $version,
                '-Approved'
            )
            if ($ConfirmUpload) { $nxArgs += '-ConfirmUpload' }
            if ($AutoSelectMainFile) { $nxArgs += '-AutoSelectMainFile' }
            if ($nexusMetadataOnly) { $nxArgs += '-MetadataOnly' }
            & powershell.exe @nxArgs
            if ($LASTEXITCODE -ne 0) { throw 'Nexus publishing did not complete.' }
        }
        catch {
            if ($publishedGithub) { Write-Warning 'GitHub release succeeded; Nexus failed. Inspect both destinations before retrying.' }
            throw
        }
    }

    # Refresh staged & installed mod.json copies after publishing updated mod.json state
    if (Test-Path -LiteralPath $rootModJson -PathType Leaf) {
        Copy-Item -LiteralPath $rootModJson -Destination (Join-Path $outputFolder 'mod.json') -Force
        if ($doInstall -and (Test-Path -LiteralPath $pluginDir -PathType Container)) {
            Copy-Item -LiteralPath $rootModJson -Destination (Join-Path $pluginDir 'mod.json') -Force
        }
    }

    Write-Host 'Selected publishing operations completed.' -ForegroundColor Green
    exit 0
}
catch {
    Write-Host ('ERROR: ' + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
