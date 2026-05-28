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


### Classic “tinfoil hat” paranoia joke — instantly funny and self-aware

- “Tinfoil hat” is a well-known English idiom.
- It refers to the stereotype of an extremely paranoid person who believes the government / aliens / big tech is spying on their thoughts, so they wrap their head in tinfoil to block the signals.
- By naming the CLI **tinfoil**, the project is **making fun of itself** in the best possible way.
- The tool is literally a paranoid security auditor that checks everything for rootkits, vulnerabilities, hidden processes, etc.  
  → So calling it **tinfoil** is a perfect self-aware joke: “Yes, this tool is ridiculously paranoid… and proud of it.”

It instantly makes people smile because it acknowledges the over-the-top security obsession in a humorous way instead of taking itself too seriously.

### 2. Short, memorable, easy to type (`tinfoil .` sounds ridiculous in the best way)

- The command is only **one short word**: `tinfoil`
- You type things like:
  - `tinfoil` → global system audit
  - `tinfoil .` → audit current project
  - `tinfoil /some/path` → audit any folder
- Saying or typing **`tinfoil .`** out loud sounds completely absurd and funny (“I just ran tinfoil dot on this folder”).
- It's memorable because it's silly, and silliness makes it stick in people's heads.

### Overall why it's perfect for your project

Your README already has a very humorous, self-deprecating tone (“audits itself harder than your ex audits your text messages”, “paranoid, self-healing fortress”, etc.).  
**tinfoil** fits that tone perfectly — it's not a dry security name like “sentinel” or “warden”. It's playful, self-mocking, and instantly tells users: “This tool is paranoid on purpose, and it knows it.”
