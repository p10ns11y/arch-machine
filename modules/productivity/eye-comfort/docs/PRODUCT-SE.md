# Product — Eye Comfort · Sweden overlay (**planned**)

> **Status:** v1 landed (SN-EC-SE). Parent: [PRODUCT.md](./PRODUCT.md).  
> Calendar seam: SN-EC-CAL. Design: [DESIGN-SE.md](./DESIGN-SE.md).

## Register

product (same as parent)

## Users

Same Omarchy operator; optional Nordic calendar when working at high latitude or wanting saga-season structure. Long coding sessions; chrome disappears.

## Product Purpose

**Sweden overlay** structures eye-comfort SoT with:

- **Årstid** — Nordic year (Lucia → midsommar → vintermörker, …)
- **Dagsindelning** — maps to 7 circadian phases; **solar `--lat` first-class** (~59.3 Stockholm default candidate)
- **Saga / myth identity** — realm packages or landskap + myth labels (Óðinn-calm sky hall, midgard meadow, jotun fells, vanir forest, nifl mist-winter) as **hue leans and bar text**, not religious chrome

Success = AA contrast and warm restraint first; sagas as meaningful tone, not metal-album cosplay.

## Brand Personality

Calm · Warm · Precise — plus stoic long-light / long-night honesty.

## Anti-references

Parent anti-references, plus:

- Horned-helmet / blood-eagle / metal-logo UI
- Ice-blue cyber “Nordic” night (cool H≈230°)
- Pure white snow glare
- High-sat runic rainbow syntax

## Design Principles

1. **Eye comfort first** — parent AA / no pure #000/#FFF.
2. **Identity packages stable** — seasons live-render inside them.
3. **Latitude honesty** — midsummer may rarely need deep night package; document it.
4. **Myth = label + lean** — gods/realms inspire; no idol wallpapers required for v1.
5. **Wallpaper is stage** — fjäll mist, skog, skärgård calm fields.

## Planned packages (draft)

`eye-comfort-se-{asgard,midgard,jotunheim,vanaheim,nifl}` (or landskap ids at kickoff).

## CLI

```bash
eye-comfort-theme se --lat 59.3 --json
eye-comfort-theme calendar sweden --lat 59.3
# calendar: sweden in state.json (default = last value; no TZ geo-guess)
```

## Accessibility

Every identity × day-division combo ≥ 4.5:1 in tests (same bar as TN).

## Non-goals (v1)

Full liturgy UI; replacing base phases or TN; polar-perfect astronomy for every valley.
