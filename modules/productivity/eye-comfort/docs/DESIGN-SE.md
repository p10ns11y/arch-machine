# DESIGN — Eye Comfort · Sweden overlay (SN-EC-SE)

Parent: [PRODUCT-SE.md](./PRODUCT-SE.md) · Calendar seam: [calendar_registry.py](../lib/calendar_registry.py)

## Årstider (Nordic year)

Desk calendar spans — not agriculture, not weather API. Seasons structure hue leans inside stable realm packages.

| Årstid | Approx. span | Default realm | Package |
|--------|--------------|---------------|---------|
| **Vinter** | 15 Nov – end Feb | Niflheim (mist winter) | `eye-comfort-se-nifl` |
| **Vår** | Mar – May | Vanaheim (forest) | `eye-comfort-se-vanaheim` |
| **Sommar** | Jun – Aug | Asgard (long-light sky hall) | `eye-comfort-se-asgard` |
| **Höst** | Sep – 14 Nov | Jotunheim (fells) | `eye-comfort-se-jotunheim` |
| **Shoulder** | 15 Feb – 14 Mar; 15 Aug – 14 Sep | Midgard (meadow baseline) | `eye-comfort-se-midgard` |

Realm is myth **label + hue lean** only — no horned helmets, no metal chrome.

## Dagsindelning → seven circadian phases

Solar `--lat` is first-class. **Default 59.3** (Stockholm). No silent TZ→calendar geo-guess — pass `--lat` explicitly when not at the desk default.

| Phase | Swedish label | Solar hint (one line) |
|-------|---------------|------------------------|
| dawn | Gryning | outdoor |
| morning | Förmiddag | work |
| midday | Middag | outdoor |
| afternoon | Eftermiddag | work |
| dusk | Skymning | rest |
| evening | Kväll | rest |
| night | Natt | rest |

Resolution uses `schedule.phase_for_solar` (same NOAA-style approximation as base circadian). **Mikrosteg** 0–5 subdivides the active phase window for bar chip micro-step (`M1`…`M6`).

## Latitude honesty

At **59.3°N** (Stockholm):

- **Midsummer (≈21 Jun):** solar night is very short; `phase_for_solar` may rarely reach deep `night` between ~22:00–03:00. The `nifl` / dark packages can be skipped for whole evenings — this is expected, not a bug.
- **Winter (≈21 Dec):** daylight is ~6 h; `midday` / `outdoor` phases are brief. Deep `night` dominates — warm umber restraint matters more than “snow glare” white.
- **Not polar-perfect:** valleys, DST, and horizon clutter are out of scope for v1. Use `--lat` for your desk; do not infer from system timezone.

Document operator expectation: **season + solar light only** — Omarchy weather chip stays separate.

## CLI

```bash
eye-comfort-theme se --lat 59.3 --json    # calendar: sweden in state.json
eye-comfort-theme calendar sweden --lat 59.3
eye-comfort-theme calendar tamil_nadu     # switch back to TN
```

Active calendar defaults to the last `calendar` field in `~/.config/eye-comfort/state.json`.

## Accessibility

Every realm × phase × mikrosteg combo must pass **≥ 4.5:1** fg/bg in `test_sweden_schedule.py` (same bar as TN).
