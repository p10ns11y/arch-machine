# CMake FetchContent — Complete Guide (2026)

## What is FetchContent?

`FetchContent` is a **modern CMake feature** (introduced in CMake 3.11, improved in later versions) that allows you to **download and build external dependencies at configure time** — without manually cloning or copying files.

It is currently one of the **best ways** to include C/C++ libraries in 2026.

---

## Why Use FetchContent?

| Problem                        | Traditional Way              | FetchContent Way                     |
|--------------------------------|------------------------------|--------------------------------------|
| Adding external library        | Manual git clone / copy      | Automatic download                   |
| Version pinning                | Hard                         | Easy (`GIT_TAG`)                     |
| Keeping dependencies updated   | Painful                      | One command                          |
| Build integration              | Manual                       | Automatic                            |

---

## Basic Syntax

```cmake
include(FetchContent)

FetchContent_Declare(
    mylib
    GIT_REPOSITORY https://github.com/username/mylib.git
    GIT_TAG        v1.2.3          # or main / commit hash
)

FetchContent_MakeAvailable(mylib)
```

After this, you can use the library like any other target:

```cmake
target_link_libraries(your_target PRIVATE mylib)
```

---

## elomaxz Specific Example

Here's how to include `elomaxz` using `FetchContent`:

### 1. Create `CMakeLists.txt` in your project root

```cmake
cmake_minimum_required(VERSION 3.20)
project(arch-machine LANGUAGES C)

# === Fetch elomaxz ===
include(FetchContent)

FetchContent_Declare(
    elomaxz
    GIT_REPOSITORY https://github.com/yourusername/elomaxz.git
    GIT_TAG        v0.3                    # Use a tag or commit
    GIT_SHALLOW    TRUE                    # Faster clone
)

FetchContent_MakeAvailable(elomaxz)

# === Your main executable ===
add_executable(arch-machine
    src/main.c
    # ... other files
)

# Link elomaxz
target_link_libraries(arch-machine PRIVATE elomaxz)

# Include headers
target_include_directories(arch-machine PRIVATE
    ${elomaxz_SOURCE_DIR}/include
)
```

### 2. Build

```bash
mkdir build && cd build
cmake ..
make
```

---

## Advanced Options

### Pin to a Specific Commit (Recommended for Stability)

```cmake
FetchContent_Declare(
    elomaxz
    GIT_REPOSITORY https://github.com/yourusername/elomaxz.git
    GIT_TAG        a1b2c3d4e5f6...          # Full commit hash
)
```

### Use a Local Copy (for development)

```cmake
FetchContent_Declare(
    elomaxz
    SOURCE_DIR ${CMAKE_SOURCE_DIR}/core/elomaxz   # Use local folder
)
```

### Add Custom CMake Options

```cmake
FetchContent_Declare(
    elomaxz
    GIT_REPOSITORY https://github.com/yourusername/elomaxz.git
    GIT_TAG        v0.3
    CMAKE_ARGS     -DELOMAXZ_BUILD_TESTS=OFF
)
```

---

## Pros & Cons of FetchContent

| Aspect                    | Pros                                      | Cons                                      |
|---------------------------|-------------------------------------------|-------------------------------------------|
| **Ease of use**           | Very easy                                 | Requires CMake                            |
| **Version control**       | Excellent (tags + commits)                | -                                         |
| **Reproducibility**       | High                                      | -                                         |
| **Build time**            | Downloads only once (cached)              | First build slower                        |
| **Integration**           | Clean and automatic                       | Slightly more complex CMakeLists.txt      |
| **Adoption (2026)**       | Very popular in modern C/C++ projects     | Older projects still use manual methods   |

---

## When Should You Use FetchContent?

**Use it if**:
- You want clean dependency management
- You're okay with using CMake
- You want reproducible builds
- You're building a serious project (like arch-machine)

**Don't use it if**:
- You want to stay with pure Makefile + Shell (current arch-machine style)
- You prefer manual control

---

## Recommendation for arch-machine

Since `arch-machine` currently uses **Makefile + Shell + Go**, here are your options:

### Option 1: Add CMake (Recommended Long-term)
- Create `CMakeLists.txt`
- Use `FetchContent` for `elomaxz`
- Keep Go + Shell for other parts

### Option 2: Stay with Current Stack + Manual Copy
- Just copy `elomaxz` files into `core/elomaxz/`
- Use Git Submodule instead

### Option 3: Hybrid
- Use CMake only for the C core
- Keep Go and Shell as-is

---

## Summary

| Method              | Best For                     | Recommendation for arch-machine |
|---------------------|------------------------------|---------------------------------|
| **FetchContent**    | Modern, clean projects       | **Best long-term choice**       |
| **Git Submodule**   | Simple git-based projects    | Good middle ground              |
| **Manual Copy**     | Quick experiments            | Fine for now                    |

---

**Would you like me to**:
1. Create a ready-to-use `CMakeLists.txt` for arch-machine + elomaxz?
2. Show how to combine CMake + existing Makefile?
3. Create a hybrid setup (CMake for C core only)?

Just tell me which one you want.