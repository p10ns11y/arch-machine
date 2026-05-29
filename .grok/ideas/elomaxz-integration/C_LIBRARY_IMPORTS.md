# How C Libraries Are Imported Today (2026)

**Short Answer**:  
There is **still no central registry** like `npm`, `crates.io`, or `PyPI` for C.

---

## Current Ways to Import C Libraries

| Method                    | How It Works                                      | Pros                              | Cons                                   | Popularity |
|---------------------------|---------------------------------------------------|-----------------------------------|----------------------------------------|------------|
| **Manual Copy**           | Copy `.h` + `.c` files into your project          | Simple, full control              | Version hell, code bloat               | Very High  |
| **Git Submodules**        | `git submodule add <repo>`                        | Version pinned, easy update       | Painful workflow, merge conflicts      | High       |
| **Git Subtree**           | Better alternative to submodules                  | Cleaner git history               | Still manual                           | Medium     |
| **CMake FetchContent**    | Modern CMake feature                              | Clean, automatic download         | Requires CMake                         | Growing    |
| **pkg-config**            | `apt install libfoo-dev` + `pkg-config`           | Easy on Linux                     | Not portable, system packages only     | Very High (Linux) |
| **Conan**                 | C++ package manager                               | Closest to npm                    | Steeper learning curve                 | High (C++) |
| **vcpkg**                 | Microsoft's package manager                       | Good integration with Visual Studio | Mainly Windows-focused                 | High       |
| **Header-only libs**      | Just copy the `.h` file                           | Easiest possible                  | Only works for header-only libraries   | Very High  |

---

## Reality Check (2026)

- **No universal registry** exists for C (unlike Rust, Go, Node.js, Python).
- Most C projects still use **manual copy** or **Git submodules**.
- For professional C++ projects, **Conan** and **vcpkg** are becoming popular.
- Many popular libraries are still **header-only** (e.g., `stb`, `miniaudio`, `cJSON`).

---

## Recommendation for elomaxz

Since `elomaxz` is a small framework we built:

### Best Options (Ranked):

1. **Git Submodule** (Recommended for now)
   ```bash
   git submodule add https://github.com/yourname/elomaxz.git core/elomaxz
   ```

2. **Manual Copy** (Simplest for early stage)
   - Just copy the `include/` and `src/` folders

3. **CMake FetchContent** (Modern approach)
   ```cmake
   FetchContent_Declare(
     elomaxz
     GIT_REPOSITORY https://github.com/yourname/elomaxz.git
     GIT_TAG        v0.3
   )
   FetchContent_MakeAvailable(elomaxz)
   ```

---

## Summary

| Language     | Package Manager     | Central Registry     |
|--------------|---------------------|----------------------|
| JavaScript   | npm / yarn / pnpm   | Yes (npm)            |
| Rust         | cargo               | Yes (crates.io)      |
| Go           | go modules          | Yes (proxy.golang.org) |
| Python       | pip                 | Yes (PyPI)           |
| **C**        | **None**            | **No**               |
| C++          | Conan / vcpkg       | Partial              |

**C still lives in the "manual / git-based" world.**

---

*Last updated: May 2026*