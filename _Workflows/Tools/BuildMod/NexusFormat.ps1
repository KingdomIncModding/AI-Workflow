# NexusFormat.ps1 - Single-mod README sync, Markdown-to-BBCode converter, and changelog extractor.
# Scoped strictly to a single mod folder. Never reads other mods or OpenAPI specs.
# Safe to dot-source (no top-level param block to clobber caller variables) or run directly via -File.

$ErrorActionPreference = 'Stop'

function Save-Utf8NoBom {
    param([string]$Path, [string]$Content)
    [System.IO.File]::WriteAllText($Path, $Content, ([System.Text.UTF8Encoding]::new($false)))
}

function Save-ModJson {
    param([string]$Path, [object]$Metadata)
    $json = $Metadata | ConvertTo-Json -Depth 16
    Save-Utf8NoBom -Path $Path -Content ($json + [Environment]::NewLine)
}

function Convert-InlineMarkdownToBBCode {
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return '' }
    $out = $Text

    # Convert inline code `code` -> [b]code[/b]
    $out = [regex]::Replace($out, '`([^`]+)`', '[b]$1[/b]')

    # Convert links [label](url) -> [url=url]label[/url]
    $out = [regex]::Replace($out, '\[([^\]]+)\]\((https?://[^)\s]+)\)', '[url=$2]$1[/url]')

    # Convert bold **text** -> [b]text[/b]
    $out = [regex]::Replace($out, '\*\*([^*]+)\*\*', '[b]$1[/b]')

    # Convert italic *text* (not inside words or BBCode [*] bullets) -> [i]text[/i]
    $out = [regex]::Replace($out, '(?<![\[*\w])\*([^*\r\n]+)\*(?![\]*\w])', '[i]$1[/i]')

    return $out
}

function Get-ExistingBBCodePalette {
    param([string]$BBCodePath)
    $palette = @{
        TitleColor      = '#F2B552'
        SectionColor    = '#65C7E8'
        SubsectionColor = '#F4B860'
    }
    if (-not (Test-Path -LiteralPath $BBCodePath -PathType Leaf)) {
        return $palette
    }
    $raw = [System.IO.File]::ReadAllText($BBCodePath)
    $lines = @($raw -split '\r?\n')
    foreach ($line in $lines) {
        if ($line -match '^\[color=(#[0-9A-Fa-f]{6})\]\[b\].+\[/b\]\[/color\]\s*$') {
            $palette.TitleColor = $Matches[1]
            break
        }
    }
    $sectionMatches = [regex]::Matches($raw, '(?m)^\[color=(#[0-9A-Fa-f]{6})\]\[b\](?!Better |Global |Foundation)[^\r\n]+\[/b\]\[/color\]\s*$')
    if ($sectionMatches.Count -ge 2) {
        $palette.SectionColor = $sectionMatches[1].Groups[1].Value
    }
    return $palette
}

function Convert-MarkdownToNexusBBCode {
    param(
        [Parameter(Mandatory)][string]$Markdown,
        [string]$TitleColor = '#F2B552',
        [string]$SectionColor = '#65C7E8',
        [string]$SubsectionColor = '#F4B860'
    )

    $lines = @($Markdown -split '\r?\n')
    $output = New-Object System.Collections.Generic.List[string]
    $i = 0
    $count = $lines.Count

    while ($i -lt $count) {
        $line = $lines[$i]

        # Skip fenced code block markers if any accidentally exist
        if ($line -match '^\s*```') {
            $i++
            continue
        }

        # Markdown Table block
        if ($line -match '^\s*\|(.+)\|\s*$') {
            $tableLines = New-Object System.Collections.Generic.List[string]
            while ($i -lt $count -and $lines[$i] -match '^\s*\|(.+)\|\s*$') {
                $tableLines.Add($lines[$i].Trim())
                $i++
            }
            if ($tableLines.Count -gt 0) {
                $output.Add('[table]')
                $isHeader = $true
                foreach ($tLine in $tableLines) {
                    # Skip separator row like |---|---|---|
                    if ($tLine -match '^\|\s*[:\-]+(\s*\|\s*[:\-]+)+\s*\|$') {
                        $isHeader = $false
                        continue
                    }
                    $inner = $tLine.Trim('|')
                    $cells = @($inner -split '\|')
                    $output.Add('[tr]')
                    foreach ($cell in $cells) {
                        $cellText = Convert-InlineMarkdownToBBCode -Text $cell.Trim()
                        if ($isHeader) {
                            if ($cellText -notmatch '^\[b\].*\[/b\]$') {
                                $cellText = "[b]$cellText[/b]"
                            }
                        }
                        $output.Add("[td]$cellText[/td]")
                    }
                    $output.Add('[/tr]')
                    $isHeader = $false
                }
                $output.Add('[/table]')
            }
            continue
        }

        # Unordered list block (- or *), supporting 1st and 2nd level indentation
        if ($line -match '^(\s*)[-*]\s+(.+)$') {
            $output.Add('[list]')
            $inSubList = $false
            while ($i -lt $count) {
                $curr = $lines[$i]
                if ($curr -match '^(\s+)[-*]\s+(.+)$' -and $Matches[1].Length -ge 2) {
                    $itemText = Convert-InlineMarkdownToBBCode -Text $Matches[2].Trim()
                    if (-not $inSubList) {
                        $output.Add('  [list]')
                        $inSubList = $true
                    }
                    $output.Add("  [*]$itemText")
                    $i++
                }
                elseif ($curr -match '^[-*]\s+(.+)$') {
                    if ($inSubList) {
                        $output.Add('  [/list]')
                        $inSubList = $false
                    }
                    $itemText = Convert-InlineMarkdownToBBCode -Text $Matches[1].Trim()
                    $output.Add("[*]$itemText")
                    $i++
                }
                else {
                    break
                }
            }
            if ($inSubList) {
                $output.Add('  [/list]')
            }
            $output.Add('[/list]')
            continue
        }

        # Headings
        if ($line -match '^#\s+(.+)$') {
            $h1 = Convert-InlineMarkdownToBBCode -Text $Matches[1].Trim()
            $output.Add("[color=$TitleColor][b]$h1[/b][/color]")
            $i++
            continue
        }
        if ($line -match '^##\s+(.+)$') {
            $h2Raw = $Matches[1].Trim()
            $h2 = Convert-InlineMarkdownToBBCode -Text $h2Raw
            if ($h2Raw -imatch '^Compatibility$') {
                $output.Add("[size=4][b]$h2[/b][/size]")
            }
            else {
                $output.Add("[color=$SectionColor][b]$h2[/b][/color]")
            }
            $i++
            continue
        }
        if ($line -match '^###\s+(.+)$') {
            $h3 = Convert-InlineMarkdownToBBCode -Text $Matches[1].Trim()
            $output.Add("[color=$SubsectionColor][b]$h3[/b][/color]")
            $i++
            continue
        }
        if ($line -match '^#{4,6}\s+(.+)$') {
            $h4 = Convert-InlineMarkdownToBBCode -Text $Matches[1].Trim()
            $output.Add("[b]$h4[/b]")
            $i++
            continue
        }

        # Ordered list item followed by indented unordered sub-bullets
        if ($line -match '^\d+\.\s+(.+)$') {
            $output.Add((Convert-InlineMarkdownToBBCode -Text $line.Trim()))
            $i++
            if ($i -lt $count -and $lines[$i] -match '^\s{2,}[-*]\s+(.+)$') {
                $output.Add('[list]')
                while ($i -lt $count -and $lines[$i] -match '^\s{2,}[-*]\s+(.+)$') {
                    $subItem = Convert-InlineMarkdownToBBCode -Text $Matches[1].Trim()
                    $output.Add("[*]$subItem")
                    $i++
                }
                $output.Add('[/list]')
            }
            continue
        }

        # Blank line: collapse consecutive blank lines when directly before/after [list] or [table]
        if ([string]::IsNullOrWhiteSpace($line)) {
            if ($output.Count -gt 0 -and $output[$output.Count - 1] -ne '') {
                $output.Add('')
            }
            $i++
            continue
        }

        # Normal paragraph line
        $output.Add((Convert-InlineMarkdownToBBCode -Text $line))
        $i++
    }

    # Clean up blank lines immediately between a section heading and [list] or [table]
    $cleaned = New-Object System.Collections.Generic.List[string]
    for ($j = 0; $j -lt $output.Count; $j++) {
        if ($output[$j] -eq '' -and $j -gt 0 -and ($j + 1) -lt $output.Count) {
            $prev = $output[$j - 1]
            $next = $output[$j + 1]
            if (($prev -match '^\[(color|size)=.*\[/b\]\[/(color|size)\]$') -and ($next -in @('[list]', '[table]') -or $next -match '^1\.\s')) {
                continue
            }
        }
        $cleaned.Add($output[$j])
    }

    return (($cleaned -join "`r`n").Trim() + "`r`n")
}

function Test-NexusBBCode {
    param([Parameter(Mandatory)][string]$BBCode)
    $issues = New-Object System.Collections.Generic.List[string]

    if ([string]::IsNullOrWhiteSpace($BBCode)) {
        $issues.Add('BBCode content is empty.')
        return [pscustomobject]@{ IsValid = $false; ColorSpanCount = 0; Issues = $issues }
    }

    $colorOpen = ([regex]::Matches($BBCode, '\[color=#[0-9A-Fa-f]{6}\]')).Count
    $colorClose = ([regex]::Matches($BBCode, '\[/color\]')).Count
    if ($colorOpen -eq 0) {
        $issues.Add('No [color=#RRGGBB] spans found in BBCode description.')
    }
    if ($colorOpen -ne $colorClose) {
        $issues.Add("Unbalanced [color] tags: $colorOpen open vs $colorClose close.")
    }

    foreach ($tag in @('b', 'i', 'list', 'table', 'tr', 'td', 'size')) {
        $openPattern = if ($tag -eq 'size') { '\[size=[^\]]+\]' } else { "\[$tag\]" }
        $openCount = ([regex]::Matches($BBCode, $openPattern)).Count
        $closeCount = ([regex]::Matches($BBCode, "\[/$([regex]::Escape($tag))\]")).Count
        if ($openCount -ne $closeCount) {
            $issues.Add("Unbalanced [$tag] tags: $openCount open vs $closeCount close.")
        }
    }

    $urlOpen = ([regex]::Matches($BBCode, '\[url=[^\]]+\]')).Count
    $urlClose = ([regex]::Matches($BBCode, '\[/url\]')).Count
    if ($urlOpen -ne $urlClose) {
        $issues.Add("Unbalanced [url] tags: $urlOpen open vs $urlClose close.")
    }

    if ($BBCode -match '(?m)^#{1,6}\s+') {
        $issues.Add('Raw Markdown heading (#) found in BBCode.')
    }
    if ($BBCode -match '\*\*[^*]+\*\*') {
        $issues.Add('Raw Markdown bold (**...**) found in BBCode.')
    }
    if ($BBCode -match '\[[^\]]+\]\(https?://[^)]+\)') {
        $issues.Add('Raw Markdown link ([text](url)) found in BBCode.')
    }
    if ($BBCode -match '(?m)^\|\s*[:\-]+(\s*\|\s*[:\-]+)+\s*\|$') {
        $issues.Add('Raw Markdown table pipes (|---|) found in BBCode.')
    }

    return [pscustomobject]@{
        IsValid        = ($issues.Count -eq 0)
        ColorSpanCount = $colorOpen
        Issues         = @($issues)
    }
}

function Get-ModVersionChangelog {
    param(
        [Parameter(Mandatory)][string]$ChangelogPath,
        [Parameter(Mandatory)][string]$Version
    )
    if (-not (Test-Path -LiteralPath $ChangelogPath -PathType Leaf)) {
        throw "Changelog not found: $ChangelogPath"
    }
    $raw = [System.IO.File]::ReadAllText($ChangelogPath)
    $lines = @($raw -split '\r?\n')
    $escapedVer = [regex]::Escape($Version.TrimStart('v', 'V'))
    $inSection = $false
    $sectionLines = New-Object System.Collections.Generic.List[string]

    foreach ($line in $lines) {
        if ($line -match "^##\s+v?$escapedVer(\b|\s|$)") {
            $inSection = $true
            continue
        }
        if ($inSection -and $line -match '^##\s+') {
            break
        }
        if ($inSection) {
            $sectionLines.Add($line)
        }
    }

    # Fallback if no matching ## Version header was found: take all non-H1 lines
    if ($sectionLines.Count -eq 0) {
        foreach ($line in $lines) {
            if ($line -match '^#\s+') { continue }
            $sectionLines.Add($line)
        }
    }

    $markdownBody = (($sectionLines -join "`r`n").Trim())
    if ([string]::IsNullOrWhiteSpace($markdownBody)) {
        throw "No changelog content found for version $Version in $ChangelogPath"
    }

    # For Nexus changelog API: strip leading Markdown "- " or "* " bullets and section headers
    $nexusEntryLines = New-Object System.Collections.Generic.List[string]
    foreach ($line in $sectionLines) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
        if ($trimmed -match '^#{1,6}\s+') { continue }
        $cleanLine = $trimmed -replace '^[-*]\s+', ''
        # Strip inline markdown bold/code markers for plain-text Nexus changelog readability
        $cleanLine = $cleanLine -replace '\*\*([^*]+)\*\*', '$1'
        $cleanLine = $cleanLine -replace '`([^`]+)`', '$1'
        if (-not [string]::IsNullOrWhiteSpace($cleanLine)) {
            $nexusEntryLines.Add($cleanLine)
        }
    }

    return [pscustomobject]@{
        Version       = $Version
        GithubNotes   = ("## v$($Version.TrimStart('v', 'V'))`r`n`r`n" + $markdownBody + "`r`n")
        NexusNotes    = (($nexusEntryLines -join "`n").Trim())
        EntryCount    = $nexusEntryLines.Count
    }
}

function Sync-ModPublicDocs {
    param(
        [Parameter(Mandatory)][string]$ModFolder,
        [switch]$ForceRegenerateBBCode,
        [switch]$ValidateOnly
    )
    $root = (Resolve-Path -LiteralPath $ModFolder).Path.TrimEnd([char]'\', [char]'/')
    $nexusDir = Join-Path $root 'Nexus'
    $descPath = Join-Path $nexusDir 'DESCRIPTION.md'
    $compatPath = Join-Path $nexusDir 'COMPATIBILITY.md'
    $prereqPath = Join-Path $nexusDir 'PREREQUISITES.md'
    $changelogPath = Join-Path $nexusDir 'CHANGELOG.md'
    $bbcodePath = Join-Path $nexusDir 'DESCRIPTION.bbcode.txt'
    $readmePath = Join-Path $root 'README.md'

    foreach ($req in @($descPath, $compatPath, $prereqPath, $changelogPath)) {
        if (-not (Test-Path -LiteralPath $req -PathType Leaf)) {
            throw "Missing required Nexus document: $req"
        }
        if ((Get-Item -LiteralPath $req).Length -eq 0) {
            throw "Required Nexus document is empty: $req"
        }
    }

    $descContent = [System.IO.File]::ReadAllText($descPath)
    $compatContent = [System.IO.File]::ReadAllText($compatPath)
    if ($descContent -notmatch '(?im)^#{1,6}\s+Compatibility\s*$') {
        throw "DESCRIPTION.md is missing a '## Compatibility' section: $descPath"
    }
    $compatRows = @($compatContent -split '\r?\n' | Where-Object { $_ -match '^\|.*\|$' })
    foreach ($row in $compatRows) {
        if (-not $descContent.Contains($row)) {
            throw "DESCRIPTION.md is missing row from COMPATIBILITY.md: $row"
        }
    }

    # Sync DESCRIPTION.md -> README.md byte-for-byte
    if (-not $ValidateOnly) {
        Copy-Item -LiteralPath $descPath -Destination $readmePath -Force
    }
    elseif (-not (Test-Path -LiteralPath $readmePath -PathType Leaf)) {
        throw "Missing root README.md: $readmePath"
    }

    $readmeHash = (Get-FileHash -LiteralPath $readmePath -Algorithm SHA256).Hash
    $descHash = (Get-FileHash -LiteralPath $descPath -Algorithm SHA256).Hash
    if ($readmeHash -ne $descHash) {
        throw "README.md and Nexus/DESCRIPTION.md hashes do not match ($readmeHash vs $descHash)."
    }

    # Generate or validate Nexus/DESCRIPTION.bbcode.txt
    $needGenerate = $ForceRegenerateBBCode -or (-not (Test-Path -LiteralPath $bbcodePath -PathType Leaf)) -or ((Get-Item -LiteralPath $bbcodePath).Length -eq 0)
    if (-not $needGenerate -and -not $ValidateOnly) {
        # Regenerate if DESCRIPTION.md is newer than DESCRIPTION.bbcode.txt
        $descTime = (Get-Item -LiteralPath $descPath).LastWriteTimeUtc
        $bbTime = (Get-Item -LiteralPath $bbcodePath).LastWriteTimeUtc
        if ($descTime -gt $bbTime) {
            $needGenerate = $true
        }
    }

    if ($needGenerate) {
        if ($ValidateOnly) {
            throw "Nexus/DESCRIPTION.bbcode.txt is missing or empty: $bbcodePath"
        }
        $palette = Get-ExistingBBCodePalette -BBCodePath $bbcodePath
        $bbcode = Convert-MarkdownToNexusBBCode -Markdown $descContent -TitleColor $palette.TitleColor -SectionColor $palette.SectionColor -SubsectionColor $palette.SubsectionColor
        Save-Utf8NoBom -Path $bbcodePath -Content $bbcode
    }

    $finalBBCode = [System.IO.File]::ReadAllText($bbcodePath)
    $check = Test-NexusBBCode -BBCode $finalBBCode
    if (-not $check.IsValid) {
        # If existing BBCode failed validation and we haven't regenerated yet, regenerate once from Markdown
        if (-not $needGenerate -and -not $ValidateOnly) {
            $palette = Get-ExistingBBCodePalette -BBCodePath $bbcodePath
            $finalBBCode = Convert-MarkdownToNexusBBCode -Markdown $descContent -TitleColor $palette.TitleColor -SectionColor $palette.SectionColor -SubsectionColor $palette.SubsectionColor
            Save-Utf8NoBom -Path $bbcodePath -Content $finalBBCode
            $check = Test-NexusBBCode -BBCode $finalBBCode
        }
        if (-not $check.IsValid) {
            throw ("Nexus BBCode validation failed for $bbcodePath`: " + ($check.Issues -join '; '))
        }
    }

    return [pscustomobject]@{
        ModRoot        = $root
        ReadmeHash     = $readmeHash
        BBCodePath     = $bbcodePath
        ColorSpanCount = $check.ColorSpanCount
        BBCodeValid    = $check.IsValid
    }
}

if ($MyInvocation.InvocationName -ne '.' -and $args.Count -gt 0) {
    $res = Sync-ModPublicDocs @args
    Write-Host ("Synced & validated docs for {0} (SHA256: {1}, BBCode color spans: {2})" -f (Split-Path -Leaf $res.ModRoot), $res.ReadmeHash.Substring(0, 12), $res.ColorSpanCount) -ForegroundColor Green
}
