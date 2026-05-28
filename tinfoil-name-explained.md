# tinfoil — The CLI Name & Quick Start Guide

**tinfoil** is the main security auditor CLI that ships with arch-machine.

## Quick Installation & Usage

tinfoil is installed automatically when you run the main installer:

```bash
./install.sh --profile ml-dev     # (or security-dev / minimal)
```

Then use it:

```bash
tinfoil                  # full system audit
tinfoil tui              # interactive TUI
tinfoil .                # current folder
```

For development:

```bash
go run bin/tinfoil.go tui
```

See the tinfoil section in README.md and docs/INSTALLATION.md.

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
