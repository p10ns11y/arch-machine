# Installers

Bootstrap scripts for an Arch Linux workstation focused on:

- ML/AI development (ROCm + Python tooling)
- local security hardening with a single-node Kubernetes stack

## What This Repo Contains

### `basic_setup.sh`

Sets up an Arch machine for daily development and AMD/ROCm ML workflows.

It:

- updates system packages and installs core tooling (`base-devel`, `git`, `curl`, `wget`, `docker`, `code`, `ufw`, `tlp`, ROCm packages)
- installs/configures `mise` for Python/Node/Rust runtime management
- installs/configures `uv` for Python package and virtual environment workflows
- installs Mambaforge/Conda for optional heavy data-science workflows
- enables key services (`docker`, `ufw`, `tlp`)
- adds the current user to `docker`, `video`, and `render` groups
- creates or updates Conda environments:
  - `ai-amd` (Python 3.12 + data/ML packages + ROCm PyTorch)
  - `xAI-exp` (Python 3.14 + data/ML packages + ROCm PyTorch)

Use-case split:

- `mise` + `uv`: default path for day-to-day Python, Node, and Rust development
- Conda/Mambaforge: optional path when you need heavier scientific/ML stacks or isolated notebook-style environments

### `secure-fortress-phase0-simple.sh`

Sets up a "phase 0" local fortress baseline for runtime visibility and encrypted local storage.

It:

- updates system packages and installs core dependencies (`base-devel`, `git`, `curl`, `jq`, `helm`)
- installs/configures `mise` + `uv`
- installs/configures single-node `k3s` (with flannel/network policy disabled for Cilium)
- configures local kubeconfig for non-root `kubectl` usage
- installs/updates Cilium and restarts Cilium daemonset
- installs/updates Tetragon via Helm
- creates and mounts a `gocryptfs` encrypted vault (`~/.securevaultenc` -> `~/securevault`)
- runs a short verification block at the end

## Requirements

- Arch Linux
- internet access
- `sudo` privileges
- enough disk space for optional Conda environments and ML packages

## Quick Start

From this repository directory:

```bash
chmod +x basic_setup.sh secure-fortress-phase0-simple.sh
```

Run developer/ML setup:

```bash
./basic_setup.sh
```

Run fortress setup:

```bash
./secure-fortress-phase0-simple.sh
```

## Recommended Run Order

If this is a fresh workstation:

1. Run `basic_setup.sh`
2. Log out and back in (or reboot) so group changes apply
3. Run `secure-fortress-phase0-simple.sh`
4. Run verification commands below

## Verification

### ROCm / PyTorch

If you are using the Conda-based ML environment:

```bash
conda activate ai-amd
python -c "import torch; print(torch.cuda.is_available())"
```

Expected: `True` when ROCm-backed PyTorch is available.

### Kubernetes / Security Stack

```bash
kubectl get nodes
cilium status --wait
kubectl -n kube-system get ds tetragon
mountpoint ~/securevault
```

Expected:

- node is `Ready`
- Cilium reports healthy/OK
- Tetragon daemonset is scheduled and ready
- `mountpoint` exits successfully for `~/securevault`

## Re-run Behavior

Both scripts are designed to be rerunnable for many steps (`--needed`, conditional checks, `upgrade --install` patterns), but they still perform privileged/system-level operations. Review before each run.

## Safety Notes

- Run on systems you control and can recover (snapshots/backups recommended).
- Read each script before execution and adapt for your hardware and policy needs.
- Keep Kubernetes/security component versions reviewed over time.
