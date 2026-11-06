import QtQuick

Canvas {
    id: arrow
    property string dir: "right"
    property color color: "white"
    width: 64; height: 64
    onDirChanged: requestPaint()
    onColorChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        ctx.strokeStyle = color
        ctx.fillStyle = color
        ctx.lineWidth = 6
        ctx.lineCap = "round"
        ctx.lineJoin = "round"
        if (dir === "left") { ctx.translate(width, 0); ctx.scale(-1, 1) }
        if (dir === "arrive") {
            ctx.beginPath(); ctx.arc(32, 26, 14, 0, Math.PI * 2); ctx.stroke()
            ctx.beginPath(); ctx.arc(32, 26, 5, 0, Math.PI * 2); ctx.fill()
            ctx.beginPath(); ctx.moveTo(32, 40); ctx.lineTo(32, 58); ctx.stroke()
            return
        }
        if (dir === "straight") {
            ctx.beginPath(); ctx.moveTo(32, 58); ctx.lineTo(32, 20); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(20, 24); ctx.lineTo(32, 8); ctx.lineTo(44, 24); ctx.closePath(); ctx.fill()
            return
        }
        ctx.beginPath()
        ctx.moveTo(20, 58); ctx.lineTo(20, 34)
        ctx.quadraticCurveTo(20, 20, 34, 20); ctx.lineTo(42, 20)
        ctx.stroke()
        ctx.beginPath(); ctx.moveTo(40, 8); ctx.lineTo(58, 20); ctx.lineTo(40, 32); ctx.closePath(); ctx.fill()
    }
}
