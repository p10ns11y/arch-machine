**Core Principle**  

Security comes first.  

A broken project is safer than a vulnerable package on the machine.  

Delete waste ruthlessly before optimizing, accelerating, or automating

### Updated Policy

1. **Run the audit**  
   `npm audit`  
   `cargo audit`  
   `pip-audit`  
   `yarn audit` (or `yarn npm audit` in modern Yarn)  
   Record exact vulnerability + severity.

2. **Try built-in fix first**  
   Where available, run the safe auto-fix:  
   - `npm audit fix`  
   - `cargo audit fix` (install with `--features=fix` if needed)  
   - `pip-audit --fix` (or `--fix --dry-run` first)  
   - Yarn: no native `yarn audit fix` — use `npm audit fix --package-lock-only` workaround then `yarn import` (or install `yarn-audit-fix` package).  
   Re-audit immediately after.

3. **Small code/config fix?**  
   If one line still needed → do it.

4. **Upgrade or kill (remaining critical/high only)**  
   Still vulnerable or breaks something? Delete the package completely.

5. **Transitive (indirect) deps**
   - Targeted delete: `rm -rf node_modules/*/node_modules/vulnerable-package` (or `find node_modules -name "vulnerable-package" -type d -exec rm -rf {} +`).  
   - If overkill/slow: `rm -rf node_modules` (whole thing).  
   - **No lockfile rename or touch** for indirect deps (ever).  
   - **No reinstall** until you have a clean fix.

6. **Personal solo / hobby rule**  
   Non-serious project (premflow, etc.)?  
   - Delete the feature branch (`git branch -D feature-name`).  
   - Entire repo clone? Only if you decide it’s cleaner. Get consent (Y/N)

**Never** keep a vulnerable package “because it still runs.”  

