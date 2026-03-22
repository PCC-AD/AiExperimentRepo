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
   - **Model name:** must match a name Ollama serves (see `ollama list`). **Cursor’s UI often rejects names with hyphens** (e.g. `my-dolphin`) with *Model name is not valid*. Use **letters, numbers, underscores only** in the name you add in Cursor (e.g. `mydolphin`). You can duplicate a model without renaming files: `ollama cp my-dolphin mydolphin`.
   - **Override OpenAI Base URL:** paste the ngrok URL with `/v1`, e.g. `https://xxxx.ngrok-free.app/v1`.
   - **OpenAI API Key:** turn **ON** and enter a placeholder (e.g. `ollama` or `sk-local`). Many setups fail if the key toggle is off while using a custom base URL.
3. Select that model in Chat and test with a short prompt.

### Tool calling (why Ask/Plan can still fail)

Cursor often sends OpenAI-style **`tools`** (function calling) to your base URL—even in **Ask**—because parts of the UI still use an agent-style request path. **Ollama** will error if the model does not support tools, for example:

`… does not support tools`

Models built from **`dolphin-llama3`** (and many other tags) may **not** be tool-capable. For Cursor + Ollama, prefer a base that supports tools (see [Ollama tool calling](https://docs.ollama.com/capabilities/tool-calling)), e.g. **`llama3.1`**:

```powershell
ollama pull llama3.1:8b
```

Add **`llama3_1_8b`** or similar in Cursor (no hyphens if Cursor rejects them), or create a custom model with `FROM llama3.1:8b` and your own `SYSTEM` block, then `ollama create mycursorlocal -f .\Modelfile`.

Use **`dolphin-llama3`** / non-tool models in **Ollama CLI or other clients** that do not attach tools; expect **Cursor** to require a tool-capable model for integrated chat.

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
| `ERR_NGROK_121` / agent too old | Run `ngrok update` or `winget upgrade Ngrok.Ngrok`; free accounts require a minimum agent version (see ngrok error text). |
| Tunnel never appears | Check the ngrok window for errors; confirm authtoken. |
| Cursor cannot reach model | Base URL must end with `/v1`; model name must match `ollama list`. |
| *Model name is not valid* (Cursor) | Try a name **without hyphens** (`mydolphin` not `my-dolphin`); run `ollama cp old-name new_name`. Turn **OpenAI API Key** **on** with a placeholder key. |
| `GET /v1` → 404 in ngrok | Normal if something requested bare `/v1` (e.g. browser). Use `/v1/models` or let Cursor call `/v1/chat/completions`. |
| *does not support tools* (Ollama) | Cursor sends **tools**; your model must support tool calling. Use e.g. **`llama3.1:8b`** (see section above), not only `dolphin-llama3`-based tags. |
| *unable to allocate CUDA_Host buffer* / GPU OOM | Add **`PARAMETER num_gpu 0`** to the Modelfile (CPU-only), same idea as `dolphin-llama3-cpu`. Re-run `ollama create mycursorlocal -f .\Modelfile.mycursor`. See `Modelfile.llama31-cursor-cpu.example`. |
| *unable to allocate CPU buffer* | Not enough **system RAM** for weights + KV cache. Add **`PARAMETER num_ctx 4096`** (or **`2048`**). If it still fails, use a **smaller base** (e.g. `llama3.2:3b`): `ollama pull llama3.2:3b`, then `FROM llama3.2:3b` — see `Modelfile.llama32-3b-cursor-cpu.example`. Close other heavy apps before loading. |
| *requires more system memory … than is available* | The chosen tag (e.g. **8B**) needs more contiguous free RAM than Windows has. Switch Modelfile to **`FROM llama3.2:3b`** (or **`llama3.2:1b`**) and `ollama pull` that tag, then `ollama create …` again. |
| *llama runner … exit status 2* | Same class of error as unstable GPU runners (see [OLLAMA_SETUP.md](../OLLAMA_SETUP.md)). **1)** Run `ollama run llama3.2:3b` (no custom model). If that fails, update Ollama or try **`llama3.2:1b`**. **2)** If base works, build a **minimal** Modelfile (short `SYSTEM`) — see `Modelfile.llama32-3b-minimal.example`. **3)** If only the huge `SYSTEM` build fails, shorten the prompt or split content. |
| Wrong Ollama port | Set `OLLAMA_HOST` or use `-Port` on the script. |

---

## License and upstream

`dolphin-llama3` is subject to the **Meta Llama 3** license and upstream terms. Use models responsibly and in compliance with applicable law and vendor policies.
