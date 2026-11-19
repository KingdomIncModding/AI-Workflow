# Standalone, two-stage mod migration and GitHub repository replacement utility.
# Stage 1: prepare an older mod locally for AI-assisted metadata/docs migration.
# Stage 2: after AI_SETUP_PROMPT.md is removed, replace the existing GitHub repo.
param(
    [Parameter(Mandatory = $true)]
    [string]$ModFolder,
    [string]$MockRemotePath,
    [switch]$MockAutoConfirm
)

$ErrorActionPreference = 'Stop'
# Disable Git's interactive pager. A drag-and-drop CMD session must not pause at (END).
$env:GIT_PAGER = 'cat'
$env:PAGER = 'cat'
$owner = 'KingdomIncModding'
$legacyPrefix = 'KingdomInc_'
$completed = $false
$temporaryCheckout = $null
$mockMode = -not [string]::IsNullOrWhiteSpace($MockRemotePath)

function Invoke-Git {
    param([string[]]$Arguments)
    & git @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw ('Git failed (exit {0}): git {1}' -f $LASTEXITCODE, ($Arguments -join ' '))
    }
}

function Save-Json {
    param([string]$Path, [object]$Value)
    $json = $Value | ConvertTo-Json -Depth 16
    [System.IO.File]::WriteAllText($Path, ($json + [Environment]::NewLine), ([System.Text.UTF8Encoding]::new($false)))
}

function Ensure-Property {
    param([object]$Object, [string]$Name, [object]$Default)
    if (-not $Object.PSObject.Properties[$Name]) {
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Default
    }
    return $Object.PSObject.Properties[$Name].Value
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Ensure-IgnoreRule {
    param([string]$Path, [string[]]$Rules)
    $existing = if (Test-Path -LiteralPath $Path -PathType Leaf) {
        @([System.IO.File]::ReadAllLines($Path))
    } else { @() }
    $new = New-Object System.Collections.Generic.List[string]
    foreach ($rule in $Rules) {
        if ($existing -cnotcontains $rule) { $new.Add($rule) }
    }
    if ($new.Count -gt 0) {
        [System.IO.File]::AppendAllText($Path, ([Environment]::NewLine + ($new -join [Environment]::NewLine) + [Environment]::NewLine), ([System.Text.UTF8Encoding]::new($false)))
    }
}

# Use only the shared workspace template. RepoReplace has no bundled template.
# This is the single authoritative location for every mod template file.
function Resolve-TemplateFile {
    param([string]$RelativePath)
    $candidate = Join-Path $sharedTemplate $RelativePath
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        return $candidate
    }
    throw ('Missing file in the shared mod template: {0}. Expected: {1}' -f $RelativePath, $candidate)
}

function Test-RequiredTemplateFiles {
    param([string]$ModPath)
    if (-not (Test-Path -LiteralPath $sharedTemplate -PathType Container)) {
        throw ('Shared mod template not found: {0}. RepoReplace never uses a second copy.' -f $sharedTemplate)
    }

    # mod.json is always required: existing metadata must be merged with the
    # current canonical template, never with an embedded or stale snapshot.
    $required = @('mod.json')
    foreach ($relative in @(
        '.gitignore', 'README.md',
        'Nexus\DESCRIPTION.md', 'Nexus\CHANGELOG.md',
        'Nexus\PREREQUISITES.md', 'Nexus\COMPATIBILITY.md'
    )) {
        if (-not (Test-Path -LiteralPath (Join-Path $ModPath $relative) -PathType Leaf)) {
            $required += $relative
        }
    }
    foreach ($relative in $required) {
        $null = Resolve-TemplateFile -RelativePath $relative
    }
}

# Copy LOCAL-ONLY reference forms from the ONE shared
# template folder. Do not assume historical filenames such as bug_report.yml:
# GitHub also supports .yaml and .md, and files may be named differently.
function Copy-SharedIssueTemplates {
    param([string]$ModPath)
    $templateDirectory = Join-Path (Join-Path $sharedTemplate '.github') 'ISSUE_TEMPLATE'
    $destinationDirectory = Join-Path (Join-Path $modPath '.github') 'ISSUE_TEMPLATE'

    Write-Host ('Checking shared issue templates: {0}' -f $templateDirectory)
    if (-not (Test-Path -LiteralPath $templateDirectory -PathType Container)) {
        Write-Warning ('Issue template DIRECTORY was not found: {0}. The shared _ModTemplate is the only source.' -f $templateDirectory)
        return
    }

    # Enumerate actual filenames instead of checking two hardcoded paths.
    # -Force includes files accidentally marked hidden on Windows.
    $allFiles = @(Get-ChildItem -LiteralPath $templateDirectory -File -Force -ErrorAction Stop)
    $templates = @($allFiles | Where-Object { @('.yml', '.yaml', '.md') -contains $_.Extension.ToLowerInvariant() })
    if ($templates.Count -eq 0) {
        $found = if ($allFiles.Count -gt 0) { ($allFiles.Name -join ', ') } else { '(directory is empty)' }
        Write-Warning ('No .yml, .yaml, or .md issue templates in {0}. Files found: {1}' -f $templateDirectory, $found)
        return
    }

    Ensure-Directory -Path $destinationDirectory
    foreach ($templateFile in $templates) {
        $destinationFile = Join-Path $destinationDirectory $templateFile.Name
        if (Test-Path -LiteralPath $destinationFile -PathType Leaf) {
            Write-Host ('Preserved existing issue template: {0}' -f $templateFile.Name)
            continue
        }
        Copy-Item -LiteralPath $templateFile.FullName -Destination $destinationFile -ErrorAction Stop
        Write-Host ('Installed issue template: {0}' -f $templateFile.Name)
    }
}

function Copy-Template-If-Missing {
    param([string]$RelativePath, [string]$Destination)
    if (-not (Test-Path -LiteralPath $Destination -PathType Leaf)) {
        $source = Resolve-TemplateFile -RelativePath $RelativePath
        Ensure-Directory -Path (Split-Path -Path $Destination -Parent)
        Copy-Item -LiteralPath $source -Destination $Destination
    }
}

function Get-FileSha256 {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return '' }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

# GitHub receives ONLY the player-facing README, not Nexus docs or agent files.
# The Nexus directory itself is not uploaded to GitHub.
function Assert-CompatibilityInDescription {
    param([string]$ModPath)
    $description = [System.IO.File]::ReadAllText((Join-Path $ModPath 'Nexus\DESCRIPTION.md'))
    $compatibility = [System.IO.File]::ReadAllText((Join-Path $ModPath 'Nexus\COMPATIBILITY.md'))
    if ($description -notmatch '(?im)^#{1,6}\s+Compatibility\s*$') {
        throw 'DESCRIPTION.md must include a Compatibility section, which is mirrored into the GitHub README.'
    }
    $rows = @($compatibility -split '\r?\n' | Where-Object { $_ -match '^\|.*\|$' })
    foreach ($row in $rows) {
        if (-not $description.Contains($row)) {
            throw 'DESCRIPTION.md is missing a row from Nexus/COMPATIBILITY.md. Add the exact compatibility table, then copy DESCRIPTION.md to README.md.'
        }
    }
}

function New-SetupPrompt {
    param([string]$Path, [string]$ModName, [string]$RepoUrl)
    $content = @'
# One-time Mod Migration Prompt

This is a temporary handoff file. Read this prompt, complete the migration, and
DELETE THIS FILE when everything below is finished. It is explicitly ignored
by Git and MUST NEVER be uploaded. Put any ongoing prompts or working notes in
`_AI/Prompts/` or `_AI/Notes/`, never in the public mod root.

## Mod and repository

- Mod: __MOD_NAME__
- Existing GitHub repository: __REPO_URL__
- The mod's source code belongs in `src/` ONLY.
- Project files (`*.csproj`, `*.sln`, `*.slnx`) belong in the mod root.
- Approved mod assets belong in `Assets/{category}/` ONLY.
- AI-generated candidates, media, prompts, and scratch work belong under
  `_AI/`; generated asset drafts belong under `_AI/Gen/Assets/{category}/`.
- Never add local `_AI/` content to GitHub.

## Read the established workspace rules

Find the shared `_Mods/_AI/AGENTS.md`. Then read:
- `_Mods/_AI/_GitHub/README.md`
- `_Mods/_AI/_GitHub/REPOSITORIES.md`
- `_Mods/_AI/_GitHub/CONVENTIONS.md`
- `_Mods/_AI/_Nexus/MOD_DESCRIPTIONS.md`
- `_Mods/_AI/_Nexus/PUBLISHING.md`
- `_Mods/_AI/_Workflows/NEWMOD.md`

These are the source of truth when present. Do not invent requirements.

## Required migration (based on actual code and existing text)

1. Inspect the entire local mod source and existing root README before writing.
   The original README is backed up at `_AI/Notes/Legacy_README.md` if one
   existed. Do not lose accurate player-facing information.
2. Complete `mod.json`: identity, actual version, author, description, the
   verified GitHub repository, dependencies, and Nexus page/requirements only
   if known. Keep unknown values null/empty; do not make them up. Preserve
   existing valid metadata.
3. Rewrite `Nexus/DESCRIPTION.md` as a clean, accurate, player-facing mod
   description using the previous README and real implemented features.
   Include installation/usage only when supported by the mod. NEVER include
   AI reports, verification, build commands, artifacts, developer instructions,
   prompts, internal file paths, or implementation checklists.
4. Add a `## Compatibility` section to `Nexus/DESCRIPTION.md` containing the
   confirmed `Class.Method | Hook Type | Impact` table from `Nexus/COMPATIBILITY.md`
   (or its plain no-hooks statement). Keep it concise and player-facing.
   Then copy `Nexus/DESCRIPTION.md` EXACTLY to the root `README.md` (same bytes).
   Do not append compatibility to README alone. Do not include AI/build details.
5. Fill `Nexus/CHANGELOG.md` from known history. Do not invent releases.
   If no history is available, say so simply rather than guessing.
6. Fill `Nexus/PREREQUISITES.md` with required mods/frameworks identified from
   source/project dependencies. Include verified Nexus mod page URLs for
   linked requirements when available; do not invent links.
7. Fill `Nexus/COMPATIBILITY.md` with ONLY this table shape:

   | Class.Method | Hook Type | Impact |
   |---|---|---|

   List genuine hooks (Harmony, etc.) based on source. Describe impact simply.
   If none are used, note that plainly. Do not invent affected methods.
8. Check locally stored `.github/ISSUE_TEMPLATE/` forms and keep them free of AI
   jargon. Do not create, comment on, close, or change GitHub issues or feature
   requests. Do not create tags, releases, or new features unless directed.
9. Check the mod-root `.gitignore` includes `/_AI/`, `/Nexus/`,
   `/.github/`, `/~tmp/`, and `/AI_SETUP_PROMPT.md` (plus agent instructions).
   Nexus drafts, local issue templates, and agent instructions must stay off GitHub.
   The `.gitignore` file itself IS committed to GitHub.
   Do not delete or rewrite user project files or source code.
10. Verify all public text against actual functionality. Verify the root
    README and Nexus DESCRIPTION match byte-for-byte.

## Finish and push authorization

- DELETE `AI_SETUP_PROMPT.md` from the mod root only when all steps are done.
- Leave the permanent copy of this prompt inside `_AI/Prompts/` for reference.
- DO NOT push to GitHub. DO NOT post issues. DO NOT change Nexus remotely.
- To upload later, the user drags this mod folder onto ReplaceRepo.cmd again,
  reviews the exact repository, and types REPLACE to authorize a commit/push.
'@
    $content = $content.Replace('__MOD_NAME__', $ModName).Replace('__REPO_URL__', $RepoUrl)
    [System.IO.File]::WriteAllText($Path, $content, ([System.Text.UTF8Encoding]::new($false)))
}

try {
    if ($MockAutoConfirm -and -not $mockMode) {
        throw 'MockAutoConfirm is available only with a local MockRemotePath.'
    }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw 'Git for Windows was not found in PATH.'
    }
    $mod = Get-Item -LiteralPath $ModFolder -ErrorAction Stop
    if (-not $mod.PSIsContainer) { throw 'Drag a mod folder, not a file.' }
    $modPath = $mod.FullName
    $modName = $mod.Name
    if ($modName -notmatch '^[A-Za-z0-9._-]+$') {
        throw 'Mod folder name contains unsupported repository characters.'
    }
    $repoName = if ($modName.StartsWith($legacyPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        $modName.Substring($legacyPrefix.Length)
    } else { $modName }
    $repoPage = 'https://github.com/{0}/{1}' -f $owner, $repoName
    $repoGitUrl = $repoPage + '.git'
    if ($mockMode) {
        # Offline test: git clone / push operate ONLY on a verified local bare repository.
        if ([System.Uri]::IsWellFormedUriString($MockRemotePath, [System.UriKind]::Absolute) -or
            $MockRemotePath.StartsWith('\\')) {
            throw 'MockRemotePath must be a local directory, not a URL or network share.'
        }
        $remoteDir = Get-Item -LiteralPath $MockRemotePath -ErrorAction Stop
        if (-not $remoteDir.PSIsContainer) { throw 'MockRemotePath is not a directory.' }
        $repoGitUrl = $remoteDir.FullName
        $isBare = @(& git -C $repoGitUrl rev-parse --is-bare-repository 2>$null)
        if ($LASTEXITCODE -ne 0 -or ($isBare -join '').Trim() -ne 'true') {
            throw 'MockRemotePath must point to an initialized local bare Git repository.'
        }
        Write-Host '*** OFFLINE MOCK MODE *** No GitHub read, commit, or push will occur.' -ForegroundColor Cyan
        Write-Host ('Local test repository: {0}' -f $repoGitUrl)
    }
    $temporaryCheckout = Join-Path $modPath '~tmp'
    if (Test-Path -LiteralPath $temporaryCheckout) {
        throw '~tmp already exists. This tool will not overwrite it. Inspect/remove it manually.'
    }

    # Never trust a differently configured repository link.
    $metadataPath = Join-Path $modPath 'mod.json'
    $existingMetadata = $null
    if (Test-Path -LiteralPath $metadataPath -PathType Leaf) {
        $existingMetadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
        $declared = if ($existingMetadata.repository -and $existingMetadata.repository.url) {
            [string]$existingMetadata.repository.url
        } else { '' }
        if ($declared) {
            $normalizedDeclared = $declared.Trim().TrimEnd('/') -replace '\.git$', ''
            if (-not $normalizedDeclared.Equals($repoPage, [StringComparison]::OrdinalIgnoreCase)) {
                throw ('mod.json points to a different repository: {0}' -f $declared)
            }
        }
    }

    if ($mockMode) {
        Write-Host 'Looking up the isolated local mock repository...'
    } else {
        Write-Host 'Looking up the existing GitHub repository...'
    }
    $remoteHead = @(& git ls-remote --symref -- $repoGitUrl HEAD)
    if ($LASTEXITCODE -ne 0 -or $remoteHead.Count -eq 0) {
        throw ('Repository is missing or not accessible: {0}' -f $repoPage)
    }
    $headLine = $remoteHead | Where-Object { $_ -match '^ref:\s+refs/heads/([^\s]+)\s+HEAD$' } | Select-Object -First 1
    $headMatch = [regex]::Match([string]$headLine, '^ref:\s+refs/heads/([^\s]+)\s+HEAD$')
    if (-not $headMatch.Success) {
        throw 'Cannot determine the existing repository default branch.'
    }
    $branch = $headMatch.Groups[1].Value
    Write-Host ('Repository: {0} (branch: {1})' -f $repoPage, $branch)

    # Canonical template ONLY: _Mods/_AI/_Workflows/_ModTemplate.
    $sharedTemplate = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\_Workflows\_ModTemplate'))
    $setupPrompt = Join-Path $modPath 'AI_SETUP_PROMPT.md'
    $initializedMarker = Join-Path $modPath '_AI\Notes\RepoReplace_Initialized.flag'

    # First use: always prepare old mods locally. No GitHub write occurs.
    if (-not (Test-Path -LiteralPath $initializedMarker -PathType Leaf)) {
        Write-Host ''
        Write-Host 'PREPARE LEGACY MOD FOR THE NEW WORKSPACE FORMAT' -ForegroundColor Yellow
        Write-Host ('Mod folder : {0}' -f $modPath)
        Write-Host ('Repository : {0}' -f $repoPage)
        Write-Host 'Existing files will be preserved. Missing files and folders will be added.'
        Write-Host 'The existing README will be saved privately and used as a draft.'
        Write-Host 'An AI setup prompt will be created in the mod root temporarily.'
        Write-Host 'NO GitHub commits or pushes happen during preparation.'
        $approval = if ($MockAutoConfirm) { 'PREPARE' } else { Read-Host 'Type PREPARE to create local migration files' }
        if ($approval -cne 'PREPARE') { Write-Host 'Cancelled. Nothing changed.'; exit 0 }

        # Verify required template inputs BEFORE modifying the mod.
        Test-RequiredTemplateFiles -ModPath $modPath
        Write-Host ('Using shared template: {0}' -f $sharedTemplate)

        foreach ($folder in @(
            'src', 'Assets', 'Assets\Screenshots', 'Assets\Thumbnails',
            'Nexus', '_AI', '_AI\Gen', '_AI\Gen\Assets',
            '_AI\Gen\Assets\Thumbnails', '_AI\Prompts', '_AI\Media',
            '_AI\Notes', '_AI\Scratch', '.github', '.github\ISSUE_TEMPLATE'
        )) { Ensure-Directory -Path (Join-Path $modPath $folder) }

        $legacyReadme = Join-Path $modPath 'README.md'
        $backupReadme = Join-Path $modPath '_AI\Notes\Legacy_README.md'
        $description = Join-Path $modPath 'Nexus\DESCRIPTION.md'
        if ((Test-Path -LiteralPath $legacyReadme -PathType Leaf) -and
            -not (Test-Path -LiteralPath $backupReadme -PathType Leaf)) {
            Copy-Item -LiteralPath $legacyReadme -Destination $backupReadme
        }
        foreach ($name in @('DESCRIPTION.md', 'CHANGELOG.md', 'PREREQUISITES.md', 'COMPATIBILITY.md')) {
            Copy-Template-If-Missing -RelativePath ('Nexus\' + $name) -Destination (Join-Path $modPath ('Nexus\' + $name))
        }
        # Legacy README text is draft material only; AI must remove all dev content.
        if ((Test-Path -LiteralPath $legacyReadme -PathType Leaf) -and
            ((Get-Item -LiteralPath $description).Length -eq 0)) {
            Copy-Item -LiteralPath $legacyReadme -Destination $description -Force
        }
        Copy-Template-If-Missing -RelativePath 'README.md' -Destination $legacyReadme
        Copy-SharedIssueTemplates -ModPath $modPath

        if (-not $existingMetadata) {
            $existingMetadata = Get-Content -LiteralPath (Resolve-TemplateFile -RelativePath 'mod.json') -Raw | ConvertFrom-Json
        }
        $null = Ensure-Property $existingMetadata 'id' $modName
        $null = Ensure-Property $existingMetadata 'name' $modName
        $null = Ensure-Property $existingMetadata 'version' $null
        if (-not $existingMetadata.id) { $existingMetadata.id = $modName }
        if (-not $existingMetadata.name) { $existingMetadata.name = $modName }
        $repository = Ensure-Property $existingMetadata 'repository' ([pscustomobject]@{})
        if ($null -eq $repository) { $repository = [pscustomobject]@{}; $existingMetadata.repository = $repository }
        foreach ($pair in @(
            @('platform', 'GitHub'), @('owner', $owner), @('name', $repoName),
            @('url', $repoPage), @('branch', $branch), @('visibility', $null),
            @('topics', @()), @('latestTag', $null)
        )) {
            $null = Ensure-Property $repository ([string]$pair[0]) $pair[1]
        }
        $repository.platform = 'GitHub'
        $repository.owner = $owner
        $repository.name = $repoName
        $repository.url = $repoPage
        $repository.branch = $branch
        # Keep all other existing metadata, including Nexus IDs and requirements.
        $templateMetadata = Get-Content -LiteralPath (Resolve-TemplateFile -RelativePath 'mod.json') -Raw | ConvertFrom-Json
        foreach ($part in @('distribution', 'development', 'publishing')) {
            $value = $templateMetadata.PSObject.Properties[$part].Value
            $null = Ensure-Property $existingMetadata $part $value
        }
        if ($existingMetadata.distribution) {
            $nexus = Ensure-Property $existingMetadata.distribution 'nexus' $templateMetadata.distribution.nexus
            if ($nexus) {
                foreach ($prop in $templateMetadata.distribution.nexus.PSObject.Properties) {
                    $null = Ensure-Property $nexus $prop.Name $prop.Value
                }
            }
        }
        Save-Json -Path $metadataPath -Value $existingMetadata

        $ignorePath = Join-Path $modPath '.gitignore'
        if (-not (Test-Path -LiteralPath $ignorePath -PathType Leaf)) {
            Copy-Item -LiteralPath (Resolve-TemplateFile -RelativePath '.gitignore') -Destination $ignorePath
        }
        Ensure-IgnoreRule -Path $ignorePath -Rules @('/_AI/', '/Nexus/', '/.github/', '/.agents/', '/.claude/', '/.codex/', '/AGENTS.md', '/CLAUDE.md', '/GEMINI.md', '/~tmp/', '/AI_SETUP_PROMPT.md', '**/bin/', '**/obj/', '*.user', '*.suo', '.env', '.env.*')

        New-SetupPrompt -Path $setupPrompt -ModName $modName -RepoUrl $repoPage
        Copy-Item -LiteralPath $setupPrompt -Destination (Join-Path $modPath '_AI\Prompts\RepositorySetup.md') -Force
        [System.IO.File]::WriteAllText($initializedMarker, 'Legacy mod preparation completed locally.', ([System.Text.UTF8Encoding]::new($false)))
        Write-Host ''
        Write-Host 'LOCAL PREPARATION COMPLETE.' -ForegroundColor Green
        Write-Host ('Read and give this prompt to your AI agent: {0}' -f $setupPrompt)
        Write-Host 'After the AI fills the docs and updates the README, delete the prompt.'
        Write-Host 'Then drag the mod folder onto ReplaceRepo.cmd again to review/push.'
        Write-Host 'Nothing was pushed to GitHub.'
        exit 0
    }

    if (Test-Path -LiteralPath $setupPrompt -PathType Leaf) {
        Write-Host ''
        Write-Host ('Migration is still pending: {0}' -f $setupPrompt) -ForegroundColor Yellow
        Write-Host 'Have your AI agent complete the instructions and delete this file.'
        Write-Host 'You can repair missing issue templates from the shared template now.'
        $repair = if ($MockAutoConfirm) { 'REPAIR' } else { Read-Host 'Type REPAIR to copy missing issue templates locally (Enter to skip)' }
        if ($repair -ceq 'REPAIR') {
            Copy-SharedIssueTemplates -ModPath $modPath
            Write-Host 'Local issue template repair complete. No GitHub changes.' -ForegroundColor Green
        } else {
            Write-Host 'Nothing was changed.'
        }
        exit 0
    }

    # Ready-to-publish preflight. Never upload the old README as an unreviewed draft.
    $source = Join-Path $modPath 'src'
    if (-not (Test-Path -LiteralPath $source -PathType Container) -or
        -not (Get-ChildItem -LiteralPath $source -File -Recurse | Select-Object -First 1)) {
        throw 'src/ is empty. Move actual source files into src/ before publishing.'
    }
    foreach ($requiredFile in @(
        'mod.json', 'README.md', 'Nexus\DESCRIPTION.md', 'Nexus\CHANGELOG.md',
        'Nexus\PREREQUISITES.md', 'Nexus\COMPATIBILITY.md'
    )) {
        $actual = Join-Path $modPath $requiredFile
        if (-not (Test-Path -LiteralPath $actual -PathType Leaf)) {
            throw ('Required file is missing: {0}' -f $requiredFile)
        }
        if ((Get-Item -LiteralPath $actual).Length -eq 0) {
            throw ('Required document is empty: {0}. Complete migration before pushing.' -f $requiredFile)
        }
    }
    $readmeHash = Get-FileSha256 -Path (Join-Path $modPath 'README.md')
    $descriptionHash = Get-FileSha256 -Path (Join-Path $modPath 'Nexus\DESCRIPTION.md')
    if ($readmeHash -ne $descriptionHash) {
        throw 'README.md differs from Nexus/DESCRIPTION.md. Sync them exactly before pushing.'
    }
    Assert-CompatibilityInDescription -ModPath $modPath
    $metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
    if (-not $metadata.repository -or
        $metadata.repository.url -ne $repoPage) {
        throw 'mod.json repository.url is missing or does not match the verified repository.'
    }
    if ($metadata.repository.branch -ne $branch) {
        throw 'mod.json repository.branch differs from the current remote default branch.'
    }
    foreach ($field in @('id', 'name', 'version', 'author', 'description')) {
        if (-not $metadata.PSObject.Properties[$field] -or
            -not [string]$metadata.PSObject.Properties[$field].Value) {
            throw ('mod.json {0} is missing. Complete metadata before pushing.' -f $field)
        }
    }
    Write-Host ''
    Write-Host 'REPLACE EXISTING GITHUB REPOSITORY CONTENTS' -ForegroundColor Yellow
    Write-Host ('Local folder : {0}' -f $modPath)
    Write-Host ('Repository   : {0}' -f $repoPage)
    Write-Host ('Default branch: {0}' -f $branch)
    Write-Host ('Checkout     : {0}' -f $temporaryCheckout)
    Write-Host ''
    Write-Host 'Remote files not present locally WILL BE DELETED.' -ForegroundColor Yellow
    Write-Host 'Git history is preserved. No force push. ALL .github/, Nexus/, AI/agent files, and build files are excluded.'
    Write-Host 'You are explicitly approving a commit AND PUSH by typing REPLACE.'
    $confirmation = if ($MockAutoConfirm) { 'REPLACE' } else { Read-Host 'Type REPLACE to proceed (anything else cancels)' }
    if ($confirmation -cne 'REPLACE') { Write-Host 'Cancelled. No GitHub changes.'; exit 0 }

    # A previously prepared mod may predate the issue template discovery fix.
    # Explicit REPLACE confirmation authorizes adding missing shared forms.
    Copy-SharedIssueTemplates -ModPath $modPath
    Ensure-IgnoreRule -Path (Join-Path $modPath '.gitignore') -Rules @('/_AI/', '/Nexus/', '/.github/', '/.agents/', '/.claude/', '/.codex/', '/AGENTS.md', '/CLAUDE.md', '/GEMINI.md', '/~tmp/', '/AI_SETUP_PROMPT.md')
    Invoke-Git -Arguments @('clone', '--quiet', '--', $repoGitUrl, $temporaryCheckout)
    $checkedOutBranch = (& git -C $temporaryCheckout branch --show-current).Trim()
    if ($LASTEXITCODE -ne 0 -or $checkedOutBranch -ne $branch) {
        throw ('Checked-out branch does not match expected default branch: {0}' -f $branch)
    }
    Invoke-Git -Arguments @('-C', $temporaryCheckout, 'rm', '-r', '-f', '--ignore-unmatch', '--', '.')
    Invoke-Git -Arguments @('-C', $temporaryCheckout, 'clean', '-fdx')

    $excludedDirs = @('~tmp', '_AI', 'Nexus', '.github', '.agents', '.claude', '.codex', '.git', 'bin', 'obj', '.vs', '.idea', 'node_modules', 'TestResults', '.secrets')
    $excludedFiles = @('AI_SETUP_PROMPT.md', 'AGENTS.md', 'CLAUDE.md', 'GEMINI.md', '*.user', '*.suo', '*.tmp', '*.log', '*.bak', '*.cache', '.env', '.env.*', '*.pfx', '*.pem', '*.key')
    $copyArgs = @($modPath, $temporaryCheckout, '/E', '/XJ', '/R:1', '/W:1', '/COPY:DAT', '/DCOPY:DAT', '/NFL', '/NDL', '/NJH', '/NJS', '/NP', '/XD') + $excludedDirs + @('/XF') + $excludedFiles
    & robocopy.exe @copyArgs | Out-Null
    if ($LASTEXITCODE -ge 8) { throw ('robocopy failed with exit code {0}.' -f $LASTEXITCODE) }

    $stagedReadme = Join-Path $temporaryCheckout 'README.md'
    $stagedDescription = Join-Path $modPath 'Nexus\DESCRIPTION.md'
    if ((Get-FileSha256 -Path $stagedReadme) -ne (Get-FileSha256 -Path $stagedDescription)) {
        throw 'Copied README and description are not identical. Refusing to push.'
    }
    Ensure-IgnoreRule -Path (Join-Path $temporaryCheckout '.gitignore') -Rules @('/_AI/', '/Nexus/', '/.github/', '/.agents/', '/.claude/', '/.codex/', '/AGENTS.md', '/CLAUDE.md', '/GEMINI.md', '/~tmp/', '/AI_SETUP_PROMPT.md')
    Invoke-Git -Arguments @('-C', $temporaryCheckout, 'add', '-A')
    $stagedNames = @(& git -C $temporaryCheckout ls-files)
    if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect staged files.' }
    if ($stagedNames -notcontains 'mod.json') { throw 'No mod.json staged. Refusing to push.' }
    if ($stagedNames -notcontains '.gitignore') { throw 'No .gitignore staged. Refusing to push.' }
    if (@($stagedNames | Where-Object { $_ -match '(^|/)(_AI|Nexus|~tmp|bin|obj|\.github|\.agents|\.claude|\.codex)/|(^|/)(AI_SETUP_PROMPT|AGENTS|CLAUDE|GEMINI)\.md$' }).Count -gt 0) {
        throw 'An AI/agent instruction, GitHub automation, Nexus, build, or private file is staged. Refusing to push.'
    }

    & git -C $temporaryCheckout diff --cached --quiet
    $diffCode = $LASTEXITCODE
    if ($diffCode -eq 0) {
        Write-Host 'No changes; remote content already matches the local files.' -ForegroundColor Green
        $completed = $true
    } elseif ($diffCode -eq 1) {
        Write-Host 'Staged replacement summary:' -ForegroundColor Cyan
        Invoke-Git -Arguments @('--no-pager', '-C', $temporaryCheckout, 'diff', '--cached', '--stat')
        Invoke-Git -Arguments @('-C', $temporaryCheckout, 'commit', '-m', ('Replace {0} repository files with updated local mod' -f $modName))
        Invoke-Git -Arguments @('-C', $temporaryCheckout, 'push', 'origin', ('HEAD:refs/heads/{0}' -f $branch))
        if ($mockMode) {
            Write-Host ('MOCK: committed to local test repository only: {0}' -f $repoGitUrl) -ForegroundColor Green
        } else {
            Write-Host ('Successfully updated: {0}' -f $repoPage) -ForegroundColor Green
        }
        $completed = $true
    } else {
        throw ('git diff returned unexpected exit code {0}.' -f $diffCode)
    }
} catch {
    Write-Host ''
    Write-Host ('ERROR: {0}' -f $_.Exception.Message) -ForegroundColor Red
    if ($temporaryCheckout -and (Test-Path -LiteralPath $temporaryCheckout)) {
        Write-Host ('Preserved checkout for inspection: {0}' -f $temporaryCheckout)
    }
    exit 1
} finally {
    if ($completed -and $temporaryCheckout -and (Test-Path -LiteralPath $temporaryCheckout)) {
        try {
            Remove-Item -LiteralPath $temporaryCheckout -Recurse -Force -ErrorAction Stop
            Write-Host 'Removed temporary ~tmp checkout.'
        } catch {
            Write-Warning ('Push succeeded but could not delete ~tmp: {0}' -f $_.Exception.Message)
        }
    }
}
