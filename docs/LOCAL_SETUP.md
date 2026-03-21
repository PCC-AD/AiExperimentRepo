# Local Ollama, Custom Models, ngrok, and Cursor

This guide records how this repository is set up to run **Dolphin (Llama 3)** locally with **Ollama**, expose it through **ngrok** for **Cursor**, and create **custom Modelfiles** with your own system prompt.

---

## Prerequisites

- **Windows** (paths and scripts assume PowerShell).
- **Ollama** installed and running (default API: `http://127.0.0.1:11434`).
- **ngrok** (optional, for Cursor over the internet). Install with:

  ```powershell
  winget install Ngrok.Ngrok
  ```

  Open a **new** terminal after install so `ngrok` is on `PATH`.

---

## Models in This Repo

| Name | Purpose |
|------|---------|
| `dolphin-llama3` | Upstream / base tag (pull with `ollama pull dolphin-llama3`). |
| `dolphin-llama3-cpu` | Local variant from `Modelfile.dolphin-llama3-cpu`: `FROM dolphin-llama3` + `PARAMETER num_gpu 0` for machines where GPU runner fails. |

See also [OLLAMA_SETUP.md](../OLLAMA_SETUP.md) for CPU variant rationale and a quick API test.

---

## Custom system prompt (Modelfile)

You do **not** paste the full output of `ollama show dolphin-llama3 --modelfile` into a new file. Use a **short** Modelfile: `FROM` the base model and your own `SYSTEM` block.

### Commands (step by step)

1. Go to the repo:

   ```powershell
   cd C:\Users\Noname\Desktop\AiExpRepo\AiExperimentRepo
   ```

2. Copy the example and edit (or create your own file):

   ```powershell
   copy Modelfile.my-dolphin.example Modelfile.my-dolphin
   notepad Modelfile.my-dolphin
   ```

   Edit the text inside the triple quotes under `SYSTEM`.

3. Create a new local model (pick any unused name, e.g. `my-dolphin`):

   ```powershell
   ollama create my-dolphin -f .\Modelfile.my-dolphin
   ```

4. Try it:

   ```powershell
   ollama run my-dolphin
   ```

   In the REPL, `/show system` should show your prompt.

5. To change the prompt later, edit the file and run the same `ollama create` again with the **same** name to overwrite the local model.

**Note:** `Modelfile.my-dolphin` is listed in `.gitignore` so personal prompts stay on your machine. Only `Modelfile.my-dolphin.example` is tracked in git.

Use `FROM dolphin-llama3-cpu` instead of `FROM dolphin-llama3` if you want the CPU-only base.

---

## Why ngrok?

Cursor’s cloud path for custom OpenAI-compatible endpoints expects a **public HTTPS** URL. Ollama listens on **localhost** only by default, so a tunnel (e.g. ngrok) bridges that gap.

---

## Scripts (automation)

All scripts live in [`scripts/`](../scripts/).

### `Start-OllamaNgrokTunnel.ps1`

- Resolves the Ollama port: `-Port`, or `OLLAMA_HOST`, or `11434`, or scans `11435`–`11450` on `127.0.0.1`.
- If ngrok is not configured, prints one-time setup instructions, **or** set `NGROK_AUTHTOKEN` once so it can run `ngrok config add-authtoken` non-interactively.
- Starts `ngrok http http://127.0.0.1:<port> --host-header localhost:<port>` (new window by default).
- Reads the local ngrok inspector API (default `http://127.0.0.1:4040/api/tunnels`), builds `https://<subdomain>.ngrok-free.app/v1`, writes `scripts/.last-cursor-ollama-base-url.txt`, copies to clipboard (unless `-SkipClipboard`).

**Run:**

```powershell
cd C:\Users\Noname\Desktop\AiExpRepo\AiExperimentRepo\scripts
.\Start-OllamaNgrokTunnel.ps1
```

**Useful parameters:** `-Port`, `-NgrokWebAddr`, `-NoNewWindow`, `-SkipClipboard`.

### `Get-NgrokCursorBaseUrl.ps1`

Use when ngrok is **already** running: prints the same `…/v1` URL, saves to `scripts/.last-cursor-ollama-base-url.txt`, copies to clipboard.

### `Start-OllamaNgrokTunnel.cmd`

Runs the PowerShell script with `-ExecutionPolicy Bypass`.

### Generated file (ignored by git)

- `scripts/.last-cursor-ollama-base-url.txt` — last resolved Cursor base URL.

---

## Cursor configuration

1. Start Ollama and run the tunnel script so you have an HTTPS base URL ending in **`/v1`**.
2. **Cursor → Settings → Models → Add model**
   - **Model name:** must match Ollama exactly (e.g. `dolphin-llama3`, `dolphin-llama3-cpu`, or `my-dolphin`).
   - **Override OpenAI Base URL:** paste the ngrok URL with `/v1`, e.g. `https://xxxx.ngrok-free.app/v1`.
   - **API key:** any placeholder (e.g. `ollama`) if the UI requires a value.
3. Select that model in Chat and test with a short prompt.

---

## ngrok authentication (one-time)

1. Get a token from [ngrok dashboard](https://dashboard.ngrok.com/get-started/your-authtoken).
2. Run:

   ```powershell
   ngrok config add-authtoken YOUR_TOKEN
   ```

   Or set `NGROK_AUTHTOKEN` and run `Start-OllamaNgrokTunnel.ps1` so it configures automatically.

---

## Troubleshooting

| Issue | What to try |
|-------|-------------|
| `ngrok` not found | New terminal after `winget install`, or refresh `PATH`. |
| Tunnel never appears | Check the ngrok window for errors; confirm authtoken. |
| Cursor cannot reach model | Base URL must end with `/v1`; model name must match `ollama list`. |
| Wrong Ollama port | Set `OLLAMA_HOST` or use `-Port` on the script. |

---

## License and upstream

`dolphin-llama3` is subject to the **Meta Llama 3** license and upstream terms. Use models responsibly and in compliance with applicable law and vendor policies.
