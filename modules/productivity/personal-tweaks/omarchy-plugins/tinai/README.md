# Omarchy Tiṇai (2.1) — calendar chip

**Plugin id stays `tinai`** for compat. Bar + panel are **calendar-generic**:
season · day-part · micro-step (TN: tiṇai · ciṟu · Nāḻikai; SE: årstid · dagsindelning · mikrosteg).

Panel **calendar switcher**: `tamil_nadu` · `sweden` · `america_1776` (disabled, later).
Runs `eye-comfort-theme calendar …` — no second Sweden plugin.

```bash
rsync -a --delete ./ ~/.config/omarchy/plugins/tinai/
omarchy plugin validate ~/.config/omarchy/plugins/tinai
omarchy restart shell   # never refresh
```

Requires `~/.local/bin/eye-comfort-theme`. Active calendar = last `calendar` in
`~/.config/eye-comfort/state.json`. Sweden: `eye-comfort-theme se --lat 59.3`.

Clicks: left toggle · right notify · middle refresh.
