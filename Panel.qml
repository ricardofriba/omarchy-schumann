import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "today.schumann.monitor"
  ipcTarget: "today.schumann.monitor"
  manageIpc: true

  property var anchorItem: null
  property var hostWidget: null

  readonly property var barIdentity: hostWidget || root
  readonly property var freqs: hostWidget ? hostWidget.freqs : ({})
  readonly property string timestamp: hostWidget ? hostWidget.timestamp : ""
  readonly property bool failed: hostWidget ? hostWidget.failed : false
  readonly property bool hasData: hostWidget ? hostWidget.hasData : false
  // The timestamp is dropped when it does not match the expected format, so a
  // reading can be current while its time is unknown.
  readonly property string stampText: timestamp !== ""
    ? timestamp + " UTC"
    : (hasData ? "Time unavailable" : "Waiting for data…")
  readonly property string fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
  readonly property color fg: root.barForeground
  readonly property color dim: Qt.darker(fg, 1.5)
  readonly property color accent: Color.accent

  function fmt(v) { return hostWidget ? hostWidget.fmt(v) : "--" }

  function delta(v, nominal) {
    var n = Number(v)
    if (!isFinite(n)) return ""
    var d = n - nominal
    return (d >= 0 ? "+" : "−") + Math.abs(d).toFixed(2) + " vs " + nominal
  }

  function open() { root.controller.show() }
  function close() { root.controller.hide() }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function openSite() {
    if (root.bar) root.bar.run("xdg-open https://schumann.today")
    root.close()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if ((text === "r" || text === "R") && root.hostWidget) root.hostWidget.refresh()
        else if (text === "o" || text === "O") root.openSite()
      }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(12)

        // Header
        Item {
          width: parent.width
          height: Style.space(24)

          Wave {
            id: headerWave
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(22)
            height: Style.space(12)
            color: root.accent
            animated: root.opened
          }

          Text {
            anchors.left: headerWave.right
            anchors.leftMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            text: "Schumann Resonance"
            color: root.fg
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
          }

          Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(6)

            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(6)
              height: width
              radius: width / 2
              color: root.failed ? Color.urgent : root.accent

              SequentialAnimation on opacity {
                running: root.opened && !root.failed
                loops: Animation.Infinite
                NumberAnimation { to: 0.3; duration: 900; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
              }
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: root.failed ? "OFFLINE" : "LIVE"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }
        }

        // Fundamental
        Item {
          width: parent.width
          height: fundamental.implicitHeight

          Column {
            id: fundamental
            anchors.left: parent.left
            spacing: Style.space(2)

            Text {
              text: "F1 · FUNDAMENTAL"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Row {
              spacing: Style.space(6)

              Text {
                id: bigValue
                textFormat: Text.PlainText
                text: root.fmt(root.freqs.F1)
                color: root.accent
                font.family: root.fontFamily
                font.pixelSize: Math.round(Style.font.display * 1.5)
                font.bold: true
              }

              Text {
                anchors.baseline: bigValue.baseline
                text: "Hz"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.heading
              }
            }

            Text {
              textFormat: Text.PlainText
              text: root.delta(root.freqs.F1, 7.83)
              visible: text !== ""
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }

        // Spectrum
        Column {
          width: parent.width
          spacing: Style.space(3)

          Spectrum {
            width: parent.width
            height: Style.space(56)
            freqs: root.freqs
            color: root.accent
            gridColor: root.fg
          }

          Item {
            width: parent.width
            height: Style.font.caption + Style.space(2)

            Repeater {
              model: [0, 8, 16, 24, 32]
              delegate: Text {
                required property var modelData
                x: Math.max(0, Math.min(parent.width - implicitWidth, modelData / 32 * parent.width - implicitWidth / 2))
                text: modelData
                color: root.dim
                opacity: 0.8
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }
          }
        }

        // Harmonics
        Row {
          id: cards
          width: parent.width
          spacing: Style.space(8)

          Repeater {
            model: [
              { key: "F2", nominal: 14.3 },
              { key: "F3", nominal: 20.8 },
              { key: "F4", nominal: 27.3 }
            ]

            delegate: Rectangle {
              required property var modelData
              width: (cards.width - cards.spacing * 2) / 3
              height: cardColumn.implicitHeight + Style.space(16)
              radius: Style.space(6)
              color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.05)
              border.width: 1
              border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.10)

              Column {
                id: cardColumn
                anchors.centerIn: parent
                spacing: Style.space(2)

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: modelData.key
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  textFormat: Text.PlainText
                  text: root.fmt(root.freqs[modelData.key])
                  color: root.fg
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.heading
                  font.bold: true
                }

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: "Hz"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }
            }
          }
        }

        PanelSeparator {
          width: parent.width
          foreground: root.fg
        }

        // Footer
        Item {
          width: parent.width
          height: Style.space(22)

          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            // API-derived: never interpreted as rich text.
            textFormat: Text.PlainText
            text: root.stampText + "  ·  Tomsk"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(4)

            PanelActionButton {
              iconText: "󰑐"
              tooltipText: "Refresh (R)"
              foreground: root.fg
              hoverColor: root.accent
              fontFamily: root.fontFamily
              onClicked: if (root.hostWidget) root.hostWidget.refresh()
            }
          }
        }

        // Link to the site
        Rectangle {
          id: siteLink
          width: parent.width
          height: Style.space(34)
          radius: Style.space(6)
          color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, linkMouse.containsMouse ? 0.18 : 0.08)
          border.width: 1
          border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, linkMouse.containsMouse ? 0.7 : 0.35)

          Behavior on color { ColorAnimation { duration: 140 } }

          Row {
            anchors.centerIn: parent
            spacing: Style.space(8)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "󰖟"
              color: root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "schumann.today"
              color: root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.subtitle
              font.bold: true
              font.underline: linkMouse.containsMouse
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "↗"
              color: root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.subtitle
            }
          }

          MouseArea {
            id: linkMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openSite()
          }
        }
      }
    }
  }
}
