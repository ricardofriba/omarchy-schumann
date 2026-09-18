import QtQuick

// Small sine-wave glyph. Scrolls slowly while `animated` is true.
Canvas {
  id: root

  property color color: "white"
  property real cycles: 2
  property real lineWidth: 1.6
  property bool animated: true
  property real phase: 0

  onColorChanged: requestPaint()
  onPhaseChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()

  onPaint: {
    var ctx = getContext("2d")
    ctx.reset()
    var w = width, h = height
    if (w <= 0 || h <= 0) return
    var mid = h / 2
    var amp = (h - lineWidth * 2) / 2
    ctx.strokeStyle = root.color
    ctx.lineWidth = lineWidth
    ctx.lineCap = "round"
    ctx.lineJoin = "round"
    ctx.beginPath()
    for (var x = 0; x <= w; x += 0.5) {
      // Taper the ends so the glyph reads as a pulse rather than a cut-off line.
      var envelope = Math.sin(Math.PI * x / w)
      var y = mid - amp * envelope * Math.sin(2 * Math.PI * cycles * x / w - phase)
      if (x === 0) ctx.moveTo(x, y)
      else ctx.lineTo(x, y)
    }
    ctx.stroke()
  }

  Timer {
    interval: 66
    running: root.animated && root.visible
    repeat: true
    onTriggered: root.phase = (root.phase + 0.18) % (2 * Math.PI)
  }
}
