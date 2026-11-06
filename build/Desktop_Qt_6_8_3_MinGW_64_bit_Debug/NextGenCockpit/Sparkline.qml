import QtQuick

// Small line chart: values + optional threshold line. Repaints when data changes.
Canvas {
    id: sp
    property var values: []
    property real threshold: NaN
    property bool thresholdBelow: true      // alert when value goes below threshold
    property color color: "#4DA3FF"
    property color warnColor: "#FFB23F"
    property color gridColor: "#1E2A36"
    property real minY: NaN
    property real maxY: NaN
    property string unit: ""
    property bool bars: false
    renderStrategy: Canvas.Cooperative
    onValuesChanged: requestPaint()
    onColorChanged: requestPaint()
    onThresholdChanged: requestPaint()

    function css(c, a) { return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a + ")" }

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        const v = values || []
        const W = width, H = height, pad = 4
        ctx.strokeStyle = css(gridColor, 1); ctx.lineWidth = 1
        ctx.beginPath()
        for (let i = 0; i <= 2; i++) { const y = pad + (H - 2 * pad) * i / 2; ctx.moveTo(0, y); ctx.lineTo(W, y) }
        ctx.stroke()
        if (v.length < 2) return
        let lo = isNaN(minY) ? Math.min.apply(null, v) : minY
        let hi = isNaN(maxY) ? Math.max.apply(null, v) : maxY
        if (!isNaN(threshold)) { lo = Math.min(lo, threshold); hi = Math.max(hi, threshold) }
        if (hi - lo < 1e-6) { hi += 1; lo -= 1 }
        const m = (hi - lo) * 0.12; lo -= m; hi += m
        const X = i => (bars ? (i + 0.5) / v.length : i / (v.length - 1)) * W
        const Y = val => pad + (H - 2 * pad) * (1 - (val - lo) / (hi - lo))
        const last = v[v.length - 1]
        const bad = !isNaN(threshold) && (thresholdBelow ? last < threshold : last > threshold)
        const col = bad ? warnColor : color
        if (bars) {
            const bw = W / v.length * 0.6
            for (let i = 0; i < v.length; i++) {
                const over = !isNaN(threshold) && (thresholdBelow ? v[i] < threshold : v[i] > threshold)
                ctx.fillStyle = css(over ? warnColor : color, 0.85)
                ctx.fillRect(X(i) - bw / 2, Y(v[i]), bw, Y(lo) - Y(v[i]))
            }
        } else {
            const g = ctx.createLinearGradient(0, 0, 0, H)
            g.addColorStop(0, css(col, 0.28)); g.addColorStop(1, css(col, 0))
            ctx.beginPath(); ctx.moveTo(X(0), H)
            for (let i = 0; i < v.length; i++) ctx.lineTo(X(i), Y(v[i]))
            ctx.lineTo(X(v.length - 1), H); ctx.closePath()
            ctx.fillStyle = g; ctx.fill()
            ctx.beginPath(); ctx.moveTo(X(0), Y(v[0]))
            for (let i = 1; i < v.length; i++) ctx.lineTo(X(i), Y(v[i]))
            ctx.strokeStyle = css(col, 1); ctx.lineWidth = 2; ctx.stroke()
            ctx.fillStyle = css(col, 1)
            ctx.beginPath(); ctx.arc(X(v.length - 1), Y(last), 3.5, 0, Math.PI * 2); ctx.fill()
        }
        if (!isNaN(threshold)) {
            ctx.setLineDash([5, 4])
            ctx.strokeStyle = css(warnColor, 0.9); ctx.lineWidth = 1.2
            ctx.beginPath(); ctx.moveTo(0, Y(threshold)); ctx.lineTo(W, Y(threshold)); ctx.stroke()
            ctx.setLineDash([])
        }
    }
}
