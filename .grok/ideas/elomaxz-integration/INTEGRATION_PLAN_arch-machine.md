# Detailed Implementation Plan: Integrate elomaxz into arch-machine

**Target**: Make this plan clear enough that **any model** (Grok, Composer 2.5, Claude, etc.) can implement it cleanly and correctly.

**Project**: arch-machine (https://github.com/p10ns11y/arch-machine)
**Goal**: Replace complex shell logic with a clean, predictable, hybrid C core using elomaxz.

---

## 1. High-Level Goals

1. Make `arch-machine` more **maintainable** and **testable**
2. Use **elomaxz** as the **core state machine** for installation, maintenance, and auditing
3. Keep **Go** (`tinfoil`) as the user interface layer
4. Keep **Shell** only for actual system command execution
5. Follow **Functional Core + Imperative Shell** + **MVU** pattern

---

## 2. Recommended Architecture

```
Go (bin/tinfoil.go)
   ↓ (calls via cgo or exec)
elomaxz Core (C)
   ├── ElomaxzProgram
   ├── MachineState (Model)
   ├── Msg types
   └── Cmd system (executes shell commands)
   ↓
Shell Commands (pacman, cp, systemctl, etc.)
```

---

## 3. Phased Implementation Plan

### Phase 1: Core State Machine (Highest Priority)

**Goal**: Move the heart of installation + maintenance logic into elomaxz.

#### Step 1.1: Define Data Structures

Create `include/machine_state.h`:

```c
typedef struct {
    char profile[32];           // "minimal", "ml-dev", "security-dev"
    bool fresh_install;
    int packages_installed;
    SecurityLevel security_level;
    AuditStatus last_audit;
    // Add more fields as needed
} MachineState;

typedef enum {
    MSG_APPLY_PROFILE,
    MSG_INSTALL_PACKAGES,
    MSG_RUN_AUDIT,
    MSG_MAINTENANCE_CYCLE,
    MSG_GENERATE_EVIDENCE,
} MsgType;

typedef struct {
    MsgType type;
    char profile[32];
    // Add payload fields
} Msg;
```

#### Step 1.2: Implement Core Functions

In `src/machine_core.c`:

- `MachineState init_state(void)`
- `MachineState update_state(MachineState current, Msg msg, Cmd* cmds, size_t* n)`
- `void view_state(MachineState state)`
- `void free_state(MachineState state)`

#### Step 1.3: Create Main Program

Create `src/arch_machine.c`:

```c
ElomaxzProgram prog = {
    .init = init_machine_state,
    .update = update_machine_state,
    .view = view_machine_state,
    .msg_name = machine_msg_name,
    .free_model = free_machine_state,
    // ...
};

elomaxz_run_with_msg_source(&prog, get_next_message, NULL);
```

---

### Phase 2: Integration with Go (`tinfoil`)

**Option A (Recommended)**: Use **cgo** to call elomaxz as a library from Go.

**Option B**: Run elomaxz as a separate binary and communicate via JSON or sockets.

Start with **Option B** (simpler) → move to cgo later.

---

### Phase 3: Move Logic from Shell to C

**Priority order**:

1. Profile application logic (`install.sh`)
2. Maintenance cycle logic
3. Security audit logic
4. Evidence generation

Use `Cmd` system to execute actual shell commands safely.

---

### Phase 4: Testing & Hardening

- Unit test `update()` function with different messages
- Add `.debug = true` during development
- Create integration tests

---

## 4. File Structure (After Integration)

```
arch-machine/
├── bin/
│   └── tinfoil.go                 ← Keep (Go frontend)
├── core/                          ← NEW: elomaxz integration
│   ├── include/
│   │   ├── elomaxz.h
│   │   └── machine_state.h
│   ├── src/
│   │   ├── elomaxz.c
│   │   ├── machine_core.c
│   │   └── arch_machine.c
│   └── Makefile
├── modules/                       ← Keep (shell modules for commands)
├── maintenance/
├── legacy/                        ← Original shell scripts (backup)
└── docs/
```

---

## 5. Key Design Decisions

| Decision                    | Recommendation                          | Reason |
|----------------------------|-----------------------------------------|--------|
| State Management           | Use `ElomaxzProgram` + `MachineState`   | Predictable + testable |
| Shell Commands             | Execute via `Cmd` system                | Clean separation |
| Go Integration             | Start with separate binary + JSON       | Simpler, then move to cgo |
| Profile Logic              | Move to `update()` function             | Single source of truth |
| Error Handling             | Return structured `Msg` on failure      | Consistent with MVU |

---

## 6. Implementation Order (for any model)

1. Create `core/` directory structure
2. Copy elomaxz files into `core/`
3. Define `MachineState` and `Msg` types
4. Implement `init()`, `update()`, `view()`
5. Create `arch_machine.c` main program
6. Test with simple profile application
7. Connect from Go `tinfoil`
8. Gradually move shell logic into C

---

## 7. Success Criteria

- Core installation logic is in `update()` function
- State is predictable and debuggable (`.debug = true`)
- `tinfoil` can trigger actions via messages
- Shell is used only for actual command execution
- Code is easier to test and reason about

---

**This plan is designed to be unambiguous.** Any competent model should be able to follow it step-by-step without confusion.

---

*Created for arch-machine + elomaxz integration — May 2026*