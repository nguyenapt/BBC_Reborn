# One-time RTDB migrate: grammar_by_episode/{episodeId}/line_{k} (old 1-based keys)
# -> line_{k-1} (0-based). Run BEFORE deploying app/playMP3 with 0-based lineKey convention.
#
# Requires: curl, jq (optional for validation). Set $BaseUrl to your RTDB root (no trailing slash).
# Usage: .\migrate_grammar_line_keys.ps1 -EpisodeId "your-episode-guid" [-DryRun]

param(
    [Parameter(Mandatory = $true)]
    [string] $EpisodeId,
    [string] $BaseUrl = "https://bbc-listening-english.firebaseio.com/ai_cache/grammar_by_episode",
    [switch] $DryRun
)

$safeEp = $EpisodeId.Trim() -replace '[\.\$#\[\]/]', '_'
$epUrl = "$BaseUrl/$safeEp.json"

Write-Host "GET $epUrl"
$json = Invoke-RestMethod -Uri $epUrl -Method Get
if ($null -eq $json) { Write-Host "No data."; exit 0 }

$lineKeys = @($json.PSObject.Properties.Name | Where-Object { $_ -match '^line_\d+$' } | Sort-Object {
    [int]($_ -replace '^line_', '')
} -Descending)

foreach ($oldKey in $lineKeys) {
    $n = [int]($oldKey -replace '^line_', '')
    if ($n -lt 1) { continue }
    $newKey = "line_$($n - 1)"
    Write-Host "$oldKey -> $newKey"
    if ($DryRun) { continue }
    $node = $json.$oldKey
    $putUrl = "$BaseUrl/$safeEp/$newKey.json"
    Invoke-RestMethod -Uri $putUrl -Method Put -Body ($node | ConvertTo-Json -Depth 20) -ContentType "application/json"
    $delUrl = "$BaseUrl/$safeEp/$oldKey.json"
    Invoke-RestMethod -Uri $delUrl -Method Delete
}

Write-Host "Done. Re-run upload from playMP3 to refresh data.lineKey / lineNumber in payloads."
