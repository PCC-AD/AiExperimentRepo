# Ollama Setup (Windows)

This repository includes a reproducible local Ollama setup for `dolphin-llama3`.

**Full guide (Cursor, ngrok, custom Modelfiles, scripts):** see [docs/LOCAL_SETUP.md](docs/LOCAL_SETUP.md).

## Installed

- Ollama CLI/runtime (`0.18.1`)
- Base model: `dolphin-llama3:latest`
- Optimized local variant: `dolphin-llama3-cpu`

## Why the CPU Variant Exists

On this machine, the default runtime can fail with:

`llama runner process has terminated: exit status 2`

To make usage reliable, `dolphin-llama3-cpu` is defined with:

- `PARAMETER num_gpu 0`

This forces CPU execution and avoids GPU-runner instability.

## Recreate the CPU Variant

```powershell
ollama create dolphin-llama3-cpu -f .\Modelfile.dolphin-llama3-cpu
```

## Quick Test

```powershell
$body = @{ model = 'dolphin-llama3-cpu'; prompt = 'Reply with exactly: OLLAMA_OK'; stream = $false } | ConvertTo-Json
Invoke-RestMethod -Uri 'http://127.0.0.1:11434/api/generate' -Method Post -ContentType 'application/json' -Body $body
```
