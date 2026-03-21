#Requires -Version 5.1
<#
.SYNOPSIS
  Starts an ngrok HTTPS tunnel to local Ollama and prints the Cursor "Override OpenAI Base URL" value.

.DESCRIPTION
  Resolves the Ollama port (OLLAMA_HOST, -Port, or auto-detect). If ngrok is already serving
  the local inspector on 4040, reuses the active tunnel URL when possible.

  Optional: set environment variable NGROK_AUTHTOKEN so the first run can call
  ngrok config add-authtoken without manual steps.

.PARAMETER Port
  Ollama listen port. Default 0 = auto (OLLAMA_HOST, then 11434, then scan 11435-11450).

.PARAMETER NgrokWebAddr
  Where to read ngrok's local JSON API (default 127.0.0.1:4040). If you moved the inspector
  in ngrok.yml (web_addr / agent.web_addr), pass the same host:port here.

.PARAMETER NoNewWindow
  Run ngrok attached to this console (blocks until you Ctrl+C). Useful for Task Scheduler or CI.

.PARAMETER SkipClipboard
  Do not copy the base URL to the clipboard.
#>
[CmdletBinding()]
param(
    [ValidateRange(0, 65535)]
    [int]$Port = 0,

    [string]$NgrokWebAddr = '127.0.0.1:4040',

    [switch]$NoNewWindow,

    [switch]$SkipClipboard
)

$ErrorActionPreference = 'Stop'

function Get-NgrokExe {
    $cmd = Get-Command ngrok -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')
    $cmd = Get-Command ngrok -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    throw 'ngrok not found on PATH. Install with: winget install Ngrok.Ngrok (then open a new terminal).'
}

function Test-OllamaPort {
    param([int]$PortToTest)
    try {
        $r = Invoke-RestMethod -Uri "http://127.0.0.1:$PortToTest/api/tags" -TimeoutSec 3
        return ($null -ne $r.models)
    } catch {
        return $false
    }
}

function Resolve-OllamaPort {
    param([int]$ExplicitPort)

    if ($ExplicitPort -gt 0) {
        if (-not (Test-OllamaPort -PortToTest $ExplicitPort)) {
            throw "Ollama API not responding on 127.0.0.1:$ExplicitPort (/api/tags). Set OLLAMA_HOST or fix the service."
        }
        return $ExplicitPort
    }

    $raw = $env:OLLAMA_HOST
    if ($raw) {
        if ($raw -match '^(.+):(\d+)$') {
            $p = [int]$Matches[2]
            if (Test-OllamaPort -PortToTest $p) { return $p }
            throw "OLLAMA_HOST=$raw but Ollama did not respond on port $p."
        }
        throw "OLLAMA_HOST='$raw' - expected host:port (e.g. 127.0.0.1:11434)."
    }

    if (Test-OllamaPort -PortToTest 11434) { return 11434 }

    foreach ($p in 11435..11450) {
        if (Test-OllamaPort -PortToTest $p) {
            Write-Host ('Using Ollama on port ' + $p + ' - default 11434 was not Ollama.') -ForegroundColor Yellow
            return $p
        }
    }

    throw 'Could not find Ollama on 127.0.0.1 ports 11434-11450. Start Ollama or set OLLAMA_HOST / -Port.'
}

function Get-NgrokBaseUrlFromInspector {
    param([string]$WebAddr)

    $api = "http://$WebAddr/api/tunnels"
    try {
        $data = Invoke-RestMethod -Uri $api -TimeoutSec 2
    } catch {
        return $null
    }
    if (-not $data.tunnels) { return $null }
    $https = $data.tunnels | Where-Object { $_.public_url -match '^https://' } | Select-Object -First 1
    if (-not $https) { return $null }
    return ($https.public_url.TrimEnd('/') + '/v1')
}

function Test-NgrokAuthed {
    $cfg = Join-Path $env:LOCALAPPDATA 'ngrok\ngrok.yml'
    if (-not (Test-Path -LiteralPath $cfg)) { return $false }
    $content = Get-Content -LiteralPath $cfg -Raw
    return $content -match 'authtoken\s*:\s*\S+'
}

$ngrok = Get-NgrokExe

if (-not (Test-NgrokAuthed)) {
    if ($env:NGROK_AUTHTOKEN) {
        & $ngrok config add-authtoken $env:NGROK_AUTHTOKEN
        if (-not (Test-NgrokAuthed)) {
            throw 'ngrok config add-authtoken did not create a valid ngrok.yml (check NGROK_AUTHTOKEN).'
        }
    } else {
        Write-Host ''
        Write-Host 'ngrok is not authenticated yet. One-time setup:' -ForegroundColor Yellow
        Write-Host '  1. Copy your authtoken from https://dashboard.ngrok.com/get-started/your-authtoken'
        Write-Host '  2. Run: ngrok config add-authtoken YOUR_TOKEN'
        Write-Host '     Or set env NGROK_AUTHTOKEN and run this script again.'
        Write-Host ''
        Write-Host 'Then run this script again.' -ForegroundColor Yellow
        exit 1
    }
}

$ollamaPort = Resolve-OllamaPort -ExplicitPort $Port

$existing = Get-NgrokBaseUrlFromInspector -WebAddr $NgrokWebAddr
if ($existing) {
    Write-Host "ngrok inspector at $NgrokWebAddr already has a tunnel; reusing URL." -ForegroundColor Cyan
    $baseUrl = $existing
} else {
    $hostHeader = "localhost:$ollamaPort"
    $target = "http://127.0.0.1:$ollamaPort"
    $ngrokArgs = @('http', $target, '--host-header', $hostHeader)

    if ($NoNewWindow) {
        Write-Host "Starting ngrok in the foreground (Ctrl+C to stop). Tunnel -> $target" -ForegroundColor Cyan
        Write-Host "When the tunnel is up, run in another terminal: .\Get-NgrokCursorBaseUrl.ps1 -NgrokWebAddr $NgrokWebAddr" -ForegroundColor DarkGray
        & $ngrok @ngrokArgs
        exit $LASTEXITCODE
    }

    Start-Process -FilePath $ngrok -ArgumentList $ngrokArgs -WindowStyle Normal
    Write-Host 'Waiting for ngrok tunnel (local inspector API)...' -ForegroundColor Cyan

    $baseUrl = $null
    for ($i = 0; $i -lt 60; $i++) {
        Start-Sleep -Milliseconds 500
        $baseUrl = Get-NgrokBaseUrlFromInspector -WebAddr $NgrokWebAddr
        if ($baseUrl) { break }
    }
    if (-not $baseUrl) {
        throw 'Timed out waiting for ngrok tunnel. Check the ngrok window for errors (auth, network).'
    }
}

$outFile = Join-Path $PSScriptRoot '.last-cursor-ollama-base-url.txt'
Set-Content -LiteralPath $outFile -Value $baseUrl -Encoding utf8

Write-Host ''
Write-Host 'Cursor: Settings > Models > Add Model > dolphin-llama3' -ForegroundColor Green
Write-Host 'Override OpenAI Base URL (paste):' -ForegroundColor Green
Write-Host $baseUrl -ForegroundColor White
Write-Host ''
Write-Host "Saved to: $outFile" -ForegroundColor DarkGray

if (-not $SkipClipboard) {
    try {
        Set-Clipboard -Value $baseUrl
        Write-Host 'Copied base URL to clipboard.' -ForegroundColor DarkGray
    } catch {
        Write-Host '(Could not copy to clipboard.)' -ForegroundColor DarkYellow
    }
}
