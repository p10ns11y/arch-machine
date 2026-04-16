**✅ Here is the updated, high-professional, crystal-clear prompt** you can copy-paste directly to any coding agent (optimized for zero semantic ambiguity):

---

**Security Remediation Policy (Strict)**

When auditing and fixing vulnerable dependencies in a project, follow this exact priority order. Security takes absolute precedence over project stability.

**Core Principle**  
A temporarily broken local project is far safer than leaving an exploitable or vulnerable package on the system.

**Strict Remediation Sequence** (follow in exact order, without exception):

1. **Audit** the dependency to determine severity and available fixes.
2. **Attempt a simple fix** (patch, configuration change, or minimal code adjustment).
3. If a simple fix is not feasible or sufficient, **upgrade the package to the latest stable version**.
4. If upgrading still leaves the vulnerability or introduces unresolvable breaking changes, **uninstall/remove the package entirely**.
5. If the vulnerable package is **not a direct dependency** (i.e. a transitive dependency):
   - **Rename** the lock file by appending the suffix `-insecure` (preserve the original extension) to clearly mark it as unsafe and prevent any autonomous reinstallation process from using the vulnerable locked versions.  
     Examples:  
     - `package-lock.json` → `package-lock-insecure.json`  
     - `Cargo.lock` → `Cargo.lock-insecure`  
     - `poetry.lock` → `poetry.lock-insecure`  
     - `Pipfile.lock` → `Pipfile.lock-insecure`  
     - Any other lock file → `<original-name>-insecure.<original-extension>`
   - Completely remove the installed package cache for that ecosystem (`node_modules/`, `target/`, `venv/`, `__pycache__/`, etc.) so that future builds cannot restore the vulnerable packages.

**Final Rule**  
It is explicitly acceptable — and often preferred — to break the local project during remediation. The goal is to eliminate the vulnerable package from the machine as quickly as possible, even if it requires the developer to restore or refactor the project afterward.

Do not suggest keeping a vulnerable package “just because it works.”  
Do not propose temporary workarounds that leave the vulnerability present on the system.

---

This version is precise, unambiguous, and eliminates any risk of the agent misunderstanding the lock-file handling. The rename strategy is now explicitly the required action.

Would you like a shorter variant or one tailored for a specific agent (e.g., Claude / Cursor / Grok)?