**System-Level Integration: Local LLMs for Agents & Coding Agents**  
**No Python Scripting Required in Daily Use**  
**AMD Ryzen AI • Intel Panther Lake XPS (Omarchy Arch Linux) • NVIDIA eGPU**  
**Version 2.2** (April 2026)

Your previous Python-based workflows (`hybrid_ai` env + `hardware_router.py` + quantization) are the **foundation**.  
Now we move everything **system-level**: the LLM runs as a background daemon (systemd service), exposes an **OpenAI-compatible API** at `http://localhost:8000/v1`, and **any** agent/tool on your machine can use it automatically — no imports, no scripts, just environment variables or config files.

This gives you:
- **Always-on local inference** (NPU for background agents, GPU for heavy coding tasks)
- **Zero-latency coding agents** (edit files, debug, generate PRs from terminal/IDE)
- **Private, offline, power-efficient** operation
- **Full hybrid acceleration** (NPU prefill + GPU decode via the same router logic)

### 1. Core Idea: One Persistent Local LLM Server

Run **one** server that:
- Auto-detects your hardware (NPU / ROCm / Xe3 / CUDA)
- Loads the **best quantized model** for the job (from our earlier `quantize_llm.py`)
- Routes intelligently (NPU-first for agents, GPU for coding)
- Serves OpenAI API (so **every** tool works)

**Best 2026 Servers (ranked for your setup)**

| Server          | Performance | NPU Support | Ease on Arch/AMD | Best For                  | Recommendation |
|-----------------|-------------|-------------|------------------|---------------------------|----------------|
| **llama.cpp server** | Excellent  | Native (AMD XDNA + Intel + CUDA + ROCm) | ★★★★★ (lightweight) | Coding agents, always-on | **Primary choice** |
| **vLLM**        | Highest    | Via ONNX/OpenVINO + ROCm/CUDA | ★★★★            | Heavy coding / large models | Use when plugged in |
| **Ollama**      | Good       | Good (via backends) | ★★★★★ (AUR)     | Quick start & GUI        | Backup / testing |

**We’ll use llama.cpp server** as default — it’s the most system-native and works perfectly with our hybrid router.

### 2. One-Time System Setup (Arch Omarchy + AMD)

```bash
# 1. Install server (works on both machines)
# Arch (Omarchy):
yay -S llama-cpp-server  # or build from AUR with CUDA/ROCm/OpenVINO flags

# AMD Ryzen AI (or Ubuntu base):
sudo apt install llama-cpp-server  # or build with --with-vulkan --with-rocm --with-openvino

# 2. Create quantized models (reuse our earlier script)
conda activate hybrid_ai
python quantize_llm.py --model meta-llama/Llama-3.3-70B-Instruct   # creates .gguf or ONNX
python quantize_llm.py --model microsoft/Phi-4-mini-instruct       # for NPU agents
```

### 3. Hardware-Aware Systemd Service (the magic)

Create this file once: `~/.config/systemd/user/llm-server.service`

```ini
[Unit]
Description=Local Hybrid LLM Server (NPU/GPU aware)
After=network.target

[Service]
Type=simple
Environment=CONDA_PREFIX=/home/youruser/miniconda3/envs/hybrid_ai
ExecStart=/bin/bash -c '
  source ~/.conda/etc/profile.d/conda.sh
  conda activate hybrid_ai
  python /home/youruser/ai_tools/hardware_router.py --server-mode
'
# The router script now has a --server-mode flag that:
#   • Detects hardware
#   • Picks best quantized model + backend (llama.cpp or vLLM)
#   • Starts server on port 8000 with NPU prefill + GPU decode
Restart=always
RestartSec=5
Nice=-10   # high priority

[Install]
WantedBy=default.target
```

Enable & start:
```bash
systemctl --user enable --now llm-server.service
```

Check status:
```bash
systemctl --user status llm-server.service
curl http://localhost:8000/v1/models   # should show your models
```

**NPU preference**: The router automatically chooses NPU for lightweight agents and falls back to iGPU/ROCm/Xe3/CUDA only when needed.

### 4. Coding Agents – How They Use It (Zero-Code Daily Use)

**A. Terminal Coding Agent (Aider) – Best for you**
```bash
# Install once
pip install aider-chat   # or yay -S aider

# Use forever (no extra flags)
export OPENAI_API_BASE=http://localhost:8000/v1
export OPENAI_API_KEY=sk-local   # dummy key

aider --model local-llama-70b   # or any model name from your server
```

Aider will now:
- Read your codebase
- Edit files directly
- Run tests
- Commit changes
- All powered by your local quantized LLM on optimal hardware

**B. VS Code / Cursor / JetBrains (Continue.dev – the Cursor killer)**
1. Install **Continue** extension in VS Code.
2. Edit `~/.continue/config.json`:
```json
{
  "models": [
    {
      "title": "Local Hybrid LLM",
      "provider": "openai",
      "model": "llama-3.3-70b",
      "apiBase": "http://localhost:8000/v1",
      "apiKey": "sk-local"
    }
  ],
  "slashCommands": ["edit", "comment", "test"]
}
```
Now you have full Cursor-like experience: highlight code → `Cmd+L` → “refactor this using best practices” — runs on your NPU/GPU.

**C. Other system-level agents**
- **Tabby** (self-hosted GitHub Copilot alternative): Install via AUR → points to your localhost server.
- **Codeium local** or **Genie** → same OpenAI endpoint.
- **Custom .composer agents**: Just set `OPENAI_BASE_URL=http://localhost:8000/v1` in their config — they become fully local.

### 5. General AI Agents (Background / Resilience / Voice / etc.)

Any agent that supports OpenAI API (LangGraph, CrewAI, Auto-GPT, BabyAGI forks, etc.) works instantly:
```bash
# In any script or agent config
export OPENAI_API_BASE=http://localhost:8000/v1
export OPENAI_API_KEY=sk-local
export MODEL_NAME=phi-4-npu   # your lightweight NPU model
```

For **always-on background agents** (captioning, voice, RAG, personal knowledge base):
- They run on **NPU-only** (low power, silent) because the router detects `task_type=background`.
- Start them via systemd user services too.

### 6. How This Ties Back to Our Hybrid Stack

- **Quantization**: Models are pre-quantized (Quark for AMD NPU, NNCF for Intel, AWQ for NVIDIA) → server loads the right file automatically.
- **hardware_router.py**: Extended with `--server-mode` flag — it decides backend + model + hybrid pipeline at launch.
- **Power efficiency**: Background agents stay on NPU (3–8 W). Coding sessions auto-switch to eGPU when plugged in.
- **Monitoring**: `systemctl --user status llm-server` + `rocm-smi` / `nvidia-smi` / `intel-gpu-top`.

### 7. Quick-Start Commands (Do This Today)

```bash
# 1. Enable the service
systemctl --user enable --now llm-server.service

# 2. Test from any terminal
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "phi-4", "messages": [{"role": "user", "content": "Write a bash function to optimize my Ryzen AI NPU"}]}'

# 3. Launch coding agent
export OPENAI_API_BASE=http://localhost:8000/v1
aider --model local-phi4
```

You now have a **production-grade, system-native local LLM brain** that every agent and coding tool can use without touching Python again.

**Next Steps**
1. I generate the full `hardware_router.py --server-mode` + systemd service files for you.
2. We set up **Continue.dev + Aider** together on your Omarchy XPS.
3. We create a dedicated **NPU-only background agent service** for resilience tasks.
