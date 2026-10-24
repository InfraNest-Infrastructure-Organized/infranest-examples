# Keep one A (or AAAA) record pointing at this machine's public address. PowerShell 7+ (or Windows PowerShell 5.1).
# Run it every few minutes from Task Scheduler.
#
#   INFRANEST_TOKEN  a token with DNS → Write
#   INFRANEST_ORG    your organization's id
#   ZONE_ID, RECORD_ID  the zone and the record to keep up to date
#   FAMILY           4 (default) or 6
#   DRY_RUN          1 to only show what would change
$ErrorActionPreference = 'Stop'

$Api = if ($env:INFRANEST_API) { $env:INFRANEST_API } else { 'https://api.infranest.io/api' }
if (-not $env:INFRANEST_TOKEN) { throw 'Set INFRANEST_TOKEN to an InfraNest API token' }

# Calls the InfraNest API and returns the answer. Throws, with the API's error, on a refusal.
function Invoke-InfraNest {
    param([string]$Method, [string]$Path, [hashtable]$Body, [string]$IdempotencyKey)
    $headers = @{ Authorization = "Bearer $env:INFRANEST_TOKEN"; Accept = 'application/json' }
    if ($Body) {
        if ($IdempotencyKey) { $headers['Idempotency-Key'] = $IdempotencyKey }
        return Invoke-RestMethod -Method $Method -Uri ($Api + $Path) -Headers $headers -ContentType 'application/json' -Body ($Body | ConvertTo-Json -Depth 5)
    }
    return Invoke-RestMethod -Method $Method -Uri ($Api + $Path) -Headers $headers
}

function Get-Required([string]$Name) {
    $value = [Environment]::GetEnvironmentVariable($Name)
    if (-not $value) { throw "Set $Name" }
    return $value
}

$org = Get-Required 'INFRANEST_ORG'; $zone = Get-Required 'ZONE_ID'; $record = Get-Required 'RECORD_ID'
$lookup = if ($env:FAMILY -eq '6') { 'https://api64.ipify.org' } else { 'https://api.ipify.org' }
$current = (Invoke-RestMethod -Uri $lookup).Trim()

$stored = (Invoke-InfraNest -Method GET -Path "/organizations/$org/dns-zones/$zone/dns-records/$record").value
if ($current -eq $stored) { exit 0 }

if ($env:DRY_RUN -eq '1') {
    (Invoke-InfraNest -Method PUT -Path "/organizations/$org/dns-zones/$zone/dns-records/${record}?dry_run=1" -Body @{ value = $current; ttl = 300 }).changes | ConvertTo-Json -Depth 5
} else {
    Invoke-InfraNest -Method PUT -Path "/organizations/$org/dns-zones/$zone/dns-records/$record" -Body @{ value = $current; ttl = 300 } | Out-Null
    Write-Output "Updated from $stored to $current"
}
