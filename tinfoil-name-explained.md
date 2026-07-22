# tinfoil — The CLI Name & Quick Start Guide

> **Legacy entry doc (soft).** The **main interactive control plane is `archy`** — see [docs/archy.md](docs/archy.md).  
> Thin install still ships the Go **`tinfoil` shim** until SN-ARCHY-1. Gum `tinfoil tui` is frozen (SN-2).  
> Soft-obsolete inventory: [arch-design/soft-obsolete-candidates.md](arch-design/soft-obsolete-candidates.md) (SO-4).

**tinfoil** is the humorous name for the optional sentinel/guardian **CLI shim** that ships with arch-machine.

## Quick Installation & Usage

```bash
# Preferred interactive UI (from checkout until PATH ships):
make archy
TINFOIL_ROOT="$PWD" ./tools/archy/target/debug/archy

# Thin install still installs the shim:
./install.sh --thin
tinfoil                  # audit via shim
tinfoil tui              # legacy: archy if on PATH, else gum
```

Full profiles:

```bash
./install.sh --profile ml-dev     # (or security-dev / minimal)
```

See [docs/INSTALLATION.md](docs/INSTALLATION.md) and [docs/INDEX.md](docs/INDEX.md).

---

** Explanation of why “tinfoil” is way more humorous + perfect**


### Classic “tinfoil hat” vigilance joke — instantly funny and self-aware

- “Tinfoil hat” is a well-known English idiom for someone who takes protection and awareness to the extreme.
- By naming the CLI **tinfoil**, the project is **making fun of itself** in the best possible way — embracing exaggerated vigilance with humor and confidence.
- The tool is a **vigilant security guardian** that checks everything for rootkits, vulnerabilities, hidden processes, and more.  
  → So calling it **tinfoil** is a perfect self-aware joke: “Yes, this tool is ridiculously vigilant… and proud of it.”

It instantly makes people smile because it celebrates over-the-top commitment to security in a humorous, empowering way instead of taking itself too seriously.

### 2. Short, memorable, easy to type (`tinfoil .` sounds ridiculous in the best way)

- The command is only **one short word**: `tinfoil`
- You type things like:
  - `tinfoil` → global system audit
  - `tinfoil .` → audit current project
  - `tinfoil /some/path` → audit any folder
- Saying or typing **`tinfoil .`** out loud sounds completely absurd and funny (“I just ran tinfoil dot on this folder”).
- It's memorable because it's silly, and silliness makes it stick in people's heads.

### Overall why it's perfect for your project

Your README already has a very humorous, self-deprecating tone (“audits itself harder than your ex audits your text messages”, “vigilant, self-healing fortress”, etc.).  
**tinfoil** fits that tone perfectly — it's playful, self-mocking, and instantly tells users: “This tool is vigilant on purpose, and it knows it — with a grin.”
