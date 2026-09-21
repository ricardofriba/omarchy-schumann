import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "today.schumann.monitor"

  readonly property string apiUrl: "https://schumann.today/api/public/snapshot"
  readonly property string siteUrl: "https://schumann.today"
  // Hard ceiling on the response. curl aborts the transfer once this many
  // bytes arrive, even when the server sends no Content-Length, so a hostile
  // or broken endpoint cannot stream unbounded data into this process.
  readonly property int maxResponseBytes: 32768
  // The endpoint stamps readings as "DD.MM.YYYY HH:MM". Anything else is
  // dropped rather than shown, so no endpoint-controlled string reaches a
  // text sink.
  readonly property var timestampFormat: /^[0-3]\d\.[01]\d\.\d{4} [0-2]\d:[0-5]\d$/

  // Settings (shell.json bar entry):
  //   "modes": "F1" | "all"   — what the pill shows (default "F1")
  //   "refreshSeconds": 60    — polling interval, min 30
  //   "animate": true         — scroll the wave glyph
  readonly property bool showAll: String(setting("modes", "F1")).toLowerCase() === "all"
  readonly property int refreshSeconds: Math.max(30, parseInt(setting("refreshSeconds", 60), 10) || 60)
  readonly property bool animate: setting("animate", true) !== false

  property var freqs: ({})
  property string timestamp: ""
  property bool failed: false

  readonly property bool hasData: freqs.F1 !== undefined
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function fmt(v) {
    var n = Number(v)
    return (v === undefined || v === null || !isFinite(n)) ? "--" : n.toFixed(2)
  }

  function refresh() {
    if (!fetchProc.running) fetchProc.running = true
  }

  function update(raw) {
    var body = String(raw || "")
    // The snapshot is a few hundred bytes. Anything near the ceiling means the
    // response was cut short by --max-filesize, so it is never parsed.
    if (body.length === 0 || body.length >= maxResponseBytes) {
      failed = true
      return
    }
    try {
      var data = JSON.parse(body)
      freqs = data.frequencies || {}
      var stamp = String(data.timestamp || "")
      timestamp = timestampFormat.test(stamp) ? stamp : ""
      failed = false
    } catch (error) {
      failed = true
    }
  }

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    target.bar = root.bar
    target.settings = root.settings
    target.anchorItem = button
    target.hostWidget = root
  }

  readonly property string valueText: {
    if (!hasData) return failed ? "—" : "…"
    if (showAll) return fmt(freqs.F1) + " · " + fmt(freqs.F2) + " · " + fmt(freqs.F3) + " · " + fmt(freqs.F4)
    return fmt(freqs.F1)
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()
  Component.onCompleted: refresh()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: true
    fixedWidth: root.vertical ? -1 : content.implicitWidth + Style.spaceReal(8.5) * 2
    active: root.opened
    dimmed: root.failed
    tooltipText: root.opened ? "" : "Schumann Resonance · schumann.today\nClick: details · Right-click: open site"

    onPressed: function(mouseButton) {
      if (mouseButton === Qt.MiddleButton) root.refresh()
      else if (mouseButton === Qt.RightButton && root.bar) root.bar.run("xdg-open " + root.siteUrl)
      else if (mouseButton === Qt.LeftButton) root.toggle()
    }

    Row {
      id: content
      anchors.centerIn: parent
      spacing: Style.space(6)

      Wave {
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(16)
        height: Math.round(Style.font.body * 0.9)
        color: root.failed ? button.foreground : Color.accent
        animated: root.animate && root.hasData && !root.failed
      }

      Text {
        id: valueLabel
        anchors.verticalCenter: parent.verticalCenter
        visible: !root.vertical
        textFormat: Text.PlainText
        text: root.valueText
        color: button.foreground
        font.family: button.fontFamily
        font.pixelSize: button.fontSize
        renderType: Text.NativeRendering
      }

      Text {
        anchors.baseline: valueLabel.baseline
        visible: !root.vertical && root.hasData
        text: "Hz"
        color: button.foreground
        opacity: 0.55
        font.family: button.fontFamily
        font.pixelSize: Style.font.caption
        renderType: Text.NativeRendering
      }
    }
  }

  Process {
    id: fetchProc
    command: [
      "curl", "-fsS",
      "--max-time", "10",
      "--max-filesize", String(root.maxResponseBytes),
      "--proto", "=https",
      root.apiUrl
    ]

    stdout: StdioCollector {
      id: response
      waitForEnd: true
    }

    // Parsed only once curl exits cleanly. An overflow aborts the transfer with
    // exit code 63, so a truncated body never reaches the parser.
    onExited: function(exitCode) {
      if (exitCode === 0) root.update(response.text)
      else root.failed = true
    }
  }

  Timer {
    interval: root.refreshSeconds * 1000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }
}
