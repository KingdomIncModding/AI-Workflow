# Fully offline, isolated test of RepoReplace's PREPARE -> REPLACE pipeline.
# The original dragged folder is read-only. Git commits/pushes target a LOCAL bare repo.
param(
    [Parameter(Mandatory = $true)]
    [string]$ModFolder
)

$ErrorActionPreference = 'Stop'
$scriptRoot = $PSScriptRoot
$runRoot = $null
$stage = 'Starting'

function Invoke-GitChecked {
    param([string[]]$Arguments)
    & git @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw ('Local Git command failed (exit {0}): git {1}' -f $LASTEXITCODE, ($Arguments -join ' '))
    }
}

function Write-Utf8 {
    param([string]$Path, [string]$Content)
    $parent = Split-Path -Path $Path -Parent
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -Path $parent -ItemType Directory -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($Path, $Content, ([System.Text.UTF8Encoding]::new($false)))
}

function Set-IfBlank {
    param([object]$Object, [string]$Name, [object]$Value)
    if (-not $Object.PSObject.Properties[$Name]) {
        $Object | Add-Member -MemberType NoteProperty -Name $Name -Value $Value
    } elseif ([string]::IsNullOrWhiteSpace([string]$Object.PSObject.Properties[$Name].Value)) {
        $Object.PSObject.Properties[$Name].Value = $Value
    }
}

try {
    $source = Get-Item -LiteralPath $ModFolder -ErrorAction Stop
    if (-not $source.PSIsContainer) { throw 'Drag a folder, not a file.' }
    if ($source.Name -notmatch '^[A-Za-z0-9._-]+$') { throw 'Unsupported mod folder name.' }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'Git for Windows is required for the mock.' }
    if (-not (Get-Command robocopy.exe -ErrorAction SilentlyContinue)) { throw 'Windows robocopy.exe is required.' }

    $templateRoot = [System.IO.Path]::GetFullPath((Join-Path $scriptRoot '..\..\_Workflows\_ModTemplate'))
    if (-not (Test-Path -LiteralPath $templateRoot -PathType Container)) {
        throw ('Shared mod template missing: {0}. This tool has no bundled template.' -f $templateRoot)
    }
    Write-Host ('Shared template    : {0}' -f $templateRoot)
    $modName = $source.Name
    $repoName = if ($modName.StartsWith('KingdomInc_', [StringComparison]::OrdinalIgnoreCase)) { $modName.Substring('KingdomInc_'.Length) } else { $modName }
    $repoPage = 'https://github.com/KingdomIncModding/' + $repoName
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    # Store test copies outside both the real mod and the shared _AI documentation.
    $runRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('KingdomInc_RepoReplace_Mock\{0}-{1}-{2}' -f $modName, $timestamp, ([guid]::NewGuid().ToString('N').Substring(0,6)))
    $working = Join-Path $runRoot $modName
    $bare = Join-Path $runRoot 'mock-remote.git'
    $seed = Join-Path $runRoot 'seed'
    $report = Join-Path $runRoot 'REPORT.txt'

    Write-Host '*** REPOREPLACE OFFLINE MOCK TEST ***' -ForegroundColor Cyan
    Write-Host ('Source (read-only) : {0}' -f $source.FullName)
    Write-Host ('Expected GitHub    : {0}' -f $repoPage)
    Write-Host ('Test workspace     : {0}' -f $runRoot)
    Write-Host 'NO GitHub connections. NO GitHub changes. NO source folder changes.' -ForegroundColor Yellow
    Write-Host ''
    $answer = Read-Host 'Type MOCK to make an isolated copy and run both stages'
    if ($answer -cne 'MOCK') { Write-Host 'Cancelled. No files created.'; exit 0 }

    $stage = 'Creating isolated working copy'
    New-Item -Path $working -ItemType Directory -Force | Out-Null
    $excludedDirs = @('_AI', '~tmp', '.git', 'bin', 'obj', '.vs', '.idea', 'node_modules', 'TestResults', '.secrets')
    $copyArgs = @($source.FullName, $working, '/E', '/XJ', '/R:1', '/W:1', '/COPY:DAT', '/DCOPY:DAT', '/NFL', '/NDL', '/NJH', '/NJS', '/NP', '/XD') + $excludedDirs
    & robocopy.exe @copyArgs | Out-Null
    if ($LASTEXITCODE -ge 8) { throw ('Failed to copy mod into mock workspace. Robocopy exit code {0}.' -f $LASTEXITCODE) }

    $branch = 'main'
    $localMeta = Join-Path $working 'mod.json'
    if (Test-Path -LiteralPath $localMeta -PathType Leaf) {
        $current = Get-Content -LiteralPath $localMeta -Raw | ConvertFrom-Json
        if ($current.repository -and $current.repository.branch) {
            $branch = [string]$current.repository.branch
        }
    }
    if ($branch -notmatch '^[A-Za-z0-9][A-Za-z0-9._/-]*$' -or $branch -match '(\.\.|//|/$|\.$)') {
        throw ('Invalid local default branch name: {0}' -f $branch)
    }

    $stage = 'Seeding simulated existing repository'
    New-Item -ItemType Directory -Path $seed -Force | Out-Null
    Invoke-GitChecked -Arguments @('init', '--bare', '--quiet', '--', $bare)
    Invoke-GitChecked -Arguments @('init', '--quiet', '--', $seed)
    Invoke-GitChecked -Arguments @('-C', $seed, 'checkout', '-q', '-b', $branch)
    Write-Utf8 (Join-Path $seed 'legacy-repository-file.txt') "This file exists in the mock's OLD repository only.`n"
    Invoke-GitChecked -Arguments @('-C', $seed, 'add', '-A')
    Invoke-GitChecked -Arguments @('-C', $seed, '-c', 'user.name=KingdomInc Mock', '-c', 'user.email=mock@local.invalid', 'commit', '--quiet', '-m', 'Seed mock existing repository')
    Invoke-GitChecked -Arguments @('-C', $seed, 'remote', 'add', 'origin', $bare)
    Invoke-GitChecked -Arguments @('-C', $seed, 'push', '--quiet', 'origin', ('HEAD:refs/heads/{0}' -f $branch))
    Invoke-GitChecked -Arguments @('-C', $bare, 'symbolic-ref', 'HEAD', ('refs/heads/{0}' -f $branch))

    # Identity is private to the child process; no global Git configuration changes.
    $env:GIT_AUTHOR_NAME = 'KingdomInc Mock'
    $env:GIT_AUTHOR_EMAIL = 'mock@local.invalid'
    $env:GIT_COMMITTER_NAME = 'KingdomInc Mock'
    $env:GIT_COMMITTER_EMAIL = 'mock@local.invalid'

    $stage = 'Running real PREPARE logic against the isolated copy'
    Write-Host '[1/3] Mock PREPARE' -ForegroundColor Cyan
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptRoot 'ReplaceRepo.ps1') -ModFolder $working -MockRemotePath $bare -MockAutoConfirm
    if ($LASTEXITCODE -ne 0) { throw ('Mock PREPARE failed, exit {0}.' -f $LASTEXITCODE) }
    $prompt = Join-Path $working 'AI_SETUP_PROMPT.md'
    if (-not (Test-Path -LiteralPath $prompt)) { throw 'Mock PREPARE did not create the expected AI handoff prompt.' }

    # All issue templates present in the one shared template must be found in
    # the prepared isolated mod. Never infer particular template filenames.
    $sharedIssueDirectory = Join-Path (Join-Path $templateRoot '.github') 'ISSUE_TEMPLATE'
    $sharedIssues = @()
    if (Test-Path -LiteralPath $sharedIssueDirectory -PathType Container) {
        $sharedIssues = @(Get-ChildItem -LiteralPath $sharedIssueDirectory -File -Force |
            Where-Object { @('.yml', '.yaml', '.md') -contains $_.Extension.ToLowerInvariant() })
    }
    foreach ($issue in $sharedIssues) {
        $installed = Join-Path (Join-Path (Join-Path $working '.github') 'ISSUE_TEMPLATE') $issue.Name
        if (-not (Test-Path -LiteralPath $installed -PathType Leaf)) {
            throw ('PREPARE did not copy shared issue template: {0}' -f $issue.FullName)
        }
    }
    Write-Host ('Issue templates verified in mock PREPARE: {0}' -f $sharedIssues.Count)

    $stage = 'Filling isolated fake documentation (AI is NOT run)'
    Write-Host '[2/3] Supply mock-only text to exercise the publishing gates' -ForegroundColor Cyan
    # These strings are never written to the real mod and never sent to GitHub.
    $descriptionPath = Join-Path $working 'Nexus\DESCRIPTION.md'
    $existingDescription = if ((Test-Path -LiteralPath $descriptionPath) -and (Get-Item $descriptionPath).Length -gt 0) {
        Get-Content -LiteralPath $descriptionPath -Raw
    } else { "# $modName`n`nSample description for the offline repository test.`n" }
    # The mock simulates the agent adding compatibility to the public text.
    # It must not alter the user's actual mod, only the isolated TEMP copy.
    $mockCompatibilitySection = "`n`n## Compatibility`n`nNo hooks identified in this offline test.`n"
    if ($existingDescription -notmatch '(?im)^#{1,6}\s+Compatibility\s*$') {
        $existingDescription = $existingDescription.TrimEnd() + $mockCompatibilitySection
    }
    Write-Utf8 -Path $descriptionPath -Content $existingDescription
    Write-Utf8 -Path (Join-Path $working 'README.md') -Content $existingDescription
    foreach ($entry in @(
        @('CHANGELOG.md', "# Changelog`n`n- Offline test entry.`n"),
        @('PREREQUISITES.md', "# Prerequisites`n`nNo requirements identified in this offline test.`n"),
        @('COMPATIBILITY.md', "# Compatibility`n`nNo hooks identified in this offline test.`n")
    )) {
        $doc = Join-Path $working ('Nexus\' + [string]$entry[0])
        if (-not (Test-Path -LiteralPath $doc) -or (Get-Item -LiteralPath $doc).Length -eq 0) {
            Write-Utf8 -Path $doc -Content ([string]$entry[1])
        }
    }
    # Test synthetic compatibility text, not real mod hooks: no AI pass is run.
    Write-Utf8 -Path (Join-Path $working 'Nexus\COMPATIBILITY.md') -Content "# Compatibility`n`nNo hooks identified in this offline test.`n"
    $meta = Get-Content -LiteralPath $localMeta -Raw | ConvertFrom-Json
    Set-IfBlank $meta 'id' $modName
    Set-IfBlank $meta 'name' $modName
    Set-IfBlank $meta 'version' '0.0.0-mock'
    Set-IfBlank $meta 'author' 'Mock Test'
    Set-IfBlank $meta 'description' 'Offline mock of the migration and replacement process.'
    $meta.repository.branch = $branch
    $metaJson = $meta | ConvertTo-Json -Depth 16
    Write-Utf8 -Path $localMeta -Content ($metaJson + "`n")
    # Migration preflight requires source in src/. For an empty-source legacy mod,
    # create a fake source file ONLY in the isolated mock copy.
    $mockSrc = Join-Path $working 'src'
    if (-not (Get-ChildItem -LiteralPath $mockSrc -File -Recurse | Select-Object -First 1)) {
        Write-Utf8 -Path (Join-Path $mockSrc 'RepoReplaceMock.cs') -Content ('// Mock-only test source; never put in real mods.' + [Environment]::NewLine)
    }
    Remove-Item -LiteralPath $prompt -Force
    # Synthetic local-only files prove that REPLACE never uploads them.
    Write-Utf8 -Path (Join-Path $working 'AGENTS.md') -Content 'Local agent instructions - never upload.'
    Write-Utf8 -Path (Join-Path $working '.github\workflows\automation.yml') -Content 'name: forbidden'
    Write-Utf8 -Path (Join-Path $working '.agents\local.txt') -Content 'Private agent work.'

    $stage = 'Running real REPLACE logic against the local bare repository'
    Write-Host '[3/3] Mock REPLACE and commit/push to LOCAL test repository ONLY' -ForegroundColor Cyan
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptRoot 'ReplaceRepo.ps1') -ModFolder $working -MockRemotePath $bare -MockAutoConfirm
    if ($LASTEXITCODE -ne 0) { throw ('Mock REPLACE failed, exit {0}.' -f $LASTEXITCODE) }

    $stage = 'Verifying locally simulated Git history and files'
    $names = @(& git --git-dir=$bare ls-tree -r --name-only ('refs/heads/{0}' -f $branch))
    if ($LASTEXITCODE -ne 0) { throw 'Cannot read simulated Git tree.' }
    if ($names -notcontains 'mod.json' -or $names -notcontains 'README.md' -or $names -notcontains '.gitignore') {
        throw 'Simulated repository is missing mod.json, README.md, or .gitignore.'
    }
    if ($names -contains 'Nexus/DESCRIPTION.md') { throw 'Nexus files were committed despite .gitignore.' }
    if ($names -contains 'legacy-repository-file.txt') { throw 'Old repository file was not removed.' }
    foreach ($issue in $sharedIssues) {
        $expectedPath = '.github/ISSUE_TEMPLATE/' + $issue.Name
        if ($names -contains $expectedPath) {
            throw ('Ignored issue template was included in the mock repository: {0}' -f $expectedPath)
        }
    }
    if (@($names | Where-Object { $_ -match '(^|/)(_AI|Nexus|~tmp|bin|obj|\.github|\.agents|\.claude|\.codex)/|(^|/)(AI_SETUP_PROMPT|AGENTS|CLAUDE|GEMINI)\.md$' }).Count -gt 0) {
        throw 'AI, agent, .github, Nexus, or temporary files were committed to the simulated repository.'
    }
    $shortHash = @(& git --git-dir=$bare rev-parse --short ('refs/heads/{0}' -f $branch))
    $result = @(
        'RESULT: PASS',
        'Mode: OFFLINE MOCK - NOT A REAL GITHUB UPDATE',
        ('Source untouched: {0}' -f $source.FullName),
        ('Template used (read-only): {0}' -f $templateRoot),
        ('GitHub repository inferred (NOT contacted): {0}' -f $repoPage),
        ('Mock branch (not verified against GitHub): {0}' -f $branch),
        ('Simulated local commit: {0}' -f ($shortHash -join '')),
        ('Isolated prepared mod: {0}' -f $working),
        ('Local bare test repository: {0}' -f $bare),
        ('Files committed to mock: {0}' -f $names.Count),
        ('Shared issue templates copied locally, excluded from GitHub: {0}' -f $sharedIssues.Count),
        'Existing README preserved as a draft by PREPARE; actual AI editing was NOT tested.',
        'Mock content was inserted into the ISOLATED copy only.',
        'The real GitHub remote, existing issues, tags and releases were not touched.'
    )
    Write-Utf8 -Path $report -Content (($result -join "`r`n") + "`r`n")
    Write-Host ''
    Write-Host 'MOCK TEST PASSED. NO GitHub changes. NO original mod changes.' -ForegroundColor Green
    Write-Host ('Report: {0}' -f $report)
    Write-Host ('Sandbox: {0}' -f $runRoot)
    exit 0
} catch {
    Write-Host ''
    Write-Host ('MOCK FAILED at [{0}]: {1}' -f $stage, $_.Exception.Message) -ForegroundColor Red
    if ($runRoot) {
        $failureReport = Join-Path $runRoot 'REPORT.txt'
        try {
            Write-Utf8 -Path $failureReport -Content ('RESULT: FAIL' + "`r`n" + ('Stage: {0}' -f $stage) + "`r`n" + $_.Exception.Message + "`r`n")
            Write-Host ('Inspect the isolated test directory: {0}' -f $runRoot)
        } catch { }
    }
    exit 1
}
