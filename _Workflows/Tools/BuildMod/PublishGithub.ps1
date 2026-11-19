# PublishGithub.ps1 - Local-only GitHub release publisher with version-scoped notes,
# read-after-write asset verification, and automatic mod.json state updates.
# Never invoked without explicit approval.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RepositoryUrl,
    [Parameter(Mandatory)][string]$Version,
    [Parameter(Mandatory)][string]$Archive,
    [Parameter(Mandatory)][string]$Changelog,
    [string]$ModJson,
    [switch]$SyncRepoMetadata,
    [switch]$UpdateExisting,
    [switch]$Approved
)

$ErrorActionPreference = 'Stop'
$env:GH_PROMPT_DISABLED = '1'
$env:GH_PAGER = 'cat'

. (Join-Path $PSScriptRoot 'NexusFormat.ps1')

$tempNotesFile = $null
try {
    if (-not $Approved) { throw 'Explicit publishing approval is required.' }
    if ($RepositoryUrl -notmatch '^https://github\.com/([a-zA-Z0-9-]+)/([a-zA-Z0-9_.-]+)/?$') {
        throw "Invalid GitHub repository URL: $RepositoryUrl"
    }
    $repo = "$($Matches[1])/$($Matches[2])"
    if (-not (Test-Path -LiteralPath $Archive -PathType Leaf)) { throw "Missing archive: $Archive" }
    if (-not (Test-Path -LiteralPath $Changelog -PathType Leaf)) { throw "Missing changelog: $Changelog" }

    $modRoot = Split-Path -Parent (Split-Path -Parent (Resolve-Path -LiteralPath $Changelog).Path)
    if ([string]::IsNullOrWhiteSpace($ModJson)) {
        $candidateModJson = Join-Path $modRoot 'mod.json'
        if (Test-Path -LiteralPath $candidateModJson -PathType Leaf) {
            $ModJson = $candidateModJson
        }
    }

    $tag = 'v' + $Version.TrimStart('v', 'V')
    $archiveItem = Get-Item -LiteralPath $Archive
    $archiveName = $archiveItem.Name
    $expectedSize = $archiveItem.Length

    # Verify repository identity
    $repoViewRaw = & gh repo view $repo --json nameWithOwner,url,defaultBranchRef 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Could not verify GitHub repository: $repo. $repoViewRaw" }
    $repoView = ($repoViewRaw -join "`n") | ConvertFrom-Json
    if ([string]$repoView.nameWithOwner -ine $repo) {
        throw "GitHub resolved a different repository ($($repoView.nameWithOwner)); publishing cancelled."
    }

    # Optional repository metadata sync (description, homepage, topics)
    if ($SyncRepoMetadata -and -not [string]::IsNullOrWhiteSpace($ModJson) -and (Test-Path -LiteralPath $ModJson -PathType Leaf)) {
        $metaForRepo = Get-Content -LiteralPath $ModJson -Raw | ConvertFrom-Json
        $editArgs = @('repo', 'edit', $repo)
        $hasEdit = $false
        if (-not [string]::IsNullOrWhiteSpace([string]$metaForRepo.description)) {
            $editArgs += @('--description', ([string]$metaForRepo.description))
            $hasEdit = $true
        }
        if ($metaForRepo.distribution -and $metaForRepo.distribution.nexus -and -not [string]::IsNullOrWhiteSpace([string]$metaForRepo.distribution.nexus.url)) {
            $editArgs += @('--homepage', ([string]$metaForRepo.distribution.nexus.url))
            $hasEdit = $true
        }
        if ($metaForRepo.repository -and $metaForRepo.repository.topics) {
            foreach ($topic in @($metaForRepo.repository.topics)) {
                if (-not [string]::IsNullOrWhiteSpace([string]$topic)) {
                    $editArgs += @('--add-topic', ([string]$topic).Trim())
                    $hasEdit = $true
                }
            }
        }
        if ($hasEdit) {
            Write-Host "Syncing GitHub repository metadata for $repo..."
            $null = & gh @editArgs 2>&1
        }
    }

    # Extract version-specific release notes
    $scratchDir = Join-Path (Join-Path $modRoot '_AI') 'Scratch'
    if (-not (Test-Path -LiteralPath $scratchDir -PathType Container)) {
        New-Item -ItemType Directory -Path $scratchDir -Force | Out-Null
    }
    $tempNotesFile = Join-Path $scratchDir "github_release_notes_$tag.md"
    $parsedChangelog = Get-ModVersionChangelog -ChangelogPath $Changelog -Version $Version
    Save-Utf8NoBom -Path $tempNotesFile -Content $parsedChangelog.GithubNotes

    # Check if release tag already exists
    $existingRaw = & gh release list --repo $repo --limit 1000 --json tagName 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Could not inspect existing releases: $existingRaw" }
    $list = @(($existingRaw -join "`n") | ConvertFrom-Json)
    $exists = (@($list | Where-Object { $_.tagName -eq $tag }).Count -gt 0)

    if ($exists) {
        if (-not $UpdateExisting) {
            throw "GitHub release $tag already exists on $repo. Pass -UpdateExisting to update its asset/notes, or bump the version."
        }
        Write-Host "Updating existing GitHub release $tag on $repo..."
        & gh release upload $tag $Archive --repo $repo --clobber
        if ($LASTEXITCODE -ne 0) { throw "gh release upload --clobber failed for $tag." }
        & gh release edit $tag --repo $repo --title $tag --notes-file $tempNotesFile
        if ($LASTEXITCODE -ne 0) { throw "gh release edit failed for $tag." }
    }
    else {
        Write-Host "Publishing $tag to GitHub $repo..."
        & gh release create $tag $Archive --repo $repo --title $tag --notes-file $tempNotesFile
        if ($LASTEXITCODE -ne 0) { throw 'gh release create failed.' }
    }

    # Read-after-write verification
    $verifyRaw = & gh release view $tag --repo $repo --json url,tagName,isDraft,assets 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Read-after-write verification failed for GitHub release $tag`: $verifyRaw" }
    $verified = ($verifyRaw -join "`n") | ConvertFrom-Json
    if ($verified.isDraft) { throw "GitHub release $tag is still marked as draft." }
    $matchedAsset = @($verified.assets | Where-Object { $_.name -eq $archiveName }) | Select-Object -First 1
    if ($null -eq $matchedAsset) {
        throw "GitHub release $tag does not contain expected asset '$archiveName'."
    }
    if ([int64]$matchedAsset.size -ne $expectedSize) {
        throw "GitHub asset '$archiveName' size mismatch: expected $expectedSize bytes, got $($matchedAsset.size) bytes."
    }

    # Persist verified state to mod.json
    if (-not [string]::IsNullOrWhiteSpace($ModJson) -and (Test-Path -LiteralPath $ModJson -PathType Leaf)) {
        $meta = Get-Content -LiteralPath $ModJson -Raw | ConvertFrom-Json
        if ($meta.repository) {
            $meta.repository.latestTag = $tag
        }
        if ($meta.publishing) {
            $meta.publishing.githubReleases = [string]$verified.url
        }
        Save-ModJson -Path $ModJson -Metadata $meta
        Write-Host "Updated mod.json: repository.latestTag = $tag, publishing.githubReleases = $($verified.url)" -ForegroundColor Cyan
    }

    Write-Host "GITHUB_PUBLISHED_VERIFIED: $($verified.url) ($archiveName, $expectedSize bytes)" -ForegroundColor Green
    exit 0
}
catch {
    Write-Host ('GITHUB ERROR: ' + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
finally {
    if ($tempNotesFile -and (Test-Path -LiteralPath $tempNotesFile -PathType Leaf)) {
        Remove-Item -LiteralPath $tempNotesFile -Force -ErrorAction SilentlyContinue
    }
}
