# Silence alerts while a deploy runs, and close the window when it is done. PowerShell 7+ (or 5.1).
#
#   ./Maintenance.ps1 open    prints the new window's id
#   ./Maintenance.ps1 close   closes the window in WINDOW_ID
#
#   INFRANEST_TOKEN  a token with Monitoring → Write
#   INFRANEST_ORG    your organization's id
#   CHECK_IDS        the monitors to silence, comma-separated (open)
#   NAME, MINUTES    what it is called (default Deploy) and how long at most (default 30) (open)
#   DEPLOY_ID        unique per deploy, e.g. your CI's pipeline id: a retried step opens one window
#   WINDOW_ID        the window to close (close)
param([Parameter(Mandatory)][ValidateSet('open', 'close')][string]$Action)
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

$org = Get-Required 'INFRANEST_ORG'

if ($Action -eq 'open') {
    $now = [DateTime]::UtcNow
    $minutes = if ($env:MINUTES) { [int]$env:MINUTES } else { 30 }
    $name = if ($env:NAME) { $env:NAME } else { 'Deploy' }
    $deploy = if ($env:DEPLOY_ID) { $env:DEPLOY_ID } else { [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() }
    $window = Invoke-InfraNest -Method POST -Path "/organizations/$org/maintenance-windows" -Body @{
        name            = $name
        starts_at       = $now.ToString('yyyy-MM-ddTHH:mm:ssZ')
        ends_at         = $now.AddMinutes($minutes).ToString('yyyy-MM-ddTHH:mm:ssZ')
        suppress_alerts = $true
        check_ids       = @((Get-Required 'CHECK_IDS').Split(',') | ForEach-Object { [int]$_ })
    } -IdempotencyKey "deploy-$deploy"
    Write-Output $window.id
} else {
    $windowId = Get-Required 'WINDOW_ID'
    Invoke-InfraNest -Method PATCH -Path "/organizations/$org/maintenance-windows/$windowId/complete" | Out-Null
    Write-Output "Maintenance window $windowId closed; alerts are back on."
}
