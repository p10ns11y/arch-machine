# Eye-comfort desktop theme

Module: [`modules/productivity/eye-comfort`](../modules/productivity/eye-comfort/README.md)

**Standalone-only** (not profile-wired yet) — see [MODULES.md](MODULES.md).

Vision-science Omarchy themes (`eye-comfort-{dawn,light,dusk,dark}`) with wallpapers, Ghostty palette via Omarchy, nvim soft gruvbox, Yazi flavors, and a seven-phase circadian switcher (OKLCH tokens, indoor/outdoor, intensity, solar `--lat`).

```bash
./modules/productivity/eye-comfort/install.sh --set auto
eye-comfort-theme --help
eye-comfort-theme --phase dusk --indoor --intensity soft
eye-comfort-theme auto --lat 28.6 --json
```

Phases (local, no lat): dawn 05–07 · morning 07–10 · midday 10–14 · afternoon 14–17 · dusk 17–19 · evening 19–22 · night 22–05.

Committed `colors.toml` / Ghostty / nvim hosts are generated from OKLCH SoT (`lib/generate_packages.py`); do not hand-edit those files.
