// Heading panel model — focus-now + mm-bar-json (compact SoT).

function slotTable() {
  return {
    "1": { id: "1", short: "SEA", semantic: "Season", icon: "󰸗" },
    "2": { id: "2", short: "CSH", semantic: "Cash", icon: "󰠔" },
    "3": { id: "3", short: "SON", semantic: "Son", icon: "󰡉" },
    "4": { id: "4", short: "DBT", semantic: "Debt", icon: "󰧑" }
  }
}

function emptyChip() {
  return { text: "", tooltip: "", className: "", loaded: false }
}

function emptyStatus() {
  return {
    focus: emptyChip(),
    mission: emptyChip(),
    slotId: "?",
    semantic: "…",
    icon: "󰋜",
    week: "—",
    applySummary: "",
    loaded: false
  }
}

function parseChipJson(raw) {
  var next = emptyChip()
  var text = String(raw || "").trim()
  if (!text) return next
  try {
    var d = JSON.parse(text)
  } catch (e) {
    next.text = "?"
    next.tooltip = "invalid JSON"
    next.loaded = true
    return next
  }
  next.text = String(d.text || "").trim()
  next.tooltip = String(d.tooltip || "")
  next.className = String(d.class || d.alt || "")
  next.loaded = true
  return next
}

function slotIdFromFocus(focus) {
  var klass = String((focus && focus.className) || "")
  var m = klass.match(/slot-([1-4])/)
  if (m) return m[1]
  var t = String((focus && focus.text) || "")
  m = t.match(/^([1-4])\b/)
  if (m) return m[1]
  return "?"
}

function slotMeta(focus) {
  var id = slotIdFromFocus(focus)
  var table = slotTable()
  if (table[id]) return table[id]
  return { id: id, short: "—", semantic: "Heading", icon: "󰋜" }
}

function tooltipLines(tip) {
  var s = String(tip || "")
  if (!s) return []
  return s.split("\n")
}

function applySummary(mission) {
  var lines = tooltipLines(mission && mission.tooltip)
  var out = []
  for (var i = 0; i < lines.length; i++) {
    var line = String(lines[i] || "").trim()
    if (!line) continue
    if (/^https?:\/\//i.test(line)) continue
    if (/^mail:/i.test(line)) continue
    if (line.indexOf("@") >= 0 && line.indexOf(" ") < 0) continue
    out.push(line)
    if (out.length >= 3) break
  }
  if (!out.length && mission && mission.text)
    return String(mission.text)
  return out.join("\n")
}

function chipText(status) {
  var icon = (status && status.icon) ? String(status.icon) : ""
  var semantic = (status && status.semantic) ? String(status.semantic) : "…"
  return (icon ? icon + " " : "") + semantic
}

function mergeStatus(focusRaw, missionRaw) {
  var focus = parseChipJson(focusRaw)
  var mission = parseChipJson(missionRaw)
  var meta = slotMeta(focus)
  return {
    focus: focus,
    mission: mission,
    slotId: meta.id,
    semantic: meta.semantic,
    icon: meta.icon,
    week: (mission && mission.text) ? mission.text : "—",
    applySummary: applySummary(mission),
    loaded: !!(focus.loaded || mission.loaded)
  }
}
