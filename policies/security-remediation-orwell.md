# Security Remediation Policy

Security comes first.

A broken project is safer than a vulnerable package on the system.

When you find a vulnerable dependency, follow these steps in exact order:

1. Run the security audit tool and record the exact vulnerability, severity level, and available fixes.
2. If a small code or configuration change removes the vulnerability, make that change.
3. If no small change works, upgrade the package to the latest stable version.
4. If the upgrade still leaves the vulnerability or creates new problems you cannot fix quickly, remove the package completely.
5. If the vulnerable package is a transitive (indirect) dependency:
   - Rename only the project’s top-level lock file by adding `-insecure` at the end of its name.  
     Examples:  
     - `package-lock.json` → `package-lock-insecure.json`  
     - `Cargo.lock` → `Cargo.lock-insecure`  
     - `poetry.lock` → `poetry.lock-insecure`  
     - `Pipfile.lock` → `Pipfile.lock-insecure`  
     - `yarn.lock` → `yarn.lock-insecure`
   - Do not rename any lock files inside nested folders.
   - Delete the entire installed dependency folder with `rm -rf`. This removes the vulnerable package and all nested dependencies inside `node_modules/`, `target/`, `venv/`, `__pycache__/`, etc.
6. Do not reinstall the dependencies yet. Reinstall only after you have a solution — either the vulnerability is fixed, a code tweak works, or a safe replacement package is available.

It is acceptable — and often the best choice — to break the local project during this process. The goal is to remove the vulnerable package from the machine as fast as possible.

Never keep a vulnerable package just because the code still runs.

---

This policy follows the six rules from George Orwell’s 1946 essay  

[Politics and the English Language](https://www.orwellfoundation.com/the-orwell-foundation/orwell/essays-and-other-works/politics-and-the-english-language/)