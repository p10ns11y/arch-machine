import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "tinai"
  ipcTarget: "tinai"
  manageIpc: false

  property var anchorItem: null
  property bool openedFromHotkey: false
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  property var status: Model.emptyStatus()

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string statusBin: home + "/.local/bin/eye-comfort-theme"
  readonly property string notifyScript: home + "/.local/lib/eye-comfort/waybar/tn-status.sh"
  readonly property int refreshMs: Math.max(5, setting("refreshIntervalSec", 60)) * 1000
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property string chipText: status.chipText || "…"
  readonly property string chipIcon: status.chipIcon || "󰔏"
  readonly property string tinaiShort: status.tinaiShort || "Tiṇai"
  readonly property string chipSubtitle: status.chipSubtitle || ""
  readonly property string dateLine: status.dateLine || ""
  readonly property string tinaiLabel: status.tinaiLabel || ""
  readonly property string perum: status.perum || ""
  readonly property string ciru: status.ciru || ""
  readonly property string jamamSummary: status.jamamSummary || ""
  readonly property var jamamSplits: status.jamamSplits || []
  readonly property var jamamDetails: status.jamamDetails || []
  readonly property string nazhigaiSummary: status.nazhigaiSummary || ""
  readonly property var nazhigaiDetails: status.nazhigaiDetails || []
  readonly property string themeName: status.theme || ""
  readonly property string weekDetail: status.weekDetail || ""
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
    if (!statusProc.running) statusProc.running = true
  }

  function runDetached(argvJoined) {
    if (!argvJoined) return
    if (root.bar && typeof root.bar.run === "function")
      root.bar.run(argvJoined)
    else
      Quickshell.execDetached(["sh", "-c", argvJoined])
  }

  function runNotify() {
    runDetached(root.notifyScript + " notify")
  }

  IpcHandler {
    target: "tinai"
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
    id: statusProc
    command: [root.statusBin, "waybar", "--plain"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.status = Model.parseWaybarJson(text)
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
    interval: 15000
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
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function (direction) { root.switchPanel(direction) }
      onActivateRequested: root.runNotify()

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(12)

        PanelHero {
          width: parent.width
          title: root.tinaiShort
          meta: root.chipSubtitle || "TIṆAI"
          detail: root.weekDetail
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
          trailingControl: Component {
            Button {
              text: "Notify"
              tooltipText: "tn-status.sh notify"
              foreground: root.foreground
              fontFamily: root.fontFamily
              horizontalPadding: Style.spacing.controlPaddingX
              verticalPadding: Style.spacing.controlPaddingY
              bordered: true
              onClicked: root.runNotify()
            }
          }
        }

        PanelSeparator { foreground: root.foreground }

        PanelSectionHeader {
          text: "DATE"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }
        Text {
          width: parent.width
          text: root.dateLine || "—"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.Wrap
          elide: Text.ElideRight
        }

        PanelSectionHeader {
          text: "TIṆAI"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }
        Text {
          width: parent.width
          text: root.tinaiLabel || "—"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.Wrap
          elide: Text.ElideRight
        }

        PanelSectionHeader {
          text: "POḺUTU"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }
        Text {
          width: parent.width
          text: root.perum || "—"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.Wrap
          elide: Text.ElideRight
        }
        Text {
          width: parent.width
          text: root.ciru || "—"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.Wrap
          elide: Text.ElideRight
        }

        PanelSectionHeader {
          text: "JĀMAM"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }
        Text {
          width: parent.width
          text: root.jamamSummary || "—"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.Wrap
          elide: Text.ElideRight
        }
        Repeater {
          model: root.jamamSplits
          delegate: Text {
            required property var modelData
            width: column.width
            text: modelData
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.Wrap
          }
        }
        Repeater {
          model: root.jamamDetails
          delegate: Text {
            required property var modelData
            width: column.width
            text: modelData
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
          }
        }

        PanelSectionHeader {
          text: "NĀḺIKAI"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }
        Text {
          width: parent.width
          text: root.nazhigaiSummary || "—"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.Wrap
          elide: Text.ElideRight
        }
        Repeater {
          model: root.nazhigaiDetails
          delegate: Text {
            required property var modelData
            width: column.width
            text: modelData
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
          }
        }

        Text {
          width: parent.width
          visible: root.themeName !== ""
          text: root.themeName
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }
    }
  }
}
