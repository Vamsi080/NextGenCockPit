import QtQuick

// Vector telltale glyphs (ISO 2575-style). Inactive = ghosted outline,
// active = full colour. Repaints only when state changes.
Canvas {
    id: ic
    property string kind: "seatbelt"
    property color color: "#FF3355"
    property bool active: false
    property bool flashing: false
    property bool blink: true
    width: 30; height: 30
    renderStrategy: Canvas.Cooperative

    readonly property bool lit: active && (!flashing || blink)
    opacity: lit ? 1 : 0.28
    Behavior on opacity { NumberAnimation { duration: 150 } }
    onLitChanged: requestPaint()
    onColorChanged: requestPaint()
    onKindChanged: requestPaint()

    onPaint: {
        const c = getContext("2d")
        c.reset()
        const col = lit ? color : "#8A99A8"
        c.strokeStyle = col; c.fillStyle = col
        c.lineWidth = 2; c.lineCap = "round"; c.lineJoin = "round"
        const k = kind
        function circ(x, y, r, fill) { c.beginPath(); c.arc(x, y, r, 0, Math.PI * 2); fill ? c.fill() : c.stroke() }
        function line(pts) { c.beginPath(); c.moveTo(pts[0], pts[1]); for (let i = 2; i < pts.length; i += 2) c.lineTo(pts[i], pts[i + 1]); c.stroke() }
        function text(t, size, y) { c.font = "700 " + size + "px 'Segoe UI'"; c.textAlign = "center"; c.fillText(t, 15, y) }
        function lamp(x0) { c.beginPath(); c.moveTo(x0, 8); c.quadraticCurveTo(x0 + 10, 8, x0 + 10, 15); c.quadraticCurveTo(x0 + 10, 22, x0, 22); c.closePath(); c.stroke() }

        if (k === "seatbelt") {
            circ(15, 6, 3, true)
            line([10, 27, 10, 14, 15, 11, 20, 14, 20, 27])
            line([20, 12, 9, 25])
        } else if (k === "airbag") {
            circ(9, 7, 3, true)
            line([8, 12, 8, 20, 14, 26])
            circ(21, 15, 6, false)
        } else if (k === "abs") {
            circ(15, 15, 9, false)
            c.beginPath(); c.arc(15, 15, 13, 2.3, 3.98); c.stroke()
            c.beginPath(); c.arc(15, 15, 13, -0.84, 0.84); c.stroke()
            text("ABS", 7, 18)
        } else if (k === "esp") {
            line([6, 16, 9, 10, 21, 10, 24, 16, 24, 19, 6, 19, 6, 16])
            c.beginPath(); c.moveTo(8, 27); c.bezierCurveTo(10, 23, 12, 29, 14, 25); c.stroke()
            c.beginPath(); c.moveTo(17, 27); c.bezierCurveTo(19, 23, 21, 29, 23, 25); c.stroke()
        } else if (k === "tpms") {
            c.beginPath(); c.moveTo(7, 24); c.lineTo(5, 18); c.quadraticCurveTo(4, 8, 8, 6); c.lineTo(22, 6)
            c.quadraticCurveTo(26, 8, 25, 18); c.lineTo(23, 24); c.stroke()
            line([5, 26, 25, 26])
            line([15, 10, 15, 17]); circ(15, 21, 1.4, true)
        } else if (k === "parkbrake") {
            circ(15, 15, 9, false)
            c.beginPath(); c.arc(15, 15, 13, 2.3, 3.98); c.stroke()
            c.beginPath(); c.arc(15, 15, 13, -0.84, 0.84); c.stroke()
            text("P", 12, 19)
        } else if (k === "door") {
            c.strokeRect(10, 4, 10, 22)
            line([10, 19, 4, 24])
            line([20, 19, 26, 24])
        } else if (k === "lowbeam") {
            lamp(4)
            line([17, 10, 26, 13]); line([17, 15, 26, 18]); line([17, 20, 26, 23])
        } else if (k === "highbeam") {
            lamp(4)
            line([17, 10, 27, 10]); line([17, 15, 27, 15]); line([17, 20, 27, 20])
        } else if (k === "fog") {
            lamp(4)
            line([17, 10, 26, 13]); line([17, 15, 26, 18]); line([17, 20, 26, 23])
            c.beginPath(); c.moveTo(21, 4); c.bezierCurveTo(19, 10, 23, 18, 21, 26); c.stroke()
        } else if (k === "battery12") {
            c.strokeRect(4, 9, 22, 15)
            line([8, 9, 8, 6]); line([22, 9, 22, 6])
            line([8, 16, 12, 16]); line([18, 16, 22, 16]); line([20, 14, 20, 18])
        } else if (k === "temp") {
            line([15, 4, 15, 18]); circ(15, 22, 3.5, true)
            line([15, 7, 19, 7]); line([15, 11, 19, 11])
            c.beginPath(); c.moveTo(4, 27); c.bezierCurveTo(8, 24, 10, 30, 14, 27); c.stroke()
            c.beginPath(); c.moveTo(16, 27); c.bezierCurveTo(20, 24, 22, 30, 26, 27); c.stroke()
        } else if (k === "autohold") {
            circ(15, 15, 9, false)
            c.beginPath(); c.arc(15, 15, 13, 2.3, 3.98); c.stroke()
            c.beginPath(); c.arc(15, 15, 13, -0.84, 0.84); c.stroke()
            text("A", 11, 19)
        } else if (k === "lka") {
            line([6, 27, 10, 4]); line([24, 27, 20, 4])
            c.strokeRect(12, 13, 6, 9)
        } else if (k === "ice") {
            for (let i = 0; i < 3; i++) {
                const a = i * Math.PI / 3
                line([15 - Math.cos(a) * 11, 15 - Math.sin(a) * 11, 15 + Math.cos(a) * 11, 15 + Math.sin(a) * 11])
            }
            circ(15, 15, 2, true)
        } else if (k === "hazard") {
            line([15, 4, 27, 25, 3, 25, 15, 4])
            line([15, 10, 22, 22, 8, 22, 15, 10])
        } else if (k === "bsm") {
            line([9, 22, 9, 12, 12, 8, 18, 8, 21, 12, 21, 22, 9, 22])
            c.beginPath(); c.arc(9, 15, 7, 2.4, 3.9); c.stroke()
            c.beginPath(); c.arc(21, 15, 7, -0.75, 0.75); c.stroke()
        } else if (k === "fcw") {
            line([4, 22, 4, 16, 7, 12, 13, 12, 16, 16, 16, 22, 4, 22])
            line([19, 12, 22, 17, 19, 22]); line([23, 12, 26, 17, 23, 22])
        } else if (k === "drowsy") {
            c.beginPath(); c.arc(15, 15, 10, 0, Math.PI * 2); c.stroke()
            line([10, 12, 13, 13]); line([17, 13, 20, 12])
            line([11, 20, 19, 20])
            text("z", 9, 8)
        }
    }
}
