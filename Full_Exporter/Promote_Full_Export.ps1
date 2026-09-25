param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath
)

$ErrorActionPreference = 'Stop'
$project = (Resolve-Path -LiteralPath $ProjectPath).Path
$stage = Join-Path $project '.Full_Exporter_Staging'
$items = @(
    @{ Target = (Join-Path $project 'src'); Source = (Join-Path $stage 'src'); Backup = (Join-Path $project '.Full_Exporter_PreviousSrc') },
    @{ Target = (Join-Path $project 'default.project.json'); Source = (Join-Path $stage 'default.project.json'); Backup = (Join-Path $project '.Full_Exporter_PreviousProject') },
    @{ Target = (Join-Path $project 'export_manifest.json'); Source = (Join-Path $stage 'export_manifest.json'); Backup = (Join-Path $project '.Full_Exporter_PreviousManifest') }
)

foreach ($item in $items) {
    foreach ($path in @($item.Target, $item.Source, $item.Backup)) {
        if (-not $path.StartsWith($project + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Export path is outside the project: $path"
        }
    }
    if (-not (Test-Path -LiteralPath $item.Source)) { throw "Staged export is missing $($item.Source)" }
    if (Test-Path -LiteralPath $item.Backup) { throw "Previous export backup already exists: $($item.Backup)" }
}

$manifest = Get-Content -LiteralPath (Join-Path $stage 'export_manifest.json') -Raw | ConvertFrom-Json
if ($manifest.status -ne 'COMPLETE') { throw 'Staged export manifest is not COMPLETE' }
$scriptCount = (Get-ChildItem -LiteralPath (Join-Path $stage 'src') -Recurse -File | Measure-Object).Count
if ($scriptCount -ne $manifest.exportedScriptCount) {
    throw "Staged script count $scriptCount differs from manifest count $($manifest.exportedScriptCount)"
}

$backedUp = @()
$installed = @()
try {
    foreach ($item in $items) {
        if (Test-Path -LiteralPath $item.Target) {
            Move-Item -LiteralPath $item.Target -Destination $item.Backup -ErrorAction Stop
            $backedUp += $item
        }
    }
    foreach ($item in $items) {
        Move-Item -LiteralPath $item.Source -Destination $item.Target -ErrorAction Stop
        $installed += $item
    }
} catch {
    $promotionError = $_
    foreach ($item in $installed) {
        if (Test-Path -LiteralPath $item.Target) {
            Remove-Item -LiteralPath $item.Target -Recurse -Force -ErrorAction Stop
        }
    }
    foreach ($item in $backedUp) {
        if (Test-Path -LiteralPath $item.Backup) {
            Move-Item -LiteralPath $item.Backup -Destination $item.Target -ErrorAction Stop
        }
    }
    throw "Could not install the staged export; previous export restored: $promotionError"
}

foreach ($item in $backedUp) {
    try { Remove-Item -LiteralPath $item.Backup -Recurse -Force -ErrorAction Stop }
    catch { Write-Warning "Export installed, but backup cleanup failed: $($item.Backup): $_" }
}
try { Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction Stop }
catch { Write-Warning "Export installed, but staging cleanup failed: ${stage}: $_" }
Write-Output "Installed complete export with $scriptCount script files."
