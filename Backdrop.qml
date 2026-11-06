import QtQuick

// Deep-space base layer with a mode-tinted aurora behind the scene.
Item {
    id: bd
    property var theme

    Rectangle { anchors.fill: parent; color: bd.theme.bg }

    Canvas {
        id: aurora
        anchors.fill: parent
        property color a: bd.theme.accent
        property color b: bd.theme.accent2
        onAChanged: requestPaint()
        onBChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d"); ctx.reset()
            const cx = width / 2
            let g = ctx.createRadialGradient(cx, 300, 0, cx, 300, 640)
            g.addColorStop(0, bd.theme.css(a, 0.13))
            g.addColorStop(0.5, bd.theme.css(b, 0.04))
            g.addColorStop(1, "rgba(0,0,0,0)")
            ctx.fillStyle = g
            ctx.fillRect(0, 0, width, height)
            // faint vertical data spines at the outer columns
            ctx.fillStyle = bd.theme.css(b, 0.05)
            for (const x of [40, width - 41]) ctx.fillRect(x, 90, 1, height - 180)
        }
    }
}
