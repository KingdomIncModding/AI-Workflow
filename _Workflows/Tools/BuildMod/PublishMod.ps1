# PublishMod.ps1 - Single-command orchestrator for preparing, building, pushing source,
# and publishing a single Kingdom Inc. mod to GitHub and Nexus Mods.
# Strictly scoped to -ModFolder; never reads other mods or OpenAPI specs.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ModFolder,
    [ValidateSet('All', 'GitHub', 'Nexus', 'NexusMetadataOnly', 'VerifyOnly', 'LocalPrepOnly')][string]$Target = 'All',
    [switch]$PushSource,
    [bool]$Install = $true,
    [switch]$SyncRepoMetadata,
    [switch]$UpdateExistingGithubRelease,
    [switch]$ForceRegenerateBBCode,
    [switch]$ConfirmReplace,
    [switch]$ConfirmPublish,
    [switch]$ConfirmUpload
)

$ErrorActionPreference = 'Stop'
$env:GIT_PAGER = 'cat'
$env:PAGER = 'cat'
$env:GH_PAGER = 'cat'

. (Join-Path $PSScriptRoot 'NexusFormat.ps1')

function Clear-ModBinObj {
    param([Parameter(Mandatory)][string]$ModRoot)
    $removed = 0
    $dirs = @(Get-ChildItem -LiteralPath $ModRoot -Directory -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -in @('bin', 'obj') -and $_.FullName -notmatch '[\\/]_AI[\\/]' })
    foreach ($d in $dirs) {
        if (Test-Path -LiteralPath $d.FullName -PathType Container) {
            Remove-Item -LiteralPath $d.FullName -Recurse -Force
            $removed++
        }
    }
    Write-Host "Cleaned $removed bin/obj folder(s) in $(Split-Path -Leaf $ModRoot)." -ForegroundColor Cyan
}

function Push-ModSourceRepo {
    param(
        [Parameter(Mandatory)][string]$ModRoot,
        [Parameter(Mandatory)][string]$ModJsonPath,
        [switch]$Confirmed
    )
    if (-not $Confirmed) {
        $ans = (Read-Host "Type REPLACE to push clean source repository for $(Split-Path -Leaf $ModRoot) to GitHub").Trim()
        if ($ans -cne 'REPLACE') {
            throw 'Source repository push cancelled.'
        }
    }
    $replaceScript = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\_GitHub\RepoReplace\ReplaceRepo.ps1'))
    if (-not (Test-Path -LiteralPath $replaceScript -PathType Leaf)) {
        throw "ReplaceRepo.ps1 not found at: $replaceScript"
    }
    Clear-ModBinObj -ModRoot $ModRoot
    # Pipe REPLACE into ReplaceRepo.ps1 when explicitly confirmed
    'REPLACE' | & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $replaceScript -ModFolder $ModRoot
    if ($LASTEXITCODE -ne 0) {
        throw "ReplaceRepo.ps1 failed with exit code $LASTEXITCODE."
    }
}

try {
    $root = (Resolve-Path -LiteralPath $ModFolder).Path.TrimEnd([char]'\', [char]'/')
    if (-not (Test-Path -LiteralPath $root -PathType Container)) { throw "Mod folder not found: $root" }
    $modName = Split-Path -Leaf $root
    $modJsonPath = Join-Path $root 'mod.json'
    if (-not (Test-Path -LiteralPath $modJsonPath -PathType Leaf)) { throw "Missing mod.json: $modJsonPath" }

    Write-Host "=== PublishMod: $modName (Target: $Target) ===" -ForegroundColor Cyan

    # Step 1: Sync & validate README.md, Nexus/*.md, and Nexus/DESCRIPTION.bbcode.txt
    $isVerifyOnly = ($Target -eq 'VerifyOnly')
    $docSync = Sync-ModPublicDocs -ModFolder $root -ForceRegenerateBBCode:$ForceRegenerateBBCode -ValidateOnly:$isVerifyOnly
    Write-Host "1. Docs & BBCode verified (SHA256: $($docSync.ReadmeHash.Substring(0, 12)), Color spans: $($docSync.ColorSpanCount))" -ForegroundColor Green

    $meta = Get-Content -LiteralPath $modJsonPath -Raw | ConvertFrom-Json
    $version = [string]$meta.version
    if ([string]::IsNullOrWhiteSpace($version)) { throw "mod.json version is empty in $modJsonPath" }
    $changelogPath = Join-Path (Join-Path $root 'Nexus') 'CHANGELOG.md'
    $clCheck = Get-ModVersionChangelog -ChangelogPath $changelogPath -Version $version
    Write-Host "2. Changelog verified for v$version ($($clCheck.EntryCount) bullet entries)" -ForegroundColor Green

    if ($Target -eq 'VerifyOnly') {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'PublishNexus.ps1') -ModJson $modJsonPath -ModName $modName -Version $version -VerifyOnly
        exit $LASTEXITCODE
    }

    if ($Target -eq 'LocalPrepOnly') {
        $buildArgs = @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass',
            '-File', (Join-Path $PSScriptRoot 'BuildMod.ps1'),
            '-ModFolder', $root,
            '-Configuration', 'Release',
            '-ReleaseMode', 'Skip'
        )
        if ($Install) { $buildArgs += '-Install' } else { $buildArgs += '-SkipInstall' }
        & powershell.exe @buildArgs
        exit $LASTEXITCODE
    }

    # Step 2: Optional GitHub source repository replacement push
    if ($PushSource) {
        Push-ModSourceRepo -ModRoot $root -ModJsonPath $modJsonPath -Confirmed:$ConfirmReplace
    }

    # Step 3: Build Release, Install, Package ZIP, and Publish to Target(s)
    $buildArgs = @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass',
        '-File', (Join-Path $PSScriptRoot 'BuildMod.ps1'),
        '-ModFolder', $root,
        '-Configuration', 'Release',
        '-ReleaseMode', $Target,
        '-AutoSelectMainFile'
    )
    if ($Install) { $buildArgs += '-Install' } else { $buildArgs += '-SkipInstall' }
    if ($ConfirmPublish) { $buildArgs += '-ConfirmPublish' }
    if ($ConfirmUpload) { $buildArgs += '-ConfirmUpload' }
    if ($SyncRepoMetadata) { $buildArgs += '-SyncRepoMetadata' }
    if ($UpdateExistingGithubRelease) { $buildArgs += '-UpdateExistingGithubRelease' }

    & powershell.exe @buildArgs
    if ($LASTEXITCODE -ne 0) {
        throw "BuildMod.ps1 exited with code $LASTEXITCODE."
    }

    # If mod.json changed during publishing and -PushSource was requested, sync updated mod.json to GitHub
    if ($PushSource) {
        Write-Host "Syncing updated mod.json release metadata to GitHub source repository..." -ForegroundColor Cyan
        Push-ModSourceRepo -ModRoot $root -ModJsonPath $modJsonPath -Confirmed:$ConfirmReplace
    }

    # Print final summary from mod.json and LastPublishReceipt.json
    $finalMeta = Get-Content -LiteralPath $modJsonPath -Raw | ConvertFrom-Json
    $receiptPath = Join-Path (Join-Path (Join-Path $root '_AI') 'Notes') 'LastPublishReceipt.json'
    $receipt = if (Test-Path -LiteralPath $receiptPath -PathType Leaf) { Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json } else { $null }

    Write-Host "`n=== PUBLISH SUMMARY: $modName v$version ===" -ForegroundColor Green
    Write-Host "  GitHub Repo       : $($finalMeta.repository.url) (latestTag: $($finalMeta.repository.latestTag))"
    Write-Host "  GitHub Release    : $($finalMeta.publishing.githubReleases)"
    Write-Host "  Nexus Page        : $($finalMeta.distribution.nexus.url) (ModID: $($finalMeta.distribution.nexus.modId), FileID: $($finalMeta.distribution.nexus.fileId))"
    if ($receipt) {
        Write-Host "  Nexus Release     : $($receipt.releaseState) (VersionID: $($receipt.nexusVersionId), Scan: $($receipt.securityScanStatus))"
        Write-Host "  Nexus Colors      : $($receipt.descriptionColorStatus) ($($receipt.colorSpanCount) spans)"
    }
    Write-Host "  Tags Verified     : $($finalMeta.distribution.nexus.tagsVerified)"
    Write-Host "  Reqs Verified     : $($finalMeta.distribution.nexus.requirementsVerified)"
    exit 0
}
catch {
    Write-Host ('PUBLISHMOD ERROR: ' + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
