import QtQuick

// Stylised spectrum: one peak per resonance mode, placed at its measured
// frequency on a 0–32 Hz axis, with faint ticks at the classic nominal values.
Canvas {
  id: root

  property var freqs: ({})
  property color color: "white"
  property color gridColor: "gray"
  property real maxHz: 32
  readonly property var nominal: [7.83, 14.3, 20.8, 27.3]
  readonly property var keys: ["F1", "F2", "F3", "F4"]

  onFreqsChanged: requestPaint()
  onColorChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()

  function xFor(hz) { return (hz / maxHz) * width }

  onPaint: {
    var ctx = getContext("2d")
    ctx.reset()
    var w = width, h = height
    if (w <= 0 || h <= 0) return
    var base = h - 1

    ctx.strokeStyle = gridColor
    ctx.globalAlpha = 0.35
    ctx.lineWidth = 1
    ctx.setLineDash([2, 3])
    for (var n = 0; n < nominal.length; n++) {
      var nx = Math.round(xFor(nominal[n])) + 0.5
      ctx.beginPath(); ctx.moveTo(nx, 2); ctx.lineTo(nx, base); ctx.stroke()
    }
    ctx.setLineDash([])
    ctx.globalAlpha = 0.5
    ctx.beginPath(); ctx.moveTo(0, base + 0.5); ctx.lineTo(w, base + 0.5); ctx.stroke()

    var peaks = []
    for (var i = 0; i < keys.length; i++) {
      var f = Number(freqs[keys[i]])
      if (isFinite(f) && f > 0) peaks.push({ hz: f, height: 1 - i * 0.18 })
    }
    if (peaks.length === 0) return

    function sample(hz) {
      var v = 0
      for (var p = 0; p < peaks.length; p++) {
        var d = (hz - peaks[p].hz) / 1.1
        v += peaks[p].height * Math.exp(-d * d)
      }
      return Math.min(1, v)
    }

    ctx.beginPath()
    ctx.moveTo(0, base)
    for (var x = 0; x <= w; x += 1)
      ctx.lineTo(x, base - sample(x / w * maxHz) * (h - 6))
    ctx.lineTo(w, base)
    ctx.closePath()
    var grad = ctx.createLinearGradient(0, 0, 0, h)
    grad.addColorStop(0, Qt.rgba(color.r, color.g, color.b, 0.45))
    grad.addColorStop(1, Qt.rgba(color.r, color.g, color.b, 0.02))
    ctx.globalAlpha = 1
    ctx.fillStyle = grad
    ctx.fill()

    ctx.beginPath()
    for (var x2 = 0; x2 <= w; x2 += 1) {
      var y = base - sample(x2 / w * maxHz) * (h - 6)
      if (x2 === 0) ctx.moveTo(x2, y)
      else ctx.lineTo(x2, y)
    }
    ctx.strokeStyle = color
    ctx.lineWidth = 1.6
    ctx.stroke()
  }
}
