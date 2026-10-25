# Verify that a webhook delivery came from InfraNest. https://developers.infranest.io/webhooks#verify-the-signature
#
#   pwsh Verify-Webhook.ps1 BODY_FILE TIMESTAMP SIGNATURE     (TIMESTAMP '' when the header was absent)
#   INFRANEST_WEBHOOK_SECRET   the endpoint's signing secret (whsec_…)
# Exits 0 for a genuine delivery, 1 otherwise. Use Test-InfraNestSignature in your own receiver.
param([string]$BodyFile, [string]$Timestamp, [string]$Signature)

function Test-InfraNestSignature {
  param([byte[]]$RawBody, [string]$Timestamp, [string]$Signature, [string]$Secret, [int]$Tolerance = 300)
  $signed = $RawBody
  if ($Timestamp) {
    if ($Timestamp -notmatch '^\d+$') { return $false }
    if ([Math]::Abs([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - [long]$Timestamp) -gt $Tolerance) { return $false }
    $signed = [Text.Encoding]::UTF8.GetBytes("$Timestamp.") + $RawBody
  }
  $hmac = [System.Security.Cryptography.HMACSHA256]::new([Text.Encoding]::UTF8.GetBytes($Secret))
  $expected = 'sha256=' + -join ($hmac.ComputeHash($signed) | ForEach-Object { $_.ToString('x2') })
  return [System.Security.Cryptography.CryptographicOperations]::FixedTimeEquals(
    [Text.Encoding]::ASCII.GetBytes($expected), [Text.Encoding]::ASCII.GetBytes([string]$Signature))
}

if ($BodyFile) {
  $body = [System.IO.File]::ReadAllBytes((Resolve-Path $BodyFile))
  if (Test-InfraNestSignature -RawBody $body -Timestamp $Timestamp -Signature $Signature -Secret $env:INFRANEST_WEBHOOK_SECRET) { exit 0 }
  exit 1
}
