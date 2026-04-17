## Advanced special scripts

These shell scripts are for more advanced users

When advanced use cases and tools are needed

Also if you are new to the tools,
Start as simple one time shell script
Then once you learned adapt and add to project

```table
Tool,Designed for,On a laptop / desktop,Attack surface added,Your current setup
k3s,Lightweight Kubernetes cluster,Single-node dev only,"High (API server, kubelet)",Masked + localhost-only → good compromise
Cilium,Advanced CNI + network security,Multi-node + zero-trust policies,"Medium (extra daemons, eBPF)",Skipped unless k3s runs
Tetragon,Kernel eBPF runtime security/audit,Production clusters with many pods,Medium (more eBPF programs),Skipped unless k3s runs
```