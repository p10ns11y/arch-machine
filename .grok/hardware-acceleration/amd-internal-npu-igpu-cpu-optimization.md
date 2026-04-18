**Optimal Hybrid Acceleration Strategy: NPU (XDNA), iGPU/Discrete GPU (ROCm), and CPU on AMD Ryzen AI Systems for ML/AI Tasks**  
**Version 2.0** (Improved, Extended & Cleaned – April 2026)

### Overview
This strategy delivers a **production-ready, Linux-first** hardware acceleration framework for AMD Ryzen AI systems (300/400-series SoCs). It intelligently routes workloads across the **NPU (XDNA/AMDXDNA)** for ultra-low-power inference, **iGPU + discrete GPU via ROCm 7.2+** for high-throughput training/inference, and **CPU** for orchestration, preprocessing, and fallback.

Built on your existing PyTorch/ROCm conda environments (`ai_amd`, `xai_exp`), it integrates the latest **AMD Ryzen AI Software (v1.7.x)**, **AMD Quark** quantization, **ONNX Runtime + Vitis AI Execution Provider (EP)**, and **ROCm-native** stacks. Linux NPU support has matured significantly (AMDXDNA kernel driver + FastFlowLM/Lemonade for LLMs).

**Core Philosophy**  
- **NPU-first** for anything <10B params or real-time/low-power.  
- **ROCm (iGPU/dGPU)** for heavy lifting.  
- **CPU** as orchestrator + safety net.  
- **Automatic routing** + hybrid pipelines (NPU prefill + iGPU decode for LLMs).  
- **Quantization everywhere** via AMD Quark for maximum efficiency.

**Expected Gains**  
- 5–10× lower power on lightweight tasks  
- Sub-100 ms latency for real-time apps  
- Seamless hybrid LLM serving (NPU + ROCm)  
- Full PyTorch/ONNX/TensorFlow compatibility

### Hardware Acceleration Strategy (Updated Mapping)

| Workload Type                  | Primary Target          | Fallback / Hybrid                          | Why This Choice                              | Power / Latency Benefit                  |
|--------------------------------|-------------------------|--------------------------------------------|----------------------------------------------|------------------------------------------|
| Lightweight LLMs (<10B)        | NPU (XDNA)             | NPU + iGPU (pipelined) or ROCm            | Ultra-low power, deterministic               | ~5–10 W, <100 ms TTFT                    |
| Real-time vision / audio       | NPU                    | CPU fallback                              | Always-on, silent operation                  | Minimal battery drain                    |
| Large LLMs / training (>10B)   | ROCm (iGPU or dGPU)    | CPU offload + flash attention             | High throughput, tensor parallelism          | High compute density                     |
| Diffusion / high-res vision    | ROCm                   | NPU for preview stages                    | Complex ops, flash attention support         | Maximum FPS                              |
| Pre/post-processing, scheduling| CPU                    | NPU/ROCm acceleration where possible      | General-purpose flexibility                  | Zero overhead                            |
| Background agents (captioning, voice) | NPU               | Hybrid if load spikes                     | Perfect for always-on resilience use-cases   | Silent, cool, efficient                  |

**New: Hybrid LLM Pattern (2026 best practice)**  
NPU handles **prefill** (fast first-token) → iGPU/ROCm handles **decode** (token generation). Supported natively via ONNX Runtime GenAI + FastFlowLM pipelines.

### Prerequisites (Linux-Specific – Critical Update)
1. **Kernel**: Linux 7.0+ (recommended) or stable kernels with AMDXDNA backports (6.14+).  
2. **Drivers**: AMDXDNA kernel module + XRT user-space shim (`amd/xdna-driver`). Verify with `lsmod | grep amdxdna`.  
3. **ROCm 7.2+**: Full support for Ryzen AI 400-series (iGPU + discrete). Install via AMD repo.  
4. **Ryzen AI Software 1.7.x**: Now has Linux packages (Ubuntu 24.04+ confirmed; others via source/build). Clone `amd/RyzenAI-SW` + `git lfs pull`.  
5. **Hardware Check**: `npu_check` utility from RyzenAI-SW + `rocminfo` + `rocm-smi`.

### Implementation Plan (Refined & Actionable)

#### Phase 0: System Readiness (New)
- Update kernel + install AMDXDNA/XRT.  
- Install ROCm 7.2+ (`amdgpu-install --usecase=rocm,ml --no-dkms`).  
- Clone & setup RyzenAI-SW repo.  
- Benchmark baseline (CPU-only, ROCm-only, NPU-only) using a standard suite (e.g., ONNX model zoo + LLM perf scripts).

#### Phase 1: Ryzen AI Software + Environment Integration
1. Create new conda environment:  
   ```bash
   mamba create -n ryzen_ai python=3.12
   mamba activate ryzen_ai
   ```
2. Install core stack (Linux path):  
   - `pip install onnxruntime` (or build with Vitis AI EP support)  
   - `pip install onnxruntime-genai`  
   - AMD Quark (from RyzenAI-SW or `pip install amd-quark`)  
   - `optimum[exporters,ryzenai]` (Hugging Face integration)  
   - FastFlowLM + Lemonade server for native NPU LLM serving  
   - PyTorch ROCm wheels (already in your `ai_amd` env – symlink or reuse)  
3. Update `config/tools.yaml` and `ml-dev.yaml` to include `ryzen_ai` profile.  
4. Add system module for automated driver/kernel checks.

#### Phase 2: Framework Extensions (Extended)
- **PyTorch**: Keep ROCm for GPU; export → ONNX → NPU via Quark + Vitis AI EP.  
- **ONNX Runtime**: Primary NPU path (`providers=['VitisAIExecutionProvider', 'ROCMExecutionProvider', 'CPUExecutionProvider']`).  
- **LLM Frameworks**:  
  - vLLM / TGI (ROCm)  
  - Lemonade + FastFlowLM (NPU-native, 256k context)  
  - llama.cpp with NPU experimental backend  
- **TensorFlow** (ROCm build) + Hugging Face Transformers with `optimum-amd`.  
- **Quantization Pipeline**: AMD Quark (static/dynamic/weight-only + Auto-Search) – supports PyTorch ↔ ONNX.

#### Phase 3: Intelligent Workload Distribution (Major Extension)
Create a new Python module `hardware_router.py`:
```python
def route_model(model_params: int, task_type: str, latency_target_ms: int, power_mode: bool = False):
    if model_params < 10_000_000_000 and task_type in ["inference", "real-time"]:
        return "NPU" if not power_mode else "NPU_HYBRID"
    elif latency_target_ms < 200:
        return "NPU_PREFILL_ROCM_DECODE"
    else:
        return "ROCM"  # or "ROCM_CPU_OFFLOAD"
```
- Automatic detection: `torch.cuda.is_available()`, ONNX EP probing, `amdxdna` status.  
- Hybrid pipelines: Model partitioning + pipelining APIs (NPU → iGPU handoff).  
- Monitoring: `rocm-smi`, NPU power metrics via DRM, custom Prometheus exporter.

#### Phase 4: Advanced Features & Polish
1. **Multi-GPU/RCCL** scaling (already strong in ROCm 7.2).  
2. **Quantization Workflows**: Full Quark integration + Auto-Search for best INT8/BF16 strategy.  
3. **Model Compilation**: IRON compiler (XDNA) + MIGraphX (ROCm).  
4. **Programmatic API**: `@device_router` decorator + CLI (`ryzen-ai route --model phi-4`).  
5. **LLM-Specific**: Long-context hybrid (NPU + ROCm) via FastFlowLM.  
6. **Power/Thermal Management**: Automatic NPU-only mode for battery/silent operation.

#### Phase 5: Testing, Benchmarking & Monitoring (New)
- **Benchmark Suite**: Latency, throughput, power (W), accuracy delta, memory. Use scripts from RyzenAI-SW + custom LLM eval.  
- **Edge Cases**: Operator coverage gaps (fallback to CPU/ROCm), model size limits on NPU.  
- **Logging**: Structured logs + dashboard (Grafana + Prometheus).  
- **Resilience**: Auto-fallback on NPU failure; watchdog for thermal throttling.

### New Conda Environment (`ryzen_ai`) – Final Package List
- Python 3.12  
- `onnxruntime` + `onnxruntime-genai` (Vitis AI EP)  
- `amd-quark` (quantization)  
- `optimum[ryzenai]`  
- `fastflowlm` + `lemonade-sdk` (LLM NPU)  
- PyTorch ROCm 7.2 wheels  
- `onnx`, `huggingface_hub`, `transformers`  
- Monitoring: `rocm-smi`, `amd-xdna-utils`

### Benefits (Quantified Where Possible)
- **Power Efficiency**: NPU handles background agents → near-silent, 5–10 W vs 50–100 W on GPU.  
- **Performance**: Hybrid LLM pipelines → 2–5× better TTFT + sustained tokens/sec.  
- **Flexibility**: Full support for PyTorch, ONNX, TensorFlow, vLLM, llama.cpp.  
- **Future-Proof**: Leverages AMD’s Unified AI Stack + ROCm 7.2+ + XDNA2 (60+ TOPS on 400-series).  
- **Personal Win**: Perfect for always-on AI agents while keeping laptop cool and quiet.

### Integration with .composer / .kilo
- Track via task board (new cards for each phase).  
- Use sentinel system for parallel streams (driver, env, router, benchmarks).  
- Versioned plans with rollback (Git + .kilo).  
- Link to autonomous agent configs (NPU for lightweight agents).

### Next Steps (Concrete & Prioritized)
1. **Today**: Verify kernel/driver (`uname -r`, `lsmod | grep amdxdna`, `rocminfo`).  
2. **This week**: Install Ryzen AI SW 1.7.x Linux + create `ryzen_ai` env + run Quark quickstart tutorial.  
3. **Next 7 days**: Implement & test `hardware_router.py` on 3 sample models (Phi-4, vision, small LLM).  
4. **Week 2**: Benchmark suite + hybrid LLM pipeline (NPU prefill + ROCm decode).  
5. **Week 3**: Integrate into existing agents + production monitoring.  
6. **Ongoing**: Monitor AMD releases (ROCm 7.2.x, Ryzen AI 1.8) and update.

This v2.0 plan is now **actionable, Linux-optimized, and future-proof**. It turns your Ryzen AI machine into a true heterogeneous AI powerhouse while keeping power, heat, and noise under control.