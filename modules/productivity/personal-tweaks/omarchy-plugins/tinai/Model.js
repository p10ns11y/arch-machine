// Calendar panel model — structured fields from eye-comfort-theme waybar JSON.
// Plugin id stays `tinai` for compat; fields are calendar-generic.

function emptyStatus() {
  return {
    text: "…",
    tooltip: "",
    className: "",
    calendar: "tamil_nadu",
    dateLine: "",
    seasonLabel: "",
    seasonShort: "Calendar",
    dayPart: "",
    microStep: "",
    solarHint: "",
    chipSubtitle: "",
    perum: "",
    ciru: "",
    jamamSummary: "",
    jamamDetails: [],
    jamamSplits: [],
    nazhigaiSummary: "",
    nazhigaiDetails: [],
    theme: "",
    weekDetail: "",
    chipText: "…",
    chipIcon: "󰔏",
    loaded: false
  }
}

function cleanLine(s) {
  return String(s || "").replace(/[\u2800\u3000\u00a0\u2000-\u200b\ufeff \t]+$/g, "").replace(/^[\u2800\u3000\u00a0\u2000-\u200b\ufeff \t]+/, "")
}

function isDecorative(line) {
  var s = cleanLine(line)
  if (!s) return true
  return /^[─\-–—=~·•_\s]+$/.test(s)
}

function sectionKey(line) {
  var s = cleanLine(line).toLowerCase()
  if (/^ti[nṇ]ai\b/.test(s) || s.indexOf("tiṇai") === 0) return "tinai"
  if (/^po[lḻ]utu\b/.test(s) || s.indexOf("poḻutu") === 0) return "polutu"
  if (/^j[aā]mam\b/.test(s) || s.indexOf("jāmam") === 0) return "jamam"
  if (/^n[aā][ḻl]ikai\b/.test(s) || s.indexOf("nāḻikai") === 0) return "nazhigai"
  if (/^årstid\b/.test(s)) return "season"
  if (/^realm\b/.test(s)) return "realm"
  if (/^dag\b/.test(s)) return "daypart"
  if (/^solar\b/.test(s)) return "solar"
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
  var shortName = cleanLine(parts[0] || "") || "Calendar"
  var subtitle = ""
  if (parts.length > 1)
    subtitle = parts.slice(1).map(cleanLine).filter(function (p) { return !!p }).join(" · ")
  return { shortName: shortName, subtitle: subtitle, parts: parts.map(cleanLine) }
}

function parseSeasonDayMicro(chipText, calendar) {
  var parts = parseChipParts(chipText).parts
  var season = parts[0] || ""
  var dayPart = parts[1] || ""
  var micro = parts[2] || ""
  if (calendar === "sweden" && micro.indexOf("M") === 0)
    micro = micro
  else if (micro.indexOf("N") === 0)
    micro = micro
  return { season: season, dayPart: dayPart, microStep: micro }
}

function jamamWindow(index) {
  var i = parseInt(index, 10)
  if (!(i >= 1 && i <= 8)) return null
  var start = (2 + (i - 1) * 3) % 24
  var end = (start + 3) % 24
  return { start: start, end: end }
}

function fmtHour(h) {
  var n = Math.floor(Number(h)) % 24
  if (n < 0) n += 24
  return (n < 10 ? "0" : "") + n + ":00"
}

function jamamSplitLabel(index) {
  var w = jamamWindow(index)
  if (!w) return ""
  return "Jāmam " + index + " — " + fmtHour(w.start) + " – " + fmtHour(w.end)
}

function parseJamamIndex(line) {
  var m = String(line || "").match(/J[aā]mam\s+(\d+)/i)
  return m ? parseInt(m[1], 10) : 0
}

function parseTooltip(tooltip, chipText, calendar) {
  var out = {
    dateLine: "",
    seasonLabel: "",
    dayPart: "",
    microStep: "",
    solarHint: "",
    perum: "",
    ciru: "",
    jamamSummary: "",
    jamamDetails: [],
    jamamSplits: [],
    nazhigaiSummary: "",
    nazhigaiDetails: [],
    theme: ""
  }
  var jamamIndexes = []
  var lines = String(tooltip || "").split("\n")
  var section = ""
  var gotDate = false

  for (var i = 0; i < lines.length; i++) {
    var raw = lines[i]
    var line = cleanLine(raw)
    if (isDecorative(raw)) continue

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

    if (calendar === "sweden") {
      if (section === "season" && !out.seasonLabel) {
        out.seasonLabel = stripSectionPrefix(line, ["Årstid", "Årstid  "])
        continue
      }
      if (section === "realm" && !out.perum) {
        out.perum = stripSectionPrefix(line, ["Realm", "Realm   "])
        continue
      }
      if (section === "daypart") {
        var dag = stripSectionPrefix(line, ["Dag", "Dag     "])
        var dm = dag.match(/^(.+?)\s*·\s*(M\d+)/)
        if (dm) {
          out.dayPart = dm[1]
          out.microStep = dm[2]
        } else {
          out.dayPart = dag
        }
        continue
      }
      if (section === "solar" && !out.solarHint) {
        out.solarHint = stripSectionPrefix(line, ["Solar", "Solar —", "Solar    "])
        continue
      }
    }

    if (section === "tinai" && !out.seasonLabel) {
      out.seasonLabel = line
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

    if (section === "jamam") {
      if (/^watching\b/i.test(line)) {
        out.jamamSummary = line
        continue
      }
      var ji = parseJamamIndex(line)
      if (ji) {
        if (jamamIndexes.indexOf(ji) < 0) jamamIndexes.push(ji)
        out.jamamDetails.push(line)
        continue
      }
      if (line) out.jamamDetails.push(line)
      continue
    }

    if (section === "nazhigai") {
      if (!out.nazhigaiSummary) out.nazhigaiSummary = line
      else out.nazhigaiDetails.push(line)
      continue
    }
  }

  for (var j = 0; j < jamamIndexes.length; j++) {
    var lab = jamamSplitLabel(jamamIndexes[j])
    if (lab) out.jamamSplits.push(lab)
  }

  var chip = parseSeasonDayMicro(chipText, calendar)
  if (!out.seasonLabel) out.seasonLabel = chip.season
  if (!out.dayPart) out.dayPart = chip.dayPart
  if (!out.microStep) out.microStep = chip.microStep

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
  next.calendar = String(d.calendar || d.alt || "tamil_nadu")
  if (next.calendar === "tn") next.calendar = "tamil_nadu"
  if (next.calendar === "se") next.calendar = "sweden"
  next.chipText = next.text
  next.chipIcon = next.calendar === "sweden" ? "󰖟" : "󰔏"

  var parts = parseChipParts(next.text)
  next.seasonShort = parts.shortName
  next.chipSubtitle = parts.subtitle

  var parsed = parseTooltip(next.tooltip, next.text, next.calendar)
  next.dateLine = parsed.dateLine
  next.seasonLabel = parsed.seasonLabel
  next.dayPart = parsed.dayPart
  next.microStep = parsed.microStep
  next.solarHint = parsed.solarHint
  next.perum = parsed.perum
  next.ciru = parsed.ciru
  next.jamamSummary = parsed.jamamSummary
  next.jamamDetails = parsed.jamamDetails || []
  next.jamamSplits = parsed.jamamSplits || []
  next.nazhigaiSummary = parsed.nazhigaiSummary
  next.nazhigaiDetails = parsed.nazhigaiDetails || []
  next.theme = parsed.theme
  next.weekDetail = parseWeekDetail(parsed.dateLine)
  next.loaded = true
  return next
}
