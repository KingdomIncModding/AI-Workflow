# PublishNexus.ps1 - Complete Nexus Mods v3 publisher & verifier.
# Handles single-part file uploads, version creation (with update_mod_version & archive_existing_file),
# file-level dependency linking, BBCode description & summary PATCH, version changelog append,
# read-after-write verification (file, BBCode colors, tags, dependencies), and mod.json updates.
# Scoped strictly to a single mod. Never reads other mods or OpenAPI specs.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ModJson,
    [string]$Archive,
    [string]$ModName,
    [string]$Version,
    [switch]$Approved,
    [switch]$ConfirmUpload,
    [switch]$AutoSelectMainFile,
    [switch]$CreateNewFile,
    [ValidateSet('main', 'optional')][string]$FileCategory = 'main',
    [bool]$UpdateModVersion = $true,
    [bool]$PrimaryModManagerDownload = $true,
    [string]$PageDescriptionPath,
    [switch]$PreservePageSummary,
    [bool]$UpdatePageMetadata = $true,
    [bool]$ArchiveExistingFile = $true,
    [switch]$MetadataOnly,
    [switch]$VerifyOnly,
    [switch]$ForceChangelogAppend
)

$ErrorActionPreference = 'Stop'
$base = 'https://api.nexusmods.com/v3'

. (Join-Path $PSScriptRoot 'NexusFormat.ps1')

function Get-NexusApiKey {
    foreach ($varName in @('NEXUS_API_KEY', 'NEXUSMODS_API_KEY')) {
        foreach ($scope in @('Process', 'User', 'Machine')) {
            $val = [Environment]::GetEnvironmentVariable($varName, $scope)
            if (-not [string]::IsNullOrWhiteSpace($val)) {
                return $val.Trim()
            }
        }
    }
    $secure = Read-Host 'Nexus API key (not saved)' -AsSecureString
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { return ([Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)).Trim() }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
}

function Invoke-Nexus {
    param([string]$Method, [string]$Path, $Body = $null)
    $params = @{
        Uri            = $base + $Path
        Method         = $Method
        Headers        = @{ 'apikey' = $script:apiKey; 'Accept' = 'application/json' }
        ErrorAction    = 'Stop'
        UseBasicParsing = $true
    }
    if ($null -ne $Body) {
        $params.ContentType = 'application/json; charset=utf-8'
        $jsonText = ConvertTo-Json -InputObject $Body -Depth 12 -Compress
        $params.Body = [System.Text.Encoding]::UTF8.GetBytes($jsonText)
    }
    return Invoke-RestMethod @params
}

function Resolve-NexusCreatedFile {
    param([string]$ModUid, [string]$CreatedId, [string]$ExpectedVersion, [string[]]$KnownFileIds)
    # POST /mod-files may return a version ID. Resolve against the mod's
    # authoritative file list rather than treating that ID as a file group.
    $listed = Invoke-Nexus -Method 'Get' -Path "/mods/$ModUid/files"
    $newGroups = @($listed.data.mod_files | Where-Object {
        $null -ne $_ -and $KnownFileIds -notcontains [string]$_.id
    })
    $matches = @()
    $fallback = @()
    foreach ($group in $newGroups) {
        $versions = Invoke-Nexus -Method 'Get' -Path "/mod-files/$($group.id)/versions"
        foreach ($version in @($versions.data.versions | Where-Object { $null -ne $_ })) {
            if ([string]$version.version -ne $ExpectedVersion) { continue }
            $resolved = [pscustomobject]@{ FileId = [string]$group.id; VersionId = [string]$version.id }
            if ([string]$group.id -eq $CreatedId -or [string]$version.id -eq $CreatedId) {
                $matches += $resolved
            }
            if ($newGroups.Count -eq 1) { $fallback += $resolved }
        }
    }
    if ($matches.Count -eq 1) { return $matches[0] }
    if ($matches.Count -eq 0 -and $fallback.Count -eq 1) { return $fallback[0] }
    throw 'Nexus accepted the upload but the created file/version could not be uniquely resolved. Inspect NexusUploadReceipt.json and live file groups before retrying; do not upload again.'
}

function Resolve-NexusRequiredVersion {
    param($Requirement, $RequiredMod)
    $primary = $null
    if ($RequiredMod.main_file_version.id) {
        $primary = (Invoke-Nexus -Method 'Get' -Path "/mod-file-versions/$($RequiredMod.main_file_version.id)").data
    }
    $requiredFileId = [string]$Requirement.FileId
    if ([string]::IsNullOrWhiteSpace($requiredFileId) -and $primary) {
        $requiredFileId = [string]$primary.file.id
    }
    if ([string]::IsNullOrWhiteSpace($requiredFileId)) {
        throw "No unambiguous required file was configured for $($Requirement.Name)."
    }
    $minimum = [string]$Requirement.MinimumVersion
    $chosen = $null
    if ($primary -and [string]$primary.file.id -eq $requiredFileId -and
        ([string]::IsNullOrWhiteSpace($minimum) -or [string]$primary.version -eq $minimum)) {
        $chosen = $primary
    }
    else {
        $versions = Invoke-Nexus -Method 'Get' -Path "/mod-files/$requiredFileId/versions"
        $candidate = @($versions.data.versions | Where-Object {
            $null -ne $_ -and $_.category -notin @('archived', 'removed') -and
            ([string]::IsNullOrWhiteSpace($minimum) -or [string]$_.version -eq $minimum)
        } | Sort-Object -Property @{Expression={ [DateTimeOffset]$_.uploaded_at };Descending=$true}) | Select-Object -First 1
        if ($candidate) {
            $chosen = (Invoke-Nexus -Method 'Get' -Path "/mod-file-versions/$($candidate.id)").data
        }
    }
    if (-not $chosen -or [string]$chosen.file.id -ne $requiredFileId -or
        (-not [string]::IsNullOrWhiteSpace($minimum) -and [string]$chosen.version -ne $minimum)) {
        throw "Required file $requiredFileId has no available $minimum version for $($Requirement.Name)."
    }
    [pscustomobject]@{ FileId=$requiredFileId; VersionId=[string]$chosen.id }
}

function Get-NexusMissingRequirements {
    param($Response, [object[]]$Requirements)
    # This endpoint returns definitions at the root; accept an enveloped
    # response too. A matching mod/version can still be the SDK, so verify both
    # the target file group and the minimum version's owning file group.
    $definitions = if ($null -ne $Response.dependency_definitions) {
        @($Response.dependency_definitions)
    }
    else { @($Response.data.dependency_definitions) }
    foreach ($requirement in $Requirements) {
        $ranges = @($definitions | ForEach-Object { $_.ranges } | Where-Object {
            [string]$_.target_mod_file.mod.game.domain_name -eq [string]$requirement.Game -and
            [string]$_.target_mod_file.mod.game_scoped_id -eq [string]$requirement.ModId -and
            ([string]::IsNullOrWhiteSpace([string]$requirement.FileId) -or
                ([string]$_.target_mod_file.id -eq [string]$requirement.FileId -and
                 [string]$_.min_version.file.id -eq [string]$requirement.FileId)) -and
            ([string]::IsNullOrWhiteSpace([string]$requirement.MinimumVersion) -or
                [string]$_.min_version.version -eq [string]$requirement.MinimumVersion)
        })
        if ($ranges.Count -eq 0) { [string]$requirement.Name }
    }
}

try {
    if (-not $VerifyOnly -and -not $Approved) {
        throw 'Explicit publishing approval (-Approved) is required.'
    }
    if (-not (Test-Path -LiteralPath $ModJson -PathType Leaf)) {
        throw "Missing mod.json: $ModJson"
    }
    $ModJson = (Resolve-Path -LiteralPath $ModJson).Path
    $modRoot = Split-Path -Parent $ModJson
    $meta = Get-Content -LiteralPath $ModJson -Raw | ConvertFrom-Json

    # Framework consumers may still require older downloadable releases.
    # An explicit command argument takes precedence over the mod's policy.
    if (-not $PSBoundParameters.ContainsKey('ArchiveExistingFile') -and $meta.publishing -and
        $meta.publishing.PSObject.Properties['archivePreviousReleases']) {
        if ($meta.publishing.archivePreviousReleases -isnot [bool]) {
            throw 'publishing.archivePreviousReleases must be a JSON boolean.'
        }
        $ArchiveExistingFile = $meta.publishing.archivePreviousReleases
    }

    if ([string]::IsNullOrWhiteSpace($ModName)) {
        $ModName = if ($meta.id) { [string]$meta.id } else { Split-Path -Leaf $modRoot }
    }
    if ([string]::IsNullOrWhiteSpace($Version)) {
        $Version = [string]$meta.version
    }
    if ($Version.Length -gt 50 -or $Version -notmatch '^[a-zA-Z0-9.-]+$') {
        throw "Nexus version '$Version' has unsupported characters."
    }

    $nexus = $meta.distribution.nexus
    if ($null -eq $nexus -or ([string]$nexus.modId) -notmatch '^\d+$') {
        throw 'mod.json needs a numeric distribution.nexus.modId.'
    }
    $game = [string]$nexus.game
    if ($game -notmatch '^[a-z0-9-]+$') {
        throw 'mod.json needs distribution.nexus.game.'
    }

    # Validate & sync local docs / BBCode first
    $docSync = Sync-ModPublicDocs -ModFolder $modRoot -ValidateOnly:$VerifyOnly
    $bbcodePath = $docSync.BBCodePath
    $changelogPath = Join-Path (Join-Path $modRoot 'Nexus') 'CHANGELOG.md'

    $notesDir = Join-Path (Join-Path $modRoot '_AI') 'Notes'
    if (-not (Test-Path -LiteralPath $notesDir -PathType Container)) {
        New-Item -ItemType Directory -Path $notesDir -Force | Out-Null
    }
    $receiptPath = Join-Path $notesDir 'LastPublishReceipt.json'
    $previousReceipt = $null
    if (Test-Path -LiteralPath $receiptPath -PathType Leaf) {
        try { $previousReceipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json } catch { $previousReceipt = $null }
    }

    $script:apiKey = Get-NexusApiKey
    if ([string]::IsNullOrWhiteSpace($script:apiKey)) {
        throw 'NEXUS_BLOCKED_NO_PUBLISHER: Nexus API key was not provided.'
    }

    # 1. Lookup Mod & Active File Groups
    $modResponse = Invoke-Nexus -Method 'Get' -Path "/games/$game/mods/$($nexus.modId)"
    $modData = $modResponse.data
    $modUid = [string]$modData.id
    if ([string]::IsNullOrWhiteSpace($modUid)) {
        throw 'Nexus did not return the required internal mod ID.'
    }
    Write-Host "Verified Nexus mod: $($modData.name) (page ID $($nexus.modId), internal UID $modUid, live version $($modData.version))" -ForegroundColor Cyan

    $groupsResponse = Invoke-Nexus -Method 'Get' -Path "/mods/$modUid/files"
    $groups = @($groupsResponse.data.mod_files | Where-Object { $null -ne $_ })
    $activeGroups = @($groups | Where-Object { $_.is_active -eq $true })

    $fileId = [string]$nexus.fileId
    $targetVersionId = if ($modData.main_file_version -and $modData.main_file_version.id) { [string]$modData.main_file_version.id } else { '' }
    if ($CreateNewFile) {
        if ($MetadataOnly -or $VerifyOnly -or -not [string]::IsNullOrWhiteSpace($fileId)) {
            throw '-CreateNewFile requires a binary upload with no configured fileId; it never updates an existing file group.'
        }
        $targetVersionId = ''
    }

    if (-not [string]::IsNullOrWhiteSpace($fileId)) {
        $directMatch = @($groups | Where-Object { [string]$_.id -eq $fileId })
        if ($directMatch.Count -eq 0) {
            # Check if fileId in mod.json was a version.id or game_scoped_id inside one of the mod's file groups
            $resolvedParentId = $null
            foreach ($g in $groups) {
                $verResp = Invoke-Nexus -Method 'Get' -Path "/mod-files/$($g.id)/versions"
                $vers = @($verResp.data.versions | Where-Object { $null -ne $_ })
                foreach ($v in $vers) {
                    if ([string]$v.id -eq $fileId -or [string]$v.game_scoped_id -eq $fileId -or ($v.file -and [string]$v.file.id -eq $fileId)) {
                        $resolvedParentId = [string]$g.id
                        break
                    }
                }
                if ($resolvedParentId) { break }
            }
            if ($resolvedParentId) {
                Write-Host "Resolved nexus.fileId '$fileId' to parent ModFile group ID '$resolvedParentId'." -ForegroundColor Yellow
                $fileId = $resolvedParentId
                $nexus.fileId = [int64]$fileId
            }
            else {
                throw "Configured nexus.fileId '$fileId' is not listed on this mod page. Refusing to guess."
            }
        }
    }
    elseif (-not $CreateNewFile -and $activeGroups.Count -eq 1 -and ($AutoSelectMainFile -or $MetadataOnly -or $VerifyOnly)) {
        $fileId = [string]$activeGroups[0].id
        $nexus.fileId = [int64]$fileId
        Write-Host "Auto-selected active Nexus file group: $($activeGroups[0].name) (ID: $fileId)" -ForegroundColor Cyan
    }

    # A shared page may have an original primary download and a separate optional
    # edition. Never apply the optional edition's requirements to the primary.
    if ($fileId -and ($MetadataOnly -or $VerifyOnly)) {
        $configuredVersions = Invoke-Nexus -Method 'Get' -Path "/mod-files/$fileId/versions"
        $candidates = @($configuredVersions.data.versions | Where-Object {
            $null -ne $_ -and $_.category -notin @('archived', 'removed')
        })
        $selectedVersion = @($candidates | Where-Object { [string]$_.version -eq $Version } |
            Sort-Object -Property @{Expression={ [DateTimeOffset]$_.uploaded_at };Descending=$true}) | Select-Object -First 1
        if (-not $selectedVersion) {
            $selectedVersion = @($candidates | Sort-Object -Property @{Expression={ [DateTimeOffset]$_.uploaded_at };Descending=$true}) | Select-Object -First 1
        }
        $targetVersionId = if ($selectedVersion) { [string]$selectedVersion.id } else { '' }
    }

    $releaseState = 'PREPARED_LOCALLY'
    $uploadedVersionId = $null

    # 2. File Upload & Version Creation (unless -MetadataOnly or -VerifyOnly)
    if (-not $MetadataOnly -and -not $VerifyOnly) {
        if ([string]::IsNullOrWhiteSpace($Archive) -or -not (Test-Path -LiteralPath $Archive -PathType Leaf)) {
            throw "Missing release archive for upload: $Archive"
        }
        $size = (Get-Item -LiteralPath $Archive).Length
        if ($size -gt 100MB) {
            throw 'Nexus single-part uploads are limited to 100 MiB. Use multipart or manual upload for this file.'
        }

        if (-not $CreateNewFile -and [string]::IsNullOrWhiteSpace($fileId) -and $groups.Count -gt 0) {
            Write-Host 'Existing Nexus file groups:'
            for ($i = 0; $i -lt $groups.Count; $i++) {
                Write-Host ("  {0}. {1} (ID: {2}, Active: {3})" -f ($i + 1), $groups[$i].name, $groups[$i].id, $groups[$i].is_active)
            }
            Write-Host '  N. Create NEW mod file instead of updating a file group'
            $choice = (Read-Host 'Select file to update (number or N)').Trim()
            if ($choice -ine 'N') {
                $idx = 0
                if (-not [int]::TryParse($choice, [ref]$idx) -or $idx -lt 1 -or $idx -gt $groups.Count) {
                    throw 'Invalid file selection. Nothing uploaded.'
                }
                $fileId = [string]$groups[$idx - 1].id
            }
        }

        $displayName = if ($meta.name -and ([string]$meta.name).Length -le 50 -and ([string]$meta.name) -match "^[a-zA-Z0-9 _'().-]+$") {
            [string]$meta.name
        }
        else {
            $ModName
        }
        if ($displayName.Length -gt 50 -or $displayName -notmatch "^[a-zA-Z0-9 _'().-]+$") {
            throw "Nexus file display name '$displayName' must be <= 50 chars and use supported characters."
        }

        $action = if ($fileId) { "ADD VERSION $Version to file group $fileId" } else { "CREATE new $FileCategory file ($Version)" }
        Write-Host "Nexus action: $action for $displayName ($size bytes)"
        if (-not $ConfirmUpload) {
            if ((Read-Host 'Type UPLOAD to send the archive to Nexus').Trim() -cne 'UPLOAD') {
                Write-Host 'Nexus upload cancelled.'
                exit 2
            }
        }

        $archiveName = [System.IO.Path]::GetFileName($Archive)
        $hashHex = (Get-FileHash -LiteralPath $Archive -Algorithm MD5).Hash.ToLowerInvariant()
        $hashBytes = New-Object byte[] 16
        for ($i = 0; $i -lt 16; $i++) { $hashBytes[$i] = [Convert]::ToByte($hashHex.Substring($i * 2, 2), 16) }
        $md5Base64 = [Convert]::ToBase64String($hashBytes)

        Write-Host 'Creating Nexus upload session...'
        $releaseState = 'UPLOAD_STARTED'
        $session = Invoke-Nexus -Method 'Post' -Path '/uploads' -Body @{
            size_bytes = $size
            filename   = $archiveName
            md5        = $hashHex
        }
        $uploadId = [string]$session.data.id
        $presignedUrl = [string]$session.data.presigned_url
        if (-not $uploadId -or -not $presignedUrl) {
            throw 'Nexus did not return a valid upload session.'
        }

        Write-Host "Uploading archive ($archiveName, MD5: $hashHex)..."
        $putHeaders = @{
            'Content-Disposition' = 'attachment; filename="' + $archiveName + '"'
            'Content-MD5'         = $md5Base64
        }
        Invoke-WebRequest -Uri $presignedUrl -Method Put -InFile $Archive -ContentType 'application/octet-stream' -Headers $putHeaders -UseBasicParsing | Out-Null
        $null = Invoke-Nexus -Method 'Post' -Path "/uploads/$uploadId/finalise"

        Write-Host 'Waiting for Nexus upload processing...'
        $ready = $false
        for ($attempt = 0; $attempt -lt 60; $attempt++) {
            $upload = Invoke-Nexus -Method 'Get' -Path "/uploads/$uploadId"
            $state = [string]$upload.data.state
            if ($state -eq 'available') { $ready = $true; break }
            if ($state -in @('failed', 'rejected', 'cancelled', 'error')) {
                throw "Nexus upload failed with state: $state"
            }
            Start-Sleep -Seconds 3
        }
        if (-not $ready) {
            throw "Nexus upload did not become available in time. Upload ID: $uploadId."
        }

        $payload = @{
            upload_id          = $uploadId
            name               = $displayName
            version            = $Version
            file_category      = $FileCategory
            update_mod_version = $UpdateModVersion
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$meta.description)) {
            $payload.description = [string]$meta.description
        }

        if ($fileId) {
            $payload.archive_existing_file = $ArchiveExistingFile
            $result = Invoke-Nexus -Method 'Post' -Path "/mod-files/$fileId/versions" -Body $payload
            # The create-version response may put the version ID in data.file.id.
            # The configured parent group is authoritative and must remain stable.
            $uploadReceiptPath = Join-Path $notesDir 'NexusUploadReceipt.json'
            $uploadReceipt = [ordered]@{
                nexusModUid = $modUid
                uploadId = $uploadId
                nexusFileId = $fileId
                createdResponseId = [string]$result.data.file.id
                version = $Version
                acceptedUtc = (Get-Date).ToUniversalTime().ToString('o')
            }
            Save-ModJson -Path $uploadReceiptPath -Metadata $uploadReceipt
            if ($result.data.version -and $result.data.version.id) {
                $uploadedVersionId = [string]$result.data.version.id
                $targetVersionId = $uploadedVersionId
            }
            else {
                $acceptedVersions = Invoke-Nexus -Method 'Get' -Path "/mod-files/$fileId/versions"
                $acceptedMatches = @($acceptedVersions.data.versions | Where-Object { [string]$_.version -eq $Version })
                if ($acceptedMatches.Count -ne 1) { throw 'Upload accepted but the version could not be uniquely resolved in the configured group. Inspect NexusUploadReceipt.json before retrying; do not upload again.' }
                $uploadedVersionId = [string]$acceptedMatches[0].id
                $targetVersionId = $uploadedVersionId
            }
            $uploadReceipt.nexusVersionId = $uploadedVersionId
            Save-ModJson -Path $uploadReceiptPath -Metadata $uploadReceipt
        }
        else {
            $payload.mod_id = $modUid
            $payload.primary_mod_manager_download = $PrimaryModManagerDownload
            $payload.allow_mod_manager_download = $true
            $result = Invoke-Nexus -Method 'Post' -Path '/mod-files' -Body $payload
            $createdId = [string]$result.data.id
            $uploadReceiptPath = Join-Path $notesDir 'NexusUploadReceipt.json'
            $uploadReceipt = [ordered]@{
                nexusModUid = $modUid
                uploadId = $uploadId
                createdResponseId = $createdId
                version = $Version
                acceptedUtc = (Get-Date).ToUniversalTime().ToString('o')
            }
            Save-ModJson -Path $uploadReceiptPath -Metadata $uploadReceipt
            $resolved = Resolve-NexusCreatedFile -ModUid $modUid -CreatedId $createdId -ExpectedVersion $Version -KnownFileIds @($groups | ForEach-Object { [string]$_.id })
            $fileId = $resolved.FileId
            $uploadedVersionId = $resolved.VersionId
            $targetVersionId = $uploadedVersionId
            $uploadReceipt.nexusFileId = $fileId
            $uploadReceipt.nexusVersionId = $uploadedVersionId
            Save-ModJson -Path $uploadReceiptPath -Metadata $uploadReceipt
        }

        if (-not [string]::IsNullOrWhiteSpace($fileId)) {
            $nexus.fileId = [int64]$fileId
        }
        $releaseState = 'UPLOAD_ACCEPTED'
        Write-Host "Nexus file version created: FileID=$fileId, VersionID=$uploadedVersionId, Version=$Version" -ForegroundColor Green
    }

    # Resolve latest version ID if we didn't just upload one
    if ([string]::IsNullOrWhiteSpace($targetVersionId) -and -not [string]::IsNullOrWhiteSpace($fileId)) {
        $verListResp = Invoke-Nexus -Method 'Get' -Path "/mod-files/$fileId/versions"
        $latestVer = @($verListResp.data.versions | Where-Object { $null -ne $_ }) | Select-Object -Last 1
        if ($latestVer -and $latestVer.id) {
            $targetVersionId = [string]$latestVer.id
        }
    }

    # 3. File-Level Dependency Linking & Verification
    $nexusReqs = @()
    foreach ($req in @($nexus.requirements)) {
        if ($null -eq $req) { continue }
        if ($req -is [string]) { continue }
        $reqUrl = [string]$req.url
        $reqType = [string]$req.type
        if ($reqType -eq 'nexus' -or $reqUrl -match 'nexusmods\.com/([a-z0-9-]+)/mods/(\d+)') {
            if ($reqUrl -match 'nexusmods\.com/([a-z0-9-]+)/mods/(\d+)') {
                $nexusReqs += [pscustomobject]@{
                    Name           = [string]$req.name
                    Game           = $Matches[1]
                    ModId          = $Matches[2]
                    MinimumVersion = [string]$req.minimumVersion
                    FileId         = [string]$req.fileId
                }
            }
        }
    }

    if ($nexusReqs.Count -eq 0) {
        # No Nexus mod dependencies required (e.g., Foundation / RightClickFix only need off-site BepInEx)
        $nexus.requirementsVerified = $true
        Write-Host 'Nexus requirements check: No on-site Nexus mod dependencies required (requirementsVerified = true).' -ForegroundColor Green
    }
    elseif (-not [string]::IsNullOrWhiteSpace($targetVersionId)) {
        $nexus.requirementsVerified = $false
        try {
            $depDefinitions = @()
            foreach ($nReq in $nexusReqs) {
                $reqModResp = Invoke-Nexus -Method 'Get' -Path "/games/$($nReq.Game)/mods/$($nReq.ModId)"
                $resolvedRequirement = Resolve-NexusRequiredVersion -Requirement $nReq -RequiredMod $reqModResp.data
                $nReq.FileId = $resolvedRequirement.FileId
                $minVerId = $resolvedRequirement.VersionId
                if ($minVerId) {
                    $depDefinitions += @{
                        ranges = @(
                            @{
                                min_version_id = $minVerId
                                max_version_id = $null
                            }
                        )
                    }
                }
            }

            if (-not $VerifyOnly -and $depDefinitions.Count -eq $nexusReqs.Count) {
                try {
                    $null = Invoke-Nexus -Method 'Put' -Path "/mods/$modUid/toggle-legacy-mod-requirements" -Body @{ enabled = $false }
                }
                catch { }
                $null = Invoke-Nexus -Method 'Put' -Path "/mod-file-versions/$targetVersionId/dependencies/ranges" -Body @{
                    dependency_definitions = $depDefinitions
                }
                Write-Host "Updated Nexus file-level dependencies on version $targetVersionId." -ForegroundColor Cyan
            }

            $liveDeps = Invoke-Nexus -Method 'Get' -Path "/mod-file-versions/$targetVersionId/dependencies/ranges"
            $missingRequirements = @(Get-NexusMissingRequirements -Response $liveDeps -Requirements $nexusReqs)
            if ($missingRequirements.Count -eq 0) {
                $nexus.requirementsVerified = $true
                Write-Host "Nexus requirements verified on version $targetVersionId ($($nexusReqs.Count) linked mod requirement(s), including minimum versions)." -ForegroundColor Green
            }
            else {
                Write-Warning "Nexus live file version $targetVersionId is missing expected mod/minimum-version requirements: $($missingRequirements -join ', ')."
            }
        }
        catch {
            Write-Warning ("Could not automatically verify/update file-level dependencies: " + $_.Exception.Message)
        }
    }

    # 4. Update Page Summary, BBCode Description & Version Changelog
    $changelogUpdated = $false
    if (($UpdatePageMetadata -or $MetadataOnly) -and -not $VerifyOnly) {
        $bbcodeText = [System.IO.File]::ReadAllText($bbcodePath)
        if (-not [string]::IsNullOrWhiteSpace($PageDescriptionPath)) {
            $bbcodeText = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $PageDescriptionPath).Path)
            $pageCheck = Test-NexusBBCode -BBCode $bbcodeText
            if (-not $pageCheck.IsValid) { throw ('Invalid shared-page BBCode: ' + ($pageCheck.Issues -join '; ')) }
        }
        $summaryText = ([string]$meta.description -replace '\s+', ' ').Trim()
        if ($summaryText.Length -gt 350) {
            $summaryText = $summaryText.Substring(0, 347) + '...'
        }

        $editBody = @{
            description = $bbcodeText
        }
        if (-not $PreservePageSummary -and -not [string]::IsNullOrWhiteSpace($summaryText)) {
            $editBody.summary = $summaryText
        }

        Write-Host "Updating Nexus mod page summary & BBCode description (PATCH /mods/$modUid)..."
        $null = Invoke-Nexus -Method 'Patch' -Path "/mods/$modUid" -Body $editBody
        Write-Host 'Nexus description & summary updated.' -ForegroundColor Green

        # Post version changelog if not already appended for this version
        $alreadyPosted = ($previousReceipt -and ([string]$previousReceipt.lastChangelogVersionPosted -eq $Version) -and -not $ForceChangelogAppend)
        if ($alreadyPosted) {
            Write-Host "Changelog for version $Version was already posted in a previous run; skipping duplicate append." -ForegroundColor Cyan
        }
        elseif (Test-Path -LiteralPath $changelogPath -PathType Leaf) {
            $parsedCl = Get-ModVersionChangelog -ChangelogPath $changelogPath -Version $Version
            if (-not [string]::IsNullOrWhiteSpace($parsedCl.NexusNotes)) {
                Write-Host "Appending Nexus changelog for version $Version ($($parsedCl.EntryCount) entries)..."
                $null = Invoke-Nexus -Method 'Post' -Path "/mods/$modUid/changelogs" -Body @{
                    version   = $Version
                    changelog = $parsedCl.NexusNotes
                }
                $changelogUpdated = $true
                Write-Host "Nexus changelog updated for version $Version." -ForegroundColor Green
            }
        }
    }

    # 5. Read-After-Write Verification (Mod Page, Description Colors, Tags, and File Version)
    Write-Host 'Running Nexus read-after-write verification...'
    $liveModResp = Invoke-Nexus -Method 'Get' -Path "/games/$game/mods/$($nexus.modId)"
    $liveMod = $liveModResp.data
    $verifiedFileState = if ([string]$liveMod.status -eq 'published') {
        'NEXUS_PUBLISHED_VERIFIED'
    }
    elseif ([string]$liveMod.status -eq 'not_published') {
        'NEXUS_UPLOADED_DRAFT'
    }
    else { 'NEXUS_FILE_VERIFIED_PAGE_STATUS_UNKNOWN' }

    # 5a. Verify live BBCode colors & formatting
    $liveDesc = [string]$liveMod.description
    $liveColorCheck = Test-NexusBBCode -BBCode $liveDesc
    $colorStatus = if ($liveColorCheck.IsValid -and $liveColorCheck.ColorSpanCount -gt 0) {
        'NEXUS_COLORS_PRESENT_VERIFIED'
    }
    else {
        'NEXUS_COLOR_FORMATTING_FAILED'
    }
    if ($colorStatus -eq 'NEXUS_COLORS_PRESENT_VERIFIED') {
        Write-Host "Description verification: $colorStatus ($($liveColorCheck.ColorSpanCount) color spans live)." -ForegroundColor Green
    }
    else {
        Write-Warning ("Description verification: $colorStatus - " + ($liveColorCheck.Issues -join '; '))
    }

    # 5b. Verify live Tags against mod.json
    $liveTagNames = @($liveMod.tags | Where-Object { $null -ne $_ -and $_.name } | ForEach-Object { [string]$_.name })
    $desiredTags = @($nexus.tags | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_ })
    if ($desiredTags -notcontains 'AI-Generated Content') {
        $desiredTags += 'AI-Generated Content'
    }
    $missingTags = @($desiredTags | Where-Object { $liveTagNames -notcontains $_ })
    if ($missingTags.Count -eq 0 -and $liveTagNames.Count -gt 0) {
        $nexus.tagsVerified = $true
        Write-Host ("Tags verification: PASS (Live tags: " + ($liveTagNames -join ', ') + ")") -ForegroundColor Green
    }
    else {
        # Note: Nexus v3 GET /mods/{id} returns applied tags; if liveTagNames contains AI-Generated Content, record status clearly
        if ($liveTagNames -contains 'AI-Generated Content' -and $missingTags.Count -eq 0) {
            $nexus.tagsVerified = $true
        }
        else {
            Write-Warning ("Tags pending on live page (Missing from API response: " + ($missingTags -join ', ') + " | Live: " + ($liveTagNames -join ', ') + ")")
        }
    }

    # 5c. Verify live File Version
    $verifiedVersionObj = $null
    if (-not [string]::IsNullOrWhiteSpace($targetVersionId)) {
        try {
            $verDetailResp = Invoke-Nexus -Method 'Get' -Path "/mod-file-versions/$targetVersionId"
            $verifiedVersionObj = $verDetailResp.data
            if ([string]$verifiedVersionObj.version -eq $Version) {
                $scanStatus = [string]$verifiedVersionObj.security_scan_status
                if ($scanStatus -eq 'quarantined') {
                    $releaseState = 'NEXUS_NOT_PUBLISHED'
                    throw "Nexus file version $targetVersionId is QUARANTINED!"
                }
                $releaseState = $verifiedFileState
                Write-Host "File verification: $releaseState (VersionID=$($verifiedVersionObj.id), GameScopedID=$($verifiedVersionObj.game_scoped_id), Version=$($verifiedVersionObj.version), Scan=$scanStatus, PageStatus=$($liveMod.status))" -ForegroundColor Green
            }
            elseif ($MetadataOnly -or $VerifyOnly) {
                $releaseState = $verifiedFileState
                Write-Host "File verification: Live version is $($verifiedVersionObj.version) (VersionID=$($verifiedVersionObj.id))." -ForegroundColor Cyan
            }
            else {
                $releaseState = 'PENDING_PROCESSING'
                Write-Warning "File verification: VersionID=$targetVersionId returned version '$($verifiedVersionObj.version)' (expected '$Version')."
            }
        }
        catch {
            Write-Warning ("Could not read mod-file-version $targetVersionId`: " + $_.Exception.Message)
        }
    }

    # 6. Persist verified metadata to mod.json and write receipt
    if ($meta.publishing -and -not [string]::IsNullOrWhiteSpace([string]$nexus.url)) {
        $meta.publishing.nexusMods = [string]$nexus.url
    }
    Save-ModJson -Path $ModJson -Metadata $meta

    $receipt = [ordered]@{
        modName                     = $ModName
        version                     = $Version
        timestampUtc                = (Get-Date).ToUniversalTime().ToString('o')
        nexusModId                  = $nexus.modId
        nexusModUid                 = $modUid
        nexusFileId                 = $nexus.fileId
        nexusVersionId              = $targetVersionId
        nexusGameScopedVersionId    = if ($verifiedVersionObj) { $verifiedVersionObj.game_scoped_id } else { $null }
        securityScanStatus          = if ($verifiedVersionObj) { $verifiedVersionObj.security_scan_status } else { $null }
        releaseState                = $releaseState
        pageStatus                  = [string]$liveMod.status
        descriptionColorStatus      = $colorStatus
        colorSpanCount              = $liveColorCheck.ColorSpanCount
        liveTags                    = $liveTagNames
        tagsVerified                = $nexus.tagsVerified
        requirementsVerified        = $nexus.requirementsVerified
        lastChangelogVersionPosted  = if ($changelogUpdated) { $Version } elseif ($previousReceipt) { $previousReceipt.lastChangelogVersionPosted } else { $null }
    }
    Save-ModJson -Path $receiptPath -Metadata $receipt
    Write-Host "Saved publish receipt: $receiptPath" -ForegroundColor Cyan
    exit 0
}
catch {
    Write-Host ('NEXUS ERROR: ' + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
finally {
    $script:apiKey = $null
}
