// Tinai panel model — structured fields from eye-comfort-theme waybar JSON.

function emptyStatus() {
  return {
    text: "…",
    tooltip: "",
    className: "",
    dateLine: "",
    tinaiLabel: "",
    tinaiShort: "Tiṇai",
    chipSubtitle: "",
    perum: "",
    ciru: "",
    jamamSummary: "",
    nazhigaiSummary: "",
    theme: "",
    weekDetail: "",
    chipText: "…",
    chipIcon: "󰔏",
    loaded: false
  }
}

function cleanLine(s) {
  // Strip leading/trailing padding: Braille blank, fullwidth, nbsp, ordinary spaces.
  return String(s || "").replace(/[\u2800\u3000\u00a0\u2000-\u200b\ufeff \t]+$/g, "").replace(/^[\u2800\u3000\u00a0\u2000-\u200b\ufeff \t]+/, "")
}

function isDecorative(line) {
  var s = cleanLine(line)
  if (!s) return true
  // Decorative separators made only of box / tilde / equals / dots / underscores.
  return /^[─\-–—=~·•_\s]+$/.test(s)
}

function sectionKey(line) {
  var s = cleanLine(line).toLowerCase()
  // Strip trailing fullwidth padding already handled; match headers.
  if (/^ti[nṇ]ai\b/.test(s) || s === "tiṇai" || s.indexOf("tiṇai") === 0) return "tinai"
  if (/^po[lḻ]utu\b/.test(s) || s.indexOf("poḻutu") === 0 || s.indexOf("polutu") === 0) return "polutu"
  if (/^j[aā]mam\b/.test(s) || s.indexOf("jāmam") === 0 || s.indexOf("jamam") === 0) return "jamam"
  if (/^n[aā][ḻl]ikai\b/.test(s) || s.indexOf("nāḻikai") === 0 || s.indexOf("nalikai") === 0) return "nazhigai"
  return ""
}

function stripSectionPrefix(line, prefixes) {
  var s = cleanLine(line)
  for (var i = 0; i < prefixes.length; i++) {
    var p = prefixes[i]
    if (s.indexOf(p) === 0) {
      s = cleanLine(s.slice(p.length))
      break
    }
  }
  return s
}

function parseWeekDetail(dateLine) {
  var m = String(dateLine || "").match(/\bweek\s+(\d+)\b/i)
  if (m) return "W" + m[1]
  return ""
}

function parseChipParts(text) {
  var parts = String(text || "").split(/\s*·\s*/)
  var shortName = cleanLine(parts[0] || "") || "Tiṇai"
  var subtitle = ""
  if (parts.length > 1)
    subtitle = parts.slice(1).map(cleanLine).filter(function (p) { return !!p }).join(" · ")
  return { shortName: shortName, subtitle: subtitle }
}

function parseTooltip(tooltip, chipText) {
  var out = {
    dateLine: "",
    tinaiLabel: "",
    perum: "",
    ciru: "",
    jamamSummary: "",
    nazhigaiSummary: "",
    theme: ""
  }
  var lines = String(tooltip || "").split("\n")
  var section = ""
  var gotDate = false

  for (var i = 0; i < lines.length; i++) {
    var raw = lines[i]
    var line = cleanLine(raw)
    if (isDecorative(raw)) continue

    // Theme line (footer)
    if (/^theme\b/i.test(line) || /^eye-comfort/i.test(line)) {
      out.theme = line.replace(/^theme\s+/i, "").trim() || line
      continue
    }

    var sk = sectionKey(line)
    if (sk) {
      section = sk
      continue
    }

    if (!gotDate && /\bweek\b/i.test(line) && /\d{4}/.test(line)) {
      out.dateLine = line.replace(/\s+·\s+/g, " · ").replace(/\s{2,}/g, " ")
      gotDate = true
      continue
    }
    if (!gotDate && /^\d{1,2}\s+\w+/.test(line)) {
      out.dateLine = line.replace(/\s+·\s+/g, " · ").replace(/\s{2,}/g, " ")
      gotDate = true
      continue
    }

    if (section === "tinai" && !out.tinaiLabel) {
      out.tinaiLabel = line
      continue
    }

    if (section === "polutu") {
      var low = line.toLowerCase()
      if (/^perum\b/.test(low) || (!out.perum && !/^ci[rṟ]u\b/.test(low))) {
        if (/^perum\b/i.test(line))
          out.perum = stripSectionPrefix(line, ["Perum", "perum"])
        else if (!out.perum)
          out.perum = line
        continue
      }
      if (/^ci[rṟ]u\b/i.test(line) || !out.ciru) {
        if (/^ci[rṟ]u\b/i.test(line))
          out.ciru = stripSectionPrefix(line, ["Ciṟu", "Ciru", "ciṟu", "ciru"])
        else if (!out.ciru)
          out.ciru = line
        continue
      }
    }

    if (section === "jamam" && !out.jamamSummary) {
      // Prefer "Watching N of M." style; else first content line.
      if (/^watching\b/i.test(line) || true) {
        out.jamamSummary = line
        continue
      }
    }

    if (section === "nazhigai" && !out.nazhigaiSummary) {
      out.nazhigaiSummary = line
      continue
    }
  }

  // Fallback tinai from chip text first segment.
  if (!out.tinaiLabel) {
    var parts = parseChipParts(chipText)
    if (parts.shortName && parts.shortName !== "Tiṇai")
      out.tinaiLabel = parts.shortName
  }

  return out
}

function parseWaybarJson(raw) {
  var next = emptyStatus()
  var text = String(raw || "").trim()
  if (!text) return next
  try {
    var d = JSON.parse(text)
  } catch (e) {
    next.text = "?"
    next.chipText = "?"
    next.tooltip = "invalid JSON"
    next.loaded = true
    return next
  }

  next.text = String(d.text || "").trim() || "…"
  next.tooltip = String(d.tooltip || "")
  next.className = String(d.class || d.alt || "")
  next.chipText = next.text
  next.chipIcon = "󰔏"

  var parts = parseChipParts(next.text)
  next.tinaiShort = parts.shortName
  next.chipSubtitle = parts.subtitle

  var parsed = parseTooltip(next.tooltip, next.text)
  next.dateLine = parsed.dateLine
  next.tinaiLabel = parsed.tinaiLabel
  next.perum = parsed.perum
  next.ciru = parsed.ciru
  next.jamamSummary = parsed.jamamSummary
  next.nazhigaiSummary = parsed.nazhigaiSummary
  next.theme = parsed.theme
  next.weekDetail = parseWeekDetail(parsed.dateLine)
  next.loaded = true
  return next
}
