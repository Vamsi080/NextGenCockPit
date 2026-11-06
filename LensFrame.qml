import QtQuick

// Two curved "lens" brackets framing the scene.
//  Left  ( : power above the zero notch, regeneration below it.
//  Right ) : battery state of charge, filling bottom -> top.
// Repaints only when a lit segment actually changes (no per-frame cost).
Canvas {
    id: frame
    property var sim
    property var theme
    property real boot: 1
    renderStrategy: Canvas.Cooperative

    readonly property int half: 18
    readonly property string signature: {
        if (!sim || !theme) return ""
        const pw = sim.power
        const p = pw >= 0 ? Math.min(1, pw / sim.maxPower) : -Math.min(1, -pw / 120)
        return Math.round(p * half * 2) + "|" + Math.round(sim.battery / 100 * half * 4) + "|"
                + theme.accent + "|" + Math.round(boot * 40) + "|" + Math.round(sim.maxPower)
    }
    onSignatureChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        if (!sim || !theme) return
        const cx = width / 2, cy = height / 2, R = 600
        const span = 38 * Math.PI / 180
        const A = theme.accent, B = theme.accent2
        const d = span / half, gapA = 0.0065
        const pw = sim.power
        const p = pw >= 0 ? Math.min(1, pw / sim.maxPower) : -Math.min(1, -pw / 120)
        const bat = sim.battery / 100
        const reveal = boot
        ctx.lineCap = "butt"

        for (const base of [Math.PI, 0]) {
            ctx.lineWidth = 1
            ctx.strokeStyle = theme.css(theme.dim, 0.45)
            ctx.beginPath(); ctx.arc(cx, cy, R + 22, base - span * reveal, base + span * reveal, false); ctx.stroke()
            ctx.strokeStyle = theme.css(A, 0.18)
            ctx.beginPath(); ctx.arc(cx, cy, R - 20, base - span * 0.92 * reveal, base + span * 0.92 * reveal, false); ctx.stroke()
            ctx.strokeStyle = theme.css(theme.sub, 0.35)
            ctx.beginPath()
            for (let i = -8; i <= 8; i++) {
                const a = base + i * span / 8 * 0.92 * reveal
                const r0 = R - 20, r1 = R - (i % 4 === 0 ? 32 : 26)
                ctx.moveTo(cx + Math.cos(a) * r0, cy + Math.sin(a) * r0)
                ctx.lineTo(cx + Math.cos(a) * r1, cy + Math.sin(a) * r1)
            }
            ctx.stroke()
        }

        function seg(a0, a1, color, alpha, lit) {
            ctx.beginPath(); ctx.arc(cx, cy, R, a0, a1, false)
            if (lit) {
                ctx.lineWidth = 19; ctx.strokeStyle = theme.css(color, 0.16); ctx.stroke()
                ctx.lineWidth = 11
            }
            ctx.strokeStyle = theme.css(color, alpha)
            ctx.stroke()
        }

        // LEFT: power / regen
        const litUp = p > 0 ? p * half : 0
        const litDn = p < 0 ? -p * half : 0
        for (let i = 0; i < half; i++) {
            if (i / half > reveal) break
            ctx.lineWidth = 11
            const a0 = Math.PI + i * d + gapA, a1 = Math.PI + (i + 1) * d - gapA
            const fu = Math.max(0, Math.min(1, litUp - i))
            seg(a0, a1, theme.dim, 0.28, false)
            if (fu > 0) seg(a0, a0 + (a1 - a0) * fu, theme.mix(A, B, i / half), 1, true)
            ctx.lineWidth = 11
            const b1 = Math.PI - i * d - gapA, b0 = Math.PI - (i + 1) * d + gapA
            const fd = Math.max(0, Math.min(1, litDn - i))
            seg(b0, b1, theme.dim, 0.18, false)
            if (fd > 0) seg(b1 - (b1 - b0) * fd, b1, theme.good, 0.95, true)
        }
        ctx.strokeStyle = theme.css(theme.text, 0.95); ctx.lineWidth = 2
        ctx.beginPath(); ctx.moveTo(cx - R - 14, cy); ctx.lineTo(cx - R + 26, cy); ctx.stroke()

        // RIGHT: battery
        const full = half * 2, d2 = (span * 2) / full
        const batCol = bat < 0.2 ? theme.warn : A
        for (let i = 0; i < full; i++) {
            if (i / full > reveal) break
            ctx.lineWidth = 11
            const a1 = span - i * d2 - gapA, a0 = span - (i + 1) * d2 + gapA
            const f = Math.max(0, Math.min(1, bat * full - i))
            seg(a0, a1, theme.dim, 0.25, false)
            if (f > 0) seg(a1 - (a1 - a0) * f, a1, theme.mix(B, batCol, i / full), 1, true)
        }

        ctx.font = "600 11px '" + theme.face + "'"
        ctx.fillStyle = theme.css(theme.sub, 0.9)
        const ex = Math.cos(span) * R, ey = Math.sin(span) * R
        ctx.textAlign = "left"
        ctx.fillText(Math.round(sim.maxPower) + " kW", cx - ex + 34, cy - ey + 70)
        ctx.fillStyle = theme.css(theme.good, 0.8)
        ctx.fillText("REGEN", cx - ex + 22, cy + ey - 22)
        ctx.textAlign = "right"
        ctx.fillStyle = theme.css(theme.sub, 0.9)
        ctx.fillText("100%", cx + ex - 34, cy - ey + 70)
        ctx.fillText("0", cx + ex - 22, cy + ey - 22)
    }
}
