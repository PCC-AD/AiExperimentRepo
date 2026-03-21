#Requires -Version 5.1
<#
.SYNOPSIS
  Reads ngrok's local inspector API and prints the Cursor OpenAI base URL (…/v1).

.DESCRIPTION
  Use when ngrok is already running (e.g. started manually). Default inspector is http://127.0.0.1:4040.
#>
param(
    [string]$NgrokWebAddr = '127.0.0.1:4040',
    [switch]$SkipClipboard
)

$ErrorActionPreference = 'Stop'

$api = "http://$NgrokWebAddr/api/tunnels"
$data = Invoke-RestMethod -Uri $api -TimeoutSec 5
if (-not $data.tunnels) {
    throw "No tunnels from $api. Is ngrok running?"
}
$https = $data.tunnels | Where-Object { $_.public_url -match '^https://' } | Select-Object -First 1
if (-not $https) {
    throw 'No HTTPS tunnel found in ngrok response.'
}
$baseUrl = ($https.public_url.TrimEnd('/') + '/v1')

Write-Host $baseUrl
$outFile = Join-Path $PSScriptRoot '.last-cursor-ollama-base-url.txt'
Set-Content -LiteralPath $outFile -Value $baseUrl -Encoding utf8

if (-not $SkipClipboard) {
    try {
        Set-Clipboard -Value $baseUrl
        Write-Host '(Copied to clipboard.)' -ForegroundColor DarkGray
    } catch { }
}
