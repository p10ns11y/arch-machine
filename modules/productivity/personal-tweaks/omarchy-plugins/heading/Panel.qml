import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "heading"
  ipcTarget: "heading"
  manageIpc: false

  property var anchorItem: null
  property bool openedFromHotkey: false
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  property var status: Model.emptyStatus()
  property string pendingFocusRaw: ""
  property string pendingMissionRaw: ""

  readonly property var slots: {
    var t = Model.slotTable()
    return [t["1"], t["2"], t["3"], t["4"]]
  }

  readonly property var slotOptions: {
    var t = Model.slotTable()
    return [
      { value: "1", label: t["1"].semantic, icon: t["1"].icon },
      { value: "2", label: t["2"].semantic, icon: t["2"].icon },
      { value: "3", label: t["3"].semantic, icon: t["3"].icon },
      { value: "4", label: t["4"].semantic, icon: t["4"].icon }
    ]
  }

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string focusBin: home + "/.local/bin/focus-now"
  readonly property string missionBin: home + "/.local/bin/mm-bar-json"
  readonly property int refreshMs: Math.max(5, setting("refreshIntervalSec", 30)) * 1000
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property string chipIcon: status.icon || "󰋜"
  readonly property string semantic: status.semantic || "…"
  readonly property string slotId: String(status.slotId || "?")
  readonly property string week: status.week || "—"
  readonly property string applySummary: status.applySummary || ""
  readonly property string chipText: Model.chipText(status)
  // Weather-compat: BarWidget chips often read `.label`
  readonly property string label: chipText

  function open() {
    openedFromHotkey = false
    setCenterHoverRevealSuppressed(false)
    root.controller.show()
    root.refresh()
  }

  function openFromHotkey() {
    openedFromHotkey = true
    root.controller.show()
    root.refresh()
    Qt.callLater(function () {
      if (root.opened) setCenterHoverRevealSuppressed(true)
    })
  }

  function close() {
    setCenterHoverRevealSuppressed(false)
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.openFromHotkey()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = value
  }

  function refresh() {
    if (!focusProc.running) focusProc.running = true
    if (!missionProc.running) missionProc.running = true
  }

  function commitStatus() {
    status = Model.mergeStatus(pendingFocusRaw, pendingMissionRaw)
  }

  function runDetached(argvJoined) {
    if (!argvJoined) return
    if (root.bar && typeof root.bar.run === "function")
      root.bar.run(argvJoined)
    else
      Quickshell.execDetached(["sh", "-c", argvJoined])
  }

  function setSlot(id) {
    runDetached(root.focusBin + " set " + id)
    Qt.callLater(root.refresh)
  }

  function runMissionOpen() {
    runDetached(root.missionBin + " open")
  }

  function runMissionNotify() {
    runDetached(root.missionBin + " notify")
  }

  IpcHandler {
    target: "heading"
    function open() { root.openFromHotkey() }
    function close() { root.close() }
    function show() { root.openFromHotkey() }
    function hide() { root.close() }
    function toggle() { root.toggle() }
    function refresh() { root.refresh() }
  }

  onOpenedChanged: {
    if (opened) refresh()
  }

  Process {
    id: focusProc
    command: [root.focusBin]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.pendingFocusRaw = text
        root.commitStatus()
      }
    }
  }

  Process {
    id: missionProc
    command: [root.missionBin]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.pendingMissionRaw = text
        root.commitStatus()
      }
    }
  }

  Timer {
    interval: root.refreshMs
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    interval: 4000
    running: root.opened
    repeat: true
    onTriggered: root.refresh()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function (direction) { root.switchPanel(direction) }
      onActivateRequested: root.runMissionOpen()

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(12)

        PanelHero {
          width: parent.width
          title: root.semantic
          meta: "HEADING"
          detail: root.week
          foreground: root.foreground
          fontFamily: root.fontFamily
          iconComponent: Component {
            Text {
              textFormat: Text.PlainText
              text: root.chipIcon
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
            }
          }
        }

        PanelSeparator { foreground: root.foreground }

        PanelSectionHeader {
          text: "SLOT"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        ButtonGroup {
          options: root.slotOptions
          value: root.slotId
          foreground: root.foreground
          fontFamily: root.fontFamily
          focusable: false
          cursorIndex: -1
          onChanged: function (v) { root.setSlot(v) }
        }

        PanelSeparator { foreground: root.foreground }

        PanelSectionHeader {
          text: "APPLY"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        Text {
          width: parent.width
          text: root.applySummary || "No mission map"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.Wrap
          maximumLineCount: 3
          elide: Text.ElideRight
        }

        Row {
          spacing: Style.space(6)
          Button {
            text: "Open"
            tooltipText: "kanithanj.ai"
            foreground: root.foreground
            fontFamily: root.fontFamily
            horizontalPadding: Style.spacing.controlPaddingX
            verticalPadding: Style.spacing.controlPaddingY
            bordered: true
            onClicked: root.runMissionOpen()
          }
          Button {
            text: "Notify"
            tooltipText: "mission notify"
            foreground: root.foreground
            fontFamily: root.fontFamily
            horizontalPadding: Style.spacing.controlPaddingX
            verticalPadding: Style.spacing.controlPaddingY
            bordered: true
            onClicked: root.runMissionNotify()
          }
        }
      }
    }
  }
}
