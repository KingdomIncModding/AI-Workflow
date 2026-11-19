[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$ModFolder)

$ErrorActionPreference = 'Stop'
$modRoot = (Resolve-Path -LiteralPath $ModFolder).Path
if (-not (Test-Path -LiteralPath (Join-Path $modRoot 'mod.json') -PathType Leaf)) {
    throw "Expected a mod root containing mod.json: $modRoot"
}
$sources = @(Get-ChildItem -LiteralPath (Join-Path $modRoot 'src') -File -Filter '*.cs' -Recurse -ErrorAction SilentlyContinue)
if ($sources.Count -eq 0) {
    Write-Host 'Source layout OK: no C# source yet.'
    return
}
$artifacts = Join-Path $modRoot '_AI\Scratch\SourceLayout'
$project = Join-Path $PSScriptRoot 'SourceLayout.csproj'
& dotnet build $project --configuration Release --artifacts-path $artifacts --nologo --verbosity quiet
if ($LASTEXITCODE -ne 0) { throw 'Could not build the source-layout checker (.NET 10 SDK required).' }
$checker = Join-Path $artifacts 'bin\SourceLayout\release\SourceLayout.dll'
& dotnet $checker $modRoot
if ($LASTEXITCODE -ne 0) { throw 'Source-layout validation failed; no source files were changed.' }
