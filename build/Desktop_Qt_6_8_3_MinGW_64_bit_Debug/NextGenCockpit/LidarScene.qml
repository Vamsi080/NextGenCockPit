import QtQuick

// ============================================================================
// Sensor-fusion scene with four views (cross-fade between them):
//   front : chase-cam LiDAR world, scan rings, laser shadows, ACC path, BSM
//   rear  : rear camera — guide lines, objects, pedestrian, rear auto-brake
//   top   : 360° bird's-eye — road + blind-spot zones (drive) / bay (reverse)
//   under : see-through underbody — ground, obstacle, wheels with TPMS+alignment
//
// Performance: rendered at 75% internal resolution and up-scaled, no
// shadowBlur, and all points are batched into one fill() per colour/alpha.
// ============================================================================
Canvas {
    id: scene
    property var sim
    property var theme
    property real boot: 1

    readonly property real res: 0.75
    width: 1920 * res
    height: 720 * res
    scale: 1 / res
    transformOrigin: Item.TopLeft
    smooth: true
    renderStrategy: Canvas.Cooperative

    // ---------------------------------------------------- view transitions
    readonly property string cur: sim ? sim.view : "front"
    property string prev: "front"
    property string _last: "front"
    property real fade: 1
    onCurChanged: { prev = _last; _last = cur; fadeAnim.restart() }
    NumberAnimation { id: fadeAnim; target: scene; property: "fade"; from: 0; to: 1; duration: 700; easing.type: Easing.InOutCubic }

    Timer { interval: 33; running: scene.visible; repeat: true; onTriggered: scene.requestPaint() }

    readonly property real tau: Math.PI * 2

    // ------------------------------------------------------------- helpers
    function hash(n) { const s = Math.sin(n * 127.1 + 311.7) * 43758.5453; return s - Math.floor(s) }
    function rgb(c) { return "rgb(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + ")" }
    function ramp(c0, c1, n) {
        const out = []
        for (let i = 0; i < n; i++) {
            const t = i / (n - 1)
            out.push(rgb(Qt.rgba(c0.r + (c1.r - c0.r) * t, c0.g + (c1.g - c0.g) * t, c0.b + (c1.b - c0.b) * t, 1)))
        }
        return out
    }
    // palette indices: 0..7 ramp(B->A) | 8 A | 9 B | 10 danger | 11 warn | 12 text | 13 good | 14 dim
    function palette() {
        const c = ramp(theme.accent2, theme.accent, 8)
        c.push(rgb(theme.accent), rgb(theme.accent2), rgb(theme.danger), rgb(theme.warn),
               rgb(theme.text), rgb(theme.good), rgb(theme.dim))
        return c
    }
    // point batching
    function pt(bt, ci, a, x, y, w, h) {
        if (a <= 0.04) return
        const k = ci * 10 + Math.min(9, Math.floor(a * 10))
        let arr = bt[k]
        if (!arr) { arr = []; bt[k] = arr }
        arr.push(x, y, w, h)
    }
    function flush(ctx, bt, cols, alpha) {
        for (const k in bt) {
            const kk = +k
            const arr = bt[k]
            ctx.globalAlpha = alpha * ((kk % 10) + 0.6) / 10
            ctx.fillStyle = cols[Math.floor(kk / 10)]
            ctx.beginPath()
            for (let i = 0; i < arr.length; i += 4) ctx.rect(arr[i], arr[i + 1], arr[i + 2], arr[i + 3])
            ctx.fill()
        }
        ctx.globalAlpha = alpha
    }
    // stroke the current path with a cheap two-pass glow
    function glow(ctx, color, a, w) {
        ctx.lineWidth = w + 6; ctx.strokeStyle = theme.css(color, a * 0.16); ctx.stroke()
        ctx.lineWidth = w;     ctx.strokeStyle = theme.css(color, a);        ctx.stroke()
    }
    function poly(ctx, pts) {
        ctx.beginPath()
        ctx.moveTo(pts[0][0], pts[0][1])
        for (let i = 1; i < pts.length; i++) ctx.lineTo(pts[i][0], pts[i][1])
        ctx.closePath()
    }
    function carPoly(hw, zf, zr, ch) {
        return [[-hw + ch, zf], [hw - ch, zf], [hw, zf - ch], [hw, zr + ch],
                [hw - ch, zr], [-hw + ch, zr], [-hw, zr + ch], [-hw, zf - ch]]
    }

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        if (!sim || !theme) return
        ctx.save()
        ctx.scale(res, res)
        if (fade < 1 && prev !== cur) drawView(ctx, prev, (1 - fade) * boot, fade)
        drawView(ctx, cur, fade * boot, 0)
        ctx.restore()
    }

    function drawView(ctx, v, alpha, out) {
        if (alpha < 0.01) return
        ctx.save()
        const z = 1 + 0.18 * out
        ctx.translate(960, 400); ctx.scale(z, z); ctx.translate(-960, -400)
        if (v === "front") drawFront(ctx, alpha)
        else if (v === "rear") drawRear(ctx, alpha)
        else if (v === "top") { if (sim.gear === "R") drawPark(ctx, alpha); else drawTopRoad(ctx, alpha) }
        else if (v === "under") drawUnder(ctx, alpha)
        ctx.restore()
    }

    function viewLabel(ctx, alpha, title, subtitle) {
        ctx.globalAlpha = alpha
        ctx.textAlign = "center"
        ctx.font = "600 12px '" + theme.face + "'"
        ctx.fillStyle = theme.css(theme.accent, 0.9)
        ctx.fillText(title, 960, 300)
        if (subtitle) {
            ctx.font = "400 12px '" + theme.face + "'"
            ctx.fillStyle = theme.css(theme.sub, 0.9)
            ctx.fillText(subtitle, 960, 318)
        }
    }

    // =====================================================================
    // FRONT — chase-cam LiDAR world
    // =====================================================================
    function drawFront(ctx, alpha) {
        const W = 1920, H = 720, cx = 960
        const hz = 262, F = 800, CZ = 14.5, CH = 5.4
        const t = sim.time, odo = sim.odometer, lat = sim.lateral
        const TAU = tau
        const beam = (t * 2.6) % TAU
        const wave = (t * 30) % 150
        const A = theme.accent, B = theme.accent2
        const fog = sim.weatherIndex === 2, rain = sim.weatherIndex === 1
        const maxZ = fog ? 70 : 175
        const cols = palette()
        const bt = {}

        function proj(x, y, z) {
            const d = z + CZ
            if (d < 1.2) return null
            return [cx + x * F / d, hz + (CH - y) * F / d, d]
        }
        function beamI(a) { let dd = beam - a; dd -= Math.floor(dd / TAU) * TAU; return Math.exp(-dd * 1.7) }
        function fadeZ(z) { return Math.max(0, 1 - z / maxZ) }

        ctx.save()
        ctx.globalAlpha = alpha

        // sky / floor glow
        let g = ctx.createLinearGradient(0, hz - 140, 0, hz + 6)
        g.addColorStop(0, "rgba(0,0,0,0)"); g.addColorStop(1, theme.css(A, 0.10))
        ctx.fillStyle = g; ctx.fillRect(0, hz - 140, W, 146)
        g = ctx.createLinearGradient(0, hz, 0, H)
        g.addColorStop(0, theme.css(A, 0.07)); g.addColorStop(0.5, theme.css(B, 0.025)); g.addColorStop(1, "rgba(0,0,0,0)")
        ctx.fillStyle = g; ctx.fillRect(0, hz, W, H - hz)
        g = ctx.createLinearGradient(0, 0, W, 0)
        g.addColorStop(0, "rgba(0,0,0,0)"); g.addColorStop(0.5, theme.css(A, 0.75)); g.addColorStop(1, "rgba(0,0,0,0)")
        ctx.fillStyle = g; ctx.fillRect(0, hz, W, 1)

        function quad(x0, x1, z0, z1) {
            const a = proj(x0, 0, z0), b = proj(x1, 0, z0), c = proj(x1, 0, z1), d = proj(x0, 0, z1)
            if (!a || !b || !c || !d) return false
            ctx.beginPath(); ctx.moveTo(a[0], a[1]); ctx.lineTo(b[0], b[1]); ctx.lineTo(c[0], c[1]); ctx.lineTo(d[0], d[1]); ctx.closePath()
            return true
        }

        // lane markings
        const laneFill = ctx.createLinearGradient(0, hz, 0, H)
        laneFill.addColorStop(0, "rgba(234,242,247,0)")
        laneFill.addColorStop(0.35, "rgba(234,242,247,0.18)")
        laneFill.addColorStop(1, "rgba(234,242,247,0.38)")
        ctx.fillStyle = laneFill
        const gs = sim.laneGapAt - odo, ge = gs + sim.laneGapLen      // markings missing between gs..ge
        for (const ex of [-5.4, 5.4]) {
            if (gs > -8 && quad(ex - lat - 0.08, ex - lat + 0.08, -8, Math.min(gs, maxZ + 10))) ctx.fill()
            if (ge < maxZ && quad(ex - lat - 0.08, ex - lat + 0.08, Math.max(-8, ge), maxZ + 10)) ctx.fill()
        }
        const k0 = Math.floor(odo / 9)
        for (const lx of [-1.8, 1.8]) {
            for (let k = k0 - 1; k < k0 + 22; k++) {
                const z0 = k * 9 - odo
                if (z0 + 3.2 < -8 || z0 > maxZ) continue
                if (z0 + 3.2 > gs && z0 < ge) continue
                if (quad(lx - lat - 0.07, lx - lat + 0.07, Math.max(-8, z0), z0 + 3.2)) ctx.fill()
            }
        }
        // construction-zone cones where markings end
        if (gs > 2 && gs < maxZ) {
            for (const cxw of [-5.2, -1.8, 1.8, 5.2]) {
                const p = proj(cxw - lat, 0, gs), q = proj(cxw - lat, 0.75, gs)
                if (!p || !q) continue
                const w = Math.max(2, 26 / p[2] * 10)
                ctx.fillStyle = theme.css(theme.warn, 0.9)
                ctx.beginPath(); ctx.moveTo(q[0], q[1]); ctx.lineTo(p[0] + w / 2, p[1]); ctx.lineTo(p[0] - w / 2, p[1]); ctx.closePath(); ctx.fill()
            }
            const tp = proj(0, 1.6, gs)
            if (tp) { ctx.font = "600 13px '" + theme.face + "'"; ctx.textAlign = "center"; ctx.fillStyle = theme.css(theme.warn, 1)
                      ctx.fillText("LANE MARKINGS END · " + Math.round(gs) + " m", tp[0], tp[1]) }
        }

        // (3) escape gap
        if (sim.escapeLane !== 0) {
            const lx = (sim.egoLane + sim.escapeLane) * 3.6 - lat
            if (quad(lx - 1.4, lx + 1.4, 1, 24)) {
                const eg = ctx.createLinearGradient(0, proj(0, 0, 24)[1], 0, proj(0, 0, 1)[1])
                eg.addColorStop(0, theme.css(theme.good, 0)); eg.addColorStop(1, theme.css(theme.good, 0.38))
                ctx.fillStyle = eg; ctx.fill()
            }
            const tp = proj(lx, 0.4, 10)
            if (tp) { ctx.font = "700 14px '" + theme.face + "'"; ctx.textAlign = "center"; ctx.fillStyle = theme.css(theme.good, 1)
                      ctx.fillText(sim.escapeLane > 0 ? "ESCAPE GAP ▶" : "◀ ESCAPE GAP", tp[0], tp[1]) }
        }

        // (13) standing water ahead
        if (sim.waterActive && sim.waterDist > -2) {
            const wz = sim.waterDist + 2.3
            if (quad(-5.4 - lat, 5.4 - lat, wz, wz + 14)) {
                const deep = sim.waterDepth > sim.profile.wading
                ctx.fillStyle = theme.css(deep ? theme.danger : theme.beam, 0.22); ctx.fill()
                ctx.lineWidth = 1.5; ctx.strokeStyle = theme.css(deep ? theme.danger : theme.beam, 0.7); ctx.stroke()
            }
            const tp = proj(0, 0.5, wz + 7)
            if (tp) { ctx.font = "600 13px '" + theme.face + "'"; ctx.textAlign = "center"; ctx.fillStyle = theme.css(theme.text, 1)
                      ctx.fillText("WATER " + sim.waterDepth + " mm · LIMIT " + sim.profile.wading + " mm", tp[0], tp[1]) }
        }

        // blind-spot zones
        for (const side of [-1, 1]) {
            const on = side < 0 ? sim.bsLeft : sim.bsRight
            if (!on) continue
            const lx = (sim.egoLane + side) * 3.6 - lat
            const pulse = (sim.indicator === side) ? 0.25 + 0.2 * Math.abs(Math.sin(t * 8)) : 0.16
            if (quad(lx - 1.6, lx + 1.6, -5, 4)) {
                ctx.fillStyle = theme.css(theme.danger, pulse); ctx.fill()
                ctx.lineWidth = 2; ctx.strokeStyle = theme.css(theme.danger, 0.7); ctx.stroke()
            }
        }

        // predicted path ribbon (adaptive cruise)
        const lead = sim.leadDistance
        if (sim.gear === "D" && sim.autoDrive) {
            const pEnd = lead > 0 ? Math.max(4, lead + 4.6 - 2.6) : 80
            const egoX = sim.egoLane * 3.6 - lat
            const pc = sim.fcw ? theme.danger : A
            const a = proj(-1.25 + egoX * 0.3, 0, 2.6), b = proj(1.25 + egoX * 0.3, 0, 2.6)
            const c = proj(1.25 + egoX, 0, pEnd), d = proj(-1.25 + egoX, 0, pEnd)
            if (a && b && c && d) {
                const pg = ctx.createLinearGradient(0, c[1], 0, a[1])
                pg.addColorStop(0, theme.css(pc, 0.0)); pg.addColorStop(1, theme.css(pc, 0.26))
                ctx.fillStyle = pg
                poly(ctx, [a, b, c, d]); ctx.fill()
            }
            ctx.lineWidth = 2
            ctx.strokeStyle = theme.css(pc, 1)
            const off = (odo * 0.9) % 6
            for (let z = 10 - off; z < pEnd; z += 6) {
                const f = z / pEnd
                const sx = egoX * Math.min(1, (z - 2.6) / Math.max(1, pEnd - 2.6))
                const l = proj(sx - 0.8, 0, z), mm = proj(sx, 0, z + 0.9), r = proj(sx + 0.8, 0, z)
                if (!l || !mm || !r) continue
                ctx.globalAlpha = alpha * 0.55 * (1 - f)
                ctx.beginPath(); ctx.moveTo(l[0], l[1]); ctx.lineTo(mm[0], mm[1]); ctx.lineTo(r[0], r[1]); ctx.stroke()
            }
            ctx.globalAlpha = alpha
        }

        // laser shadows behind vehicles
        const shadows = []
        for (const c of sim.traffic) {
            const X = c.x - lat, Z = c.z
            if (Z < 1) continue
            const a = Math.atan2(X, Z - 2.3), half = Math.atan2(1.05, Z - 2.3)
            shadows.push([a - half, a + half, Z - 2.3])
        }
        function shadowed(a, r) {
            for (const s of shadows) if (r > s[2] && a > s[0] && a < s[1]) return true
            return false
        }

        // scan rings
        const radii = [3.4, 4.4, 5.6, 7, 8.6, 10.5, 12.8, 15.5, 18.8, 22.8, 27.6, 33.4, 40.4, 48.8, 59, 71, 86, 104, 126]
        for (let ri = 0; ri < radii.length; ri++) {
            const r = radii[ri]
            if (r > maxZ) break
            const sp = (0.34 + r * 0.012) / r
            let a0, a1
            if (r <= 7.3) { a0 = -Math.PI; a1 = Math.PI } else { const am = Math.asin(7.3 / r); a0 = -am; a1 = am }
            const ci = Math.min(7, Math.floor(ri * 0.45))
            const fade = fadeZ(r)
            const wd = (r - wave) / 3.5, waveI = Math.exp(-wd * wd)
            for (let a = a0; a < a1; a += sp) {
                const rr = r + (hash(ri * 977 + Math.floor(a * 400)) - 0.5) * 0.12
                const x = rr * Math.sin(a), z = rr * Math.cos(a)
                if (Math.abs(x) < 1.15 && Math.abs(z) < 2.55) continue
                if (shadowed(a, rr)) continue
                const p = proj(x, 0, z)
                if (!p) continue
                const s = Math.max(1.6, Math.min(4.2, 56 / p[2]))
                pt(bt, ci, Math.min(1, fade * (0.30 + 0.70 * beamI(a) + 0.8 * waveI)), p[0] - s / 2, p[1] - s / 3, s, s * 0.66)
            }
        }

        // guard rails
        for (const side of [-1, 1]) {
            const rx = side * 7.6 - lat
            const ph = ((odo % 2.5) + 2.5) % 2.5
            for (let k = -3; k < 70; k++) {
                const z = k * 2.5 - ph
                if (z > maxZ) break
                const bi = beamI(Math.atan2(rx, z)), fade = fadeZ(z)
                for (const y of [0.25, 0.55, 0.85]) {
                    const p = proj(rx, y, z)
                    if (!p) continue
                    const s = Math.max(1.5, Math.min(4, 56 / p[2]))
                    pt(bt, side > 0 ? 9 : 8, fade * (0.35 + 0.65 * bi), p[0] - s / 2, p[1] - s / 2, s, s)
                }
            }
            const p0 = proj(rx, 0.86, -6), p1 = proj(rx, 0.86, maxZ)
            if (p0 && p1) {
                const lg = ctx.createLinearGradient(p0[0], p0[1], p1[0], p1[1])
                lg.addColorStop(0, theme.css(A, 0.55)); lg.addColorStop(1, theme.css(A, 0))
                ctx.strokeStyle = lg; ctx.lineWidth = 1.2
                ctx.beginPath(); ctx.moveTo(p0[0], p0[1]); ctx.lineTo(p1[0], p1[1]); ctx.stroke()
            }
        }

        // roadside structures
        const sk = Math.floor(odo / 4)
        for (const side of [-1, 1]) {
            for (let k = sk; k < sk + 44; k++) {
                const z = k * 4 - odo
                if (z < -4) continue
                if (z > maxZ) break
                const h1 = hash(k * 2 + (side > 0 ? 1 : 0))
                if (h1 < 0.32) continue
                const xw = side * (10.5 + hash(k * 3.7 + side) * 17) - lat
                const tall = 1.4 + hash(k * 5.1 + side * 2) * (h1 > 0.82 ? 15 : 5)
                const bi = beamI(Math.atan2(xw, z)), fade = fadeZ(z)
                const colsN = h1 > 0.82 ? 3 : 1
                for (let cI = 0; cI < colsN; cI++) {
                    for (let y = 0.2; y < tall; y += 0.7) {
                        const p = proj(xw + cI * 0.7 * side, y, z + cI * 0.4)
                        if (!p) continue
                        const s = Math.max(1.4, Math.min(3, 44 / p[2]))
                        pt(bt, 9, fade * (0.22 + 0.7 * bi) * (1 - y / (tall + 6)), p[0] - s / 2, p[1] - s / 2, s, s)
                    }
                }
            }
        }

        // road obstacle seen ahead (speed bump / pothole / debris / rock)
        const od = sim.obstacleDist
        const obsTags = []
        if (sim.gear !== "R" && od > 1 && od < Math.min(70, maxZ)) {
            const oz = od + 2.3, ox = sim.egoLane * 3.6 - lat
            const ob = sim.obstacle
            const risk = sim.underbodyRisk
            const ci = risk ? 10 : 11
            if (ob.type === "Speed bump") {
                for (let x = -1.7; x <= 1.7; x += 0.12)
                    for (const y of [0.02, 0.06, 0.1]) {
                        const p = proj(ox + x, y, oz); if (!p) continue
                        const s = Math.max(1.4, Math.min(3.5, 50 / p[2]))
                        pt(bt, (Math.floor((x + 2) / 0.45) % 2) ? 11 : 12, 0.85, p[0] - s / 2, p[1] - s / 2, s, s)
                    }
            } else if (ob.type === "Pothole") {
                for (let a = 0; a < TAU; a += 0.15) {
                    const p = proj(ox + 0.3 + Math.cos(a) * 0.6, 0.01, oz + Math.sin(a) * 0.4); if (!p) continue
                    pt(bt, 11, 0.8, p[0] - 1.5, p[1] - 1.5, 3, 3)
                }
            } else {
                const rad = ob.h / 1000 * 1.6
                for (let a = 0; a < TAU; a += 0.35)
                    for (let e = 0; e < 1.5; e += 0.3) {
                        const p = proj(ox - 0.4 + Math.cos(a) * rad * Math.cos(e), Math.sin(e) * ob.h / 1000,
                                       oz + Math.sin(a) * rad * Math.cos(e)); if (!p) continue
                        pt(bt, ci, 0.9, p[0] - 1.7, p[1] - 1.7, 3.4, 3.4)
                    }
            }
            const tp = proj(ox, 0.6, oz)
            if (tp) obsTags.push([tp[0], tp[1], ob.type.toUpperCase() + "  " + Math.abs(ob.h) + " mm  ·  " + Math.round(od) + " m",
                                  risk ? theme.danger : theme.warn])
        }

        // vehicles (far -> near), points into batch, brackets after flush
        const brackets = []
        const cars = sim.traffic.slice().sort((p, q) => q.z - p.z)
        for (const c of cars) {
            const X = c.x - lat, Z = c.z
            if (Z < -3 || Z > maxZ) continue
            const isLead = Math.abs(X) < 1.7 && Z > 0 && Math.abs(Z - 4.6 - lead) < 0.05
            const ci = (isLead && sim.fcw) || Z < 14 ? 10 : (Z < 32 ? 11 : 8)
            const zb = Z - 2.3
            const fade = Math.max(0.15, fadeZ(Z))
            const bi = beamI(Math.atan2(X, zb))
            for (let xx = -0.95; xx <= 0.951; xx += 0.19)
                for (let yy = 0.25; yy <= 1.46; yy += 0.17) {
                    if (yy > 1.0 && Math.abs(xx) > 0.74) continue
                    const p = proj(X + xx, yy, zb); if (!p) continue
                    const s = Math.max(1.2, Math.min(3.6, 50 / p[2]))
                    pt(bt, ci, fade * (0.45 + 0.55 * bi), p[0] - s / 2, p[1] - s / 2, s, s)
                }
            for (let zz = 0.9; zz <= 3.2; zz += 0.38)
                for (let xx = -0.7; xx <= 0.71; xx += 0.28) {
                    const p = proj(X + xx, 1.46, zb + zz); if (!p) continue
                    const s = Math.max(1, Math.min(3, 42 / p[2]))
                    pt(bt, ci, fade * 0.5 * (0.4 + 0.6 * bi), p[0] - s / 2, p[1] - s / 2, s, s)
                }
            if (Math.abs(X) > 0.6) {
                const sx = X > 0 ? X - 0.95 : X + 0.95
                for (let zz = 0.2; zz <= 4.6; zz += 0.36)
                    for (let yy = 0.3; yy <= 1.0; yy += 0.18) {
                        const p = proj(sx, yy, zb + zz); if (!p) continue
                        const s = Math.max(1, Math.min(3, 42 / p[2]))
                        pt(bt, ci, fade * 0.4, p[0] - s / 2, p[1] - s / 2, s, s)
                    }
            }
            const tl = proj(X - 1.1, 1.65, zb), br = proj(X + 1.1, 0, zb)
            if (tl && br && Z > 4) brackets.push({ tl: tl, br: br, ci: ci, Z: Z, lead: isLead, fade: fade })
        }

        flush(ctx, bt, cols, alpha)

        // detection brackets + tags
        ctx.font = "600 13px '" + theme.face + "'"
        ctx.textAlign = "center"
        for (const b of brackets) {
            const tl = b.tl, br = b.br
            const w = br[0] - tl[0], h = br[1] - tl[1], L = Math.min(w, h) * 0.28
            const col = cols[b.ci]
            ctx.globalAlpha = alpha * Math.min(1, b.fade * 1.4)
            ctx.strokeStyle = col; ctx.lineWidth = b.lead && sim.fcw ? 3 : 1.5
            ctx.beginPath()
            ctx.moveTo(tl[0], tl[1] + L); ctx.lineTo(tl[0], tl[1]); ctx.lineTo(tl[0] + L, tl[1])
            ctx.moveTo(br[0] - L, tl[1]); ctx.lineTo(br[0], tl[1]); ctx.lineTo(br[0], tl[1] + L)
            ctx.moveTo(br[0], br[1] - L); ctx.lineTo(br[0], br[1]); ctx.lineTo(br[0] - L, br[1])
            ctx.moveTo(tl[0] + L, br[1]); ctx.lineTo(tl[0], br[1]); ctx.lineTo(tl[0], br[1] - L)
            ctx.stroke()
            if (b.Z < 120) {
                ctx.fillStyle = col
                const label = b.lead ? (sim.fcw ? "BRAKE  " : "LEAD  ") + Math.round(b.Z - 4.6) + " m" : Math.round(b.Z) + " m"
                ctx.fillText(label, (tl[0] + br[0]) / 2, tl[1] - 8)
            }
        }
        for (const o of obsTags) {
            ctx.globalAlpha = alpha
            ctx.fillStyle = theme.css(o[3], 1)
            ctx.fillText(o[2], o[0], o[1] - 6)
        }

        // (1) Sensor Trust Meter: one ground ring per sensor around the car
        {
            const rings = [[3.4, sim.trustCam, "CAM", 2.0], [3.9, sim.trustRadar, "RADAR", 2.3], [4.4, sim.trustLidar, "LIDAR", 2.6]]
            ctx.font = "600 11px '" + theme.face + "'"; ctx.textAlign = "left"
            for (const rg of rings) {
                const col = rg[1] > 0.85 ? theme.good : rg[1] > 0.5 ? theme.warn : theme.danger
                ctx.beginPath()
                let first = true
                for (let a = -Math.PI; a <= Math.PI + 0.001; a += Math.PI / 36) {
                    const p = proj(Math.sin(a) * rg[0] * 0.75, 0.02, Math.cos(a) * rg[0])
                    if (!p) continue
                    if (first) { ctx.moveTo(p[0], p[1]); first = false } else ctx.lineTo(p[0], p[1])
                }
                ctx.setLineDash(rg[1] > 0.85 ? [] : [6, 6])
                ctx.lineWidth = 2; ctx.strokeStyle = theme.css(col, 0.35 + 0.4 * (1 - rg[1])); ctx.stroke()
                ctx.setLineDash([])
                const lp = proj(Math.sin(rg[3]) * rg[0] * 0.75, 0.02, Math.cos(rg[3]) * rg[0])
                if (lp) { ctx.fillStyle = theme.css(col, 0.9); ctx.fillText(rg[2] + " " + Math.round(rg[1] * 100), lp[0] + 6, lp[1] + 4) }
            }
        }

        drawEgoFront(ctx, proj, alpha, t)

        // weather overlays
        if (fog) {
            const fg = ctx.createLinearGradient(0, hz - 120, 0, hz + 220)
            fg.addColorStop(0, "rgba(150,165,180,0)")
            fg.addColorStop(0.45, "rgba(150,165,180,0.22)")
            fg.addColorStop(1, "rgba(150,165,180,0)")
            ctx.globalAlpha = alpha
            ctx.fillStyle = fg; ctx.fillRect(0, hz - 120, W, 340)
        }
        if (rain) {
            ctx.globalAlpha = alpha * 0.45
            ctx.strokeStyle = "rgba(190,215,240,1)"
            ctx.lineWidth = 1.2
            ctx.beginPath()
            for (let i = 0; i < 110; i++) {
                const sp2 = 0.8 + hash(i + 2) * 0.5
                const x = 480 + hash(i) * 960
                const y = (hash(i + 1) * H + t * 900 * sp2) % H
                ctx.moveTo(x, y); ctx.lineTo(x - 4, y + 16 * sp2)
            }
            ctx.stroke()
        }
        ctx.restore()
    }

    function drawEgoFront(ctx, proj, alpha, t) {
        const A = theme.accent
        const c0 = proj(0, 0, 0)
        ctx.save()
        ctx.globalAlpha = alpha
        ctx.translate(c0[0], c0[1]); ctx.scale(1, 0.32)
        const rg = ctx.createRadialGradient(0, 0, 0, 0, 0, 260)
        rg.addColorStop(0, theme.css(A, 0.45)); rg.addColorStop(0.45, theme.css(A, 0.12)); rg.addColorStop(1, theme.css(A, 0))
        ctx.fillStyle = rg
        ctx.beginPath(); ctx.arc(0, 0, 260, 0, tau); ctx.fill()
        ctx.restore()

        const levels = [
            { y: 0.32, poly: carPoly(0.98, 2.35, -2.3, 0.38), a: 0.45, w: 1.4 },
            { y: 0.92, poly: carPoly(0.95, 2.22, -2.18, 0.32), a: 0.95, w: 2 },
            { y: 1.46, poly: carPoly(0.70, 0.70, -1.30, 0.26), a: 1.0, w: 1.4 }
        ]
        const sp = levels.map(L => L.poly.map(q => proj(q[0], L.y, q[1])))
        ctx.save()
        ctx.globalAlpha = alpha
        ctx.fillStyle = "rgba(4,7,12,0.92)"
        poly(ctx, sp[0]); ctx.fill()
        poly(ctx, sp[1]); ctx.fill()
        ctx.strokeStyle = theme.css(A, 0.35); ctx.lineWidth = 1
        ctx.beginPath()
        for (let i = 0; i < 8; i++) { ctx.moveTo(sp[0][i][0], sp[0][i][1]); ctx.lineTo(sp[1][i][0], sp[1][i][1]) }
        ctx.stroke()
        const roof = sp[2]
        const gg = ctx.createLinearGradient(0, roof[0][1], 0, roof[4][1])
        gg.addColorStop(0, theme.css(A, 0.05)); gg.addColorStop(1, theme.css(A, 0.22))
        ctx.fillStyle = gg
        poly(ctx, roof); ctx.fill()
        for (let li = 0; li < 3; li++) { poly(ctx, sp[li]); glow(ctx, A, levels[li].a, levels[li].w) }
        const pil = [[[-0.62, 0.7], [-0.9, 1.45]], [[0.62, 0.7], [0.9, 1.45]], [[-0.62, -1.3], [-0.9, -1.95]], [[0.62, -1.3], [0.9, -1.95]]]
        ctx.beginPath()
        for (const p of pil) {
            const a = proj(p[0][0], 1.46, p[0][1]), b = proj(p[1][0], 0.92, p[1][1])
            ctx.moveTo(a[0], a[1]); ctx.lineTo(b[0], b[1])
        }
        ctx.lineWidth = 1.4; ctx.strokeStyle = theme.css(A, 0.85); ctx.stroke()
        // brake / tail light bar (brighter while decelerating)
        const braking = sim.accel < -3 || sim.brakeHeld
        const tlA = proj(-0.85, 0.86, -2.2), tlB = proj(0.85, 0.86, -2.2)
        ctx.beginPath(); ctx.moveTo(tlA[0], tlA[1]); ctx.lineTo(tlB[0], tlB[1])
        glow(ctx, theme.danger, braking ? 1 : 0.6, braking ? 4 : 2.5)
        // turn signals / hazard at the four corners
        if (sim.blinkOn) {
            for (const side of [-1, 1]) {
                if (!(sim.hazard || sim.indicator === side)) continue
                const r0 = proj(side * 0.95, 0.88, -2.0), r1 = proj(side * 0.75, 0.88, -2.2)
                const f0 = proj(side * 0.95, 0.88, 2.0), f1 = proj(side * 0.75, 0.88, 2.22)
                ctx.beginPath(); ctx.moveTo(r0[0], r0[1]); ctx.lineTo(r1[0], r1[1]); ctx.moveTo(f0[0], f0[1]); ctx.lineTo(f1[0], f1[1])
                glow(ctx, theme.warn, 1, 4)
            }
        }
        // LiDAR puck
        const pk = proj(0, 1.62, -0.1)
        const pulse = 0.5 + 0.5 * Math.sin(t * 6)
        ctx.fillStyle = theme.css(A, 0.25)
        ctx.beginPath(); ctx.arc(pk[0], pk[1], 9 + pulse * 3, 0, tau); ctx.fill()
        ctx.fillStyle = theme.css(theme.text, 0.7 + 0.3 * pulse)
        ctx.beginPath(); ctx.arc(pk[0], pk[1], 3 + pulse, 0, tau); ctx.fill()
        ctx.restore()
    }

    // =====================================================================
    // REAR — rear camera with fused detections
    // =====================================================================
    function drawRear(ctx, alpha) {
        const W = 1920, H = 720, cx = 960
        const hz = 250, F = 390, CH = 1.05
        const VX = 470, VY = 178, VW = 980, VH = 534
        const t = sim.time, lat = sim.lateral
        const rev = sim.gear === "R"
        const A = theme.accent, B = theme.accent2
        const cols = palette()
        const bt = {}
        // u = metres behind the rear bumper
        function proj(x, y, u) {
            const d = u + 0.55
            if (d < 0.25) return null
            return [cx + x * F / d, hz + (CH - y) * F / d, d]
        }
        ctx.save()
        ctx.globalAlpha = alpha
        ctx.beginPath(); ctx.rect(VX, VY, VW, VH); ctx.clip()

        // camera backdrop
        let g = ctx.createLinearGradient(0, VY, 0, H)
        g.addColorStop(0, "rgba(12,17,26,0.9)"); g.addColorStop(1, "rgba(18,25,36,0.96)")
        ctx.fillStyle = g; ctx.fillRect(VX, VY, VW, VH)
        g = ctx.createLinearGradient(0, 0, W, 0)
        g.addColorStop(0, "rgba(0,0,0,0)"); g.addColorStop(0.5, theme.css(B, 0.5)); g.addColorStop(1, "rgba(0,0,0,0)")
        ctx.fillStyle = g; ctx.fillRect(0, hz, W, 1)

        // ground grid points (hidden behind the wall when reversing)
        const uMax = rev ? sim.parkGap : 16
        for (let u = 0.2; u < uMax; u += (u < 4 ? 0.4 : 0.9))
            for (let x = -7; x <= 7; x += 0.6) {
                const p = proj(x, 0, u); if (!p) continue
                const s = Math.max(1.2, Math.min(3, 30 / p[2]))
                pt(bt, 9, 0.35 * Math.max(0, 1 - u / 16), p[0] - s / 2, p[1] - s / 2, s, s)
            }

        const labels = []
        if (rev) {
            const gap = sim.parkGap
            const near = gap < 0.6 ? 10 : gap < 1.2 ? 11 : 8
            // wall behind
            for (let x = -6; x <= 6; x += 0.2)
                for (let y = 0.05; y < 2.4; y += 0.2) {
                    const p = proj(x, y, gap); if (!p) continue
                    const s = Math.max(1.5, Math.min(5, 40 / p[2]))
                    pt(bt, Math.abs(x) < 1.3 ? near : 9, 0.55 * (1 - y / 3.2), p[0] - s / 2, p[1] - s / 2, s, s)
                }
            // wall plane
            {
                const a = proj(-6, 2.4, gap), b = proj(6, 0, gap)
                if (a && b) {
                    ctx.fillStyle = theme.css(theme.accent2, 0.08); ctx.fillRect(a[0], a[1], b[0] - a[0], b[1] - a[1])
                    ctx.beginPath(); ctx.moveTo(a[0], b[1]); ctx.lineTo(b[0], b[1])
                    glow(ctx, gap < 0.6 ? theme.danger : gap < 1.2 ? theme.warn : theme.accent2, 0.9, 2)
                }
            }
            // bay lines
            ctx.fillStyle = "rgba(234,242,247,0.30)"
            for (const bx of [-1.35, 1.35, -4.05, 4.05]) {
                const u0 = Math.max(0.05, gap - 5.4), u1 = gap
                const a = proj(bx - 0.06, 0, u0), b = proj(bx + 0.06, 0, u0), c = proj(bx + 0.06, 0, u1), d = proj(bx - 0.06, 0, u1)
                if (a && b && c && d) { poly(ctx, [a, b, c, d]); ctx.fill() }
            }
            // neighbouring parked cars (inner side faces)
            for (const side of [-1, 1]) {
                const sx = side * 1.75
                for (let u = Math.max(0.1, gap - 4.8); u < gap - 0.3; u += 0.22)
                    for (let y = 0.3; y < 1.4; y += 0.18) {
                        const p = proj(sx, y, u); if (!p) continue
                        const s = Math.max(1.4, Math.min(5, 36 / p[2]))
                        pt(bt, 8, 0.5, p[0] - s / 2, p[1] - s / 2, s, s)
                    }
            }
            const tp = proj(0, 2.5, gap)
            if (tp) labels.push([tp[0], tp[1], "WALL  " + gap.toFixed(2) + " m", cols[near]])
            // garage lintel 2.6 m in front of the wall
            const ul = gap - 2.6
            if (ul > 0.15) {
                const okH = sim.heightMargin >= 0.05, tight = sim.heightMargin >= 0 && !okH
                const lc = okH ? theme.good : tight ? theme.warn : theme.danger
                const a = proj(-1.6, sim.openingHeight, ul), b = proj(1.6, sim.openingHeight, ul)
                const a0 = proj(-1.6, 0, ul), b0 = proj(1.6, 0, ul)
                if (a && b && a0 && b0) {
                    ctx.beginPath(); ctx.moveTo(a0[0], a0[1]); ctx.lineTo(a[0], a[1]); ctx.lineTo(b[0], b[1]); ctx.lineTo(b0[0], b0[1])
                    glow(ctx, lc, 0.9, 3)
                    labels.push([(a[0] + b[0]) / 2, a[1], "OPENING " + sim.openingHeight.toFixed(2) + " m", rgb(lc)])
                }
            }

            // crossing pedestrian
            if (sim.pedActive) {
                const px = sim.pedX, pu = sim.pedU
                const inPath = Math.abs(px) < 1.7
                const ci = inPath ? 10 : 11
                const sw = Math.sin(t * 7) * 0.18
                const parts = []
                for (let a = 0; a < tau; a += 0.3) parts.push([px + Math.cos(a) * 0.11, 1.62 + Math.sin(a) * 0.11])
                for (let y = 0.95; y < 1.5; y += 0.04) { parts.push([px - 0.06, y]); parts.push([px + 0.06, y]) }
                for (let f = 0; f <= 1; f += 0.06) {
                    parts.push([px + sw * f, 0.95 - 0.9 * f]); parts.push([px - sw * f, 0.95 - 0.9 * f])
                    parts.push([px + 0.25 * f - sw * 0.5 * f, 1.42 - 0.45 * f]); parts.push([px - 0.25 * f + sw * 0.5 * f, 1.42 - 0.45 * f])
                }
                for (const q of parts) {
                    const p = proj(q[0], q[1], pu); if (!p) continue
                    const s2 = Math.max(2.5, Math.min(6, 12 / p[2]))
                    pt(bt, ci, 1, p[0] - s2 / 2, p[1] - s2 / 2, s2, s2)
                }
                const tl = proj(px - 0.5, 1.9, pu), br = proj(px + 0.5, 0, pu)
                if (tl && br) labels.push([(tl[0] + br[0]) / 2, tl[1], "PEDESTRIAN  " + pu.toFixed(1) + " m", cols[ci], tl, br])
            }
        } else {
            // driving: digital rear view — lanes + following traffic
            ctx.fillStyle = "rgba(234,242,247,0.35)"
            for (const lx of [-5.4, -1.8, 1.8, 5.4]) {
                const x = lx - lat
                const a = proj(x - 0.07, 0, 0.1), b = proj(x + 0.07, 0, 0.1), c = proj(x + 0.07, 0, 90), d = proj(x - 0.07, 0, 90)
                if (a && b && c && d) { poly(ctx, [a, b, c, d]); ctx.fill() }
            }
            for (const c of sim.traffic) {
                if (c.z > -2) continue
                const u = -(c.z + 2.3) - 2.3
                if (u < 0.5 || u > 90) continue
                const X = c.x - lat
                const bs = (X < -1.8 && sim.bsLeft || X > 1.8 && sim.bsRight) && u < 10
                const ci = bs ? 10 : u < 12 ? 11 : 8
                for (let xx = -0.95; xx <= 0.951; xx += 0.19)
                    for (let yy = 0.25; yy <= 1.46; yy += 0.17) {
                        if (yy > 1.0 && Math.abs(xx) > 0.74) continue
                        const p = proj(X + xx, yy, u); if (!p) continue
                        const s = Math.max(1.4, Math.min(5, 50 / p[2]))
                        pt(bt, ci, 0.85, p[0] - s / 2, p[1] - s / 2, s, s)
                    }
                const tl = proj(X - 1.1, 1.7, u), br = proj(X + 1.1, 0, u)
                if (tl && br) labels.push([(tl[0] + br[0]) / 2, tl[1], (bs ? "BLIND SPOT  " : "") + Math.round(u) + " m", cols[ci], tl, br])
            }
        }
        flush(ctx, bt, cols, alpha)

        // guide lines (reverse) with distance bands and steering curve
        if (rev) {
            const st = sim.steer
            const bands = [[0.0, 0.5, theme.danger], [0.5, 1.5, theme.warn], [1.5, 3.0, theme.good]]
            for (const side of [-1, 1]) {
                for (const bd of bands) {
                    ctx.beginPath()
                    let first = true
                    for (let s = bd[0]; s <= bd[1] + 0.001; s += 0.1) {
                        const p = proj(side * 0.98 + st * s * s * 0.45, 0, s + 0.05); if (!p) continue
                        if (first) { ctx.moveTo(p[0], p[1]); first = false } else ctx.lineTo(p[0], p[1])
                    }
                    glow(ctx, bd[2], 0.9, 4)
                }
            }
            for (const s of [0.5, 1.5, 3.0]) {
                const l = proj(-0.98 + st * s * s * 0.45, 0, s + 0.05), r = proj(0.98 + st * s * s * 0.45, 0, s + 0.05)
                if (!l || !r) continue
                ctx.beginPath(); ctx.moveTo(l[0], l[1]); ctx.lineTo(l[0] + (r[0] - l[0]) * 0.18, l[1])
                ctx.moveTo(r[0], r[1]); ctx.lineTo(r[0] - (r[0] - l[0]) * 0.18, r[1])
                glow(ctx, s < 1 ? theme.danger : s < 2 ? theme.warn : theme.good, 0.9, 3)
            }
            // static width corridor
            ctx.setLineDash([8, 10])
            ctx.beginPath()
            for (const side of [-1, 1]) {
                const a = proj(side * 0.98, 0, 0.05), b = proj(side * 0.98, 0, 3.2)
                ctx.moveTo(a[0], a[1]); ctx.lineTo(b[0], b[1])
            }
            ctx.lineWidth = 1.5; ctx.strokeStyle = theme.css(theme.text, 0.35); ctx.stroke()
            ctx.setLineDash([])
        }

        // labels & boxes
        ctx.font = "600 14px '" + theme.face + "'"
        ctx.textAlign = "center"
        for (const l of labels) {
            ctx.globalAlpha = alpha
            if (l[4]) {
                const tl = l[4], br = l[5]
                ctx.strokeStyle = l[3]; ctx.lineWidth = 2
                ctx.strokeRect(tl[0], tl[1], br[0] - tl[0], br[1] - tl[1])
            }
            ctx.fillStyle = l[3]
            ctx.fillText(l[2], l[0], l[1] - 10)
        }

        // rear bumper silhouette at the bottom edge
        ctx.globalAlpha = alpha
        ctx.beginPath()
        ctx.moveTo(650, 720); ctx.quadraticCurveTo(700, 668, 820, 662); ctx.lineTo(1100, 662); ctx.quadraticCurveTo(1220, 668, 1270, 720)
        ctx.fillStyle = "rgba(6,9,14,0.95)"; ctx.fill()
        glow(ctx, A, 0.8, 2)

        // auto-brake frame
        if (rev && sim.rearAeb) {
            const pulse = 0.5 + 0.5 * Math.abs(Math.sin(t * 8))
            ctx.lineWidth = 8
            ctx.strokeStyle = theme.css(theme.danger, 0.4 + 0.5 * pulse)
            ctx.strokeRect(VX + 4, VY + 4, VW - 8, VH - 8)
        } else {
            ctx.lineWidth = 1.5
            ctx.strokeStyle = theme.css(A, 0.35)
            ctx.strokeRect(VX + 1, VY + 1, VW - 2, VH - 2)
        }
        ctx.font = "600 12px '" + theme.face + "'"
        ctx.fillStyle = theme.css(theme.sub, 0.9)
        ctx.textAlign = "left"
        ctx.fillText(rev ? "REAR CAMERA  ·  LIDAR FUSION  ·  AUTO-BRAKE ARMED" : "DIGITAL REAR VIEW  ·  BSM", VX + 20, VY + 26)
        ctx.textAlign = "right"
        ctx.fillText("CHECK SURROUNDINGS", VX + VW - 20, VY + 26)
        if (rev) {
            const hm = sim.heightMargin, wm = sim.widthMargin
            const fits = hm >= 0 && wm >= 0
            ctx.font = "700 14px '" + theme.face + "'"
            ctx.fillStyle = theme.css(fits ? (hm < 0.05 ? theme.warn : theme.good) : theme.danger, 1)
            ctx.fillText((fits ? "FITS" : "WILL NOT FIT") + " · HEIGHT " + (hm >= 0 ? "+" : "") + Math.round(hm * 100) + " cm"
                         + (sim.roofBox ? " (roof box)" : "") + " · WIDTH +" + Math.round(wm * 100) + " cm / side", VX + VW - 20, VY + 50)
        }
        ctx.restore()
    }

    // =====================================================================
    // TOP (driving) — 360° bird's-eye of the road
    // =====================================================================
    function drawTopRoad(ctx, alpha) {
        const cx = 960, cy = 440, S = 19
        const t = sim.time, odo = sim.odometer, lat = sim.lateral
        const A = theme.accent, B = theme.accent2
        const cols = palette()
        const bt = {}
        function P(x, z) { return [cx + x * S, cy - z * S] }
        ctx.save()
        ctx.globalAlpha = alpha

        let rg = ctx.createRadialGradient(cx, cy, 0, cx, cy, 420)
        rg.addColorStop(0, theme.css(A, 0.10)); rg.addColorStop(1, theme.css(A, 0))
        ctx.fillStyle = rg; ctx.fillRect(cx - 440, cy - 440, 880, 880)

        // range rings
        ctx.setLineDash([3, 6]); ctx.lineWidth = 1
        for (const r of [5, 10, 20]) {
            ctx.strokeStyle = theme.css(B, 0.22)
            ctx.beginPath(); ctx.arc(cx, cy, r * S, 0, tau); ctx.stroke()
        }
        ctx.setLineDash([])
        ctx.font = "400 11px '" + theme.face + "'"; ctx.fillStyle = theme.css(theme.sub, 0.7); ctx.textAlign = "left"
        for (const r of [5, 10]) ctx.fillText(r + " m", cx + 4, cy - r * S - 4)

        // road edges + dashed lanes
        for (const lx of [-5.4, 5.4]) {
            const a = P(lx - lat, -40), b = P(lx - lat, 45)
            ctx.beginPath(); ctx.moveTo(a[0], a[1]); ctx.lineTo(b[0], b[1])
            ctx.lineWidth = 2.5; ctx.strokeStyle = "rgba(234,242,247,0.45)"; ctx.stroke()
        }
        const k0 = Math.floor(odo / 9)
        ctx.beginPath()
        for (const lx of [-1.8, 1.8])
            for (let k = k0 - 6; k < k0 + 7; k++) {
                const z0 = k * 9 - odo
                const a = P(lx - lat, z0), b = P(lx - lat, z0 + 3.2)
                ctx.moveTo(a[0], a[1]); ctx.lineTo(b[0], b[1])
            }
        ctx.lineWidth = 2; ctx.strokeStyle = "rgba(234,242,247,0.35)"; ctx.stroke()

        // guard-rail returns + roadside structures (LiDAR points)
        for (const side of [-1, 1]) {
            const rx = side * 7.6 - lat
            const ph = ((odo % 1.2) + 1.2) % 1.2
            for (let z = -22 - ph; z < 26; z += 1.2) {
                const p = P(rx, z)
                pt(bt, side > 0 ? 9 : 8, 0.7, p[0] - 1.5, p[1] - 1.5, 3, 3)
            }
            const sk = Math.floor(odo / 4)
            for (let k = sk - 6; k < sk + 8; k++) {
                const z = k * 4 - odo
                const h1 = hash(k * 2 + (side > 0 ? 1 : 0))
                if (h1 < 0.32) continue
                const xw = side * (10.5 + hash(k * 3.7 + side) * 17) - lat
                const sz = 0.6 + h1 * 2.2
                for (let a = 0; a < tau; a += 0.5) {
                    const p = P(xw + Math.cos(a) * sz, z + Math.sin(a) * sz)
                    pt(bt, 9, 0.35, p[0] - 1.2, p[1] - 1.2, 2.4, 2.4)
                }
            }
        }

        // blind-spot zones
        for (const side of [-1, 1]) {
            const on = side < 0 ? sim.bsLeft : sim.bsRight
            const lx = (sim.egoLane + side) * 3.6 - lat
            if (Math.abs(sim.egoLane + side) > 1) continue
            const a = P(lx - 1.6, 3), b = P(lx + 1.6, -10)
            ctx.fillStyle = theme.css(on ? theme.danger : B, on ? 0.28 : 0.05)
            ctx.fillRect(a[0], a[1], b[0] - a[0], b[1] - a[1])
            ctx.lineWidth = 1.5; ctx.strokeStyle = theme.css(on ? theme.danger : B, on ? 0.9 : 0.25)
            ctx.strokeRect(a[0], a[1], b[0] - a[0], b[1] - a[1])
            ctx.fillStyle = theme.css(on ? theme.danger : theme.sub, 0.9)
            ctx.textAlign = "center"; ctx.font = "600 11px '" + theme.face + "'"
            ctx.fillText(on ? "BLIND SPOT" : "BSM", (a[0] + b[0]) / 2, a[1] - 8)
        }

        // beam wedge
        const beam = (t * 2.2) % tau
        for (let i = 0; i < 14; i++) {
            const a = beam - i * 0.05
            ctx.globalAlpha = alpha * 0.05 * (1 - i / 14)
            ctx.fillStyle = theme.css(A, 1)
            const p1 = P(Math.sin(a) * 22, Math.cos(a) * 22), p2 = P(Math.sin(a - 0.05) * 22, Math.cos(a - 0.05) * 22)
            ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(p1[0], p1[1]); ctx.lineTo(p2[0], p2[1]); ctx.closePath(); ctx.fill()
        }
        ctx.globalAlpha = alpha

        // vehicles as point outlines
        const lead = sim.leadDistance
        let leadCar = null
        for (const c of sim.traffic) {
            const X = c.x - lat, Z = c.z
            if (Z < -20 || Z > 26) continue
            const rel = X
            const bs = Z > -10 && Z < 3 && ((rel < -1.8 && sim.bsLeft) || (rel > 1.8 && sim.bsRight))
            const isLead = Math.abs(X) < 1.7 && Z > 0 && Math.abs(Z - 4.6 - lead) < 0.05
            if (isLead) leadCar = c
            const ci = bs || (isLead && sim.fcw) ? 10 : (Math.abs(Z) < 14 ? 11 : 8)
            const body = carPoly(0.95, Z + 2.3, Z - 2.3, 0.45)
            ctx.fillStyle = cols[ci]; ctx.globalAlpha = alpha * 0.12
            poly(ctx, body.map(q => P(X + q[0], q[1]))); ctx.fill()
            for (let i = 0; i < body.length; i++) {
                const a = body[i], b = body[(i + 1) % body.length]
                const n = Math.max(2, Math.floor(Math.hypot(b[0] - a[0], b[1] - a[1]) / 0.3))
                for (let k = 0; k < n; k++) {
                    const f = k / n
                    const p = P(X + a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f)
                    pt(bt, ci, 0.9, p[0] - 1.5, p[1] - 1.5, 3, 3)
                }
            }
        }
        ctx.globalAlpha = alpha
        flush(ctx, bt, cols, alpha)

        // ACC link to lead
        if (leadCar && sim.gear === "D") {
            const a = P(0, 2.4), b = P(leadCar.x - lat, Math.min(20, leadCar.z - 2.3))
            ctx.setLineDash([6, 6])
            ctx.beginPath(); ctx.moveTo(a[0], a[1]); ctx.lineTo(b[0], b[1])
            ctx.lineWidth = 2; ctx.strokeStyle = theme.css(sim.fcw ? theme.danger : A, 0.9); ctx.stroke()
            ctx.setLineDash([])
            ctx.fillStyle = theme.css(sim.fcw ? theme.danger : theme.text, 1)
            ctx.textAlign = "left"; ctx.font = "600 13px '" + theme.face + "'"
            ctx.fillText(Math.round(lead) + " m · " + sim.leadGapSec.toFixed(1) + " s", (a[0] + b[0]) / 2 + 12, (a[1] + b[1]) / 2)
        }

        drawEgoTop(ctx, P, alpha)
        ctx.restore()
    }

    // =====================================================================
    // TOP (reverse) — parking bay with proximity bands
    // =====================================================================
    function drawPark(ctx, alpha) {
        const cx = 960, cy = 380, S = 40
        const t = sim.time
        const A = theme.accent, B = theme.accent2
        const gap = sim.parkGap
        const rearZ = -2.3, wallZ = rearZ - gap
        const beam = (t * 2.2) % tau
        const cols = palette()
        const bt = {}
        function P(x, z) { return [cx + x * S, cy - z * S] }
        function beamI(x, z) { let dd = beam - Math.atan2(x, -z); dd -= Math.floor(dd / tau) * tau; return Math.exp(-dd * 1.5) }

        ctx.save()
        ctx.globalAlpha = alpha
        let rg = ctx.createRadialGradient(cx, cy, 0, cx, cy, 420)
        rg.addColorStop(0, theme.css(A, 0.10)); rg.addColorStop(1, theme.css(A, 0))
        ctx.fillStyle = rg; ctx.fillRect(cx - 440, cy - 440, 880, 880)

        // radial-faded floor grid
        ctx.lineWidth = 1
        ctx.strokeStyle = theme.css(B, 1)
        const zOff = wallZ - Math.floor(wallZ)
        for (let i = -8; i <= 8; i++)
            for (let j = -8; j < 8; j++) {
                const fv = Math.max(0, 1 - Math.hypot(i, j + 0.5) / 8)
                const fh = Math.max(0, 1 - Math.hypot(j + 0.5, i + zOff) / 8)
                if (fv > 0) { ctx.globalAlpha = alpha * 0.14 * fv; const a = P(i, j), b = P(i, j + 1); ctx.beginPath(); ctx.moveTo(a[0], a[1]); ctx.lineTo(b[0], b[1]); ctx.stroke() }
                if (fh > 0) { ctx.globalAlpha = alpha * 0.14 * fh; const a = P(j, i + zOff), b = P(j + 1, i + zOff); ctx.beginPath(); ctx.moveTo(a[0], a[1]); ctx.lineTo(b[0], b[1]); ctx.stroke() }
            }
        ctx.globalAlpha = alpha

        // bay lines
        ctx.strokeStyle = "rgba(234,242,247,0.45)"; ctx.lineWidth = 2.5
        ctx.beginPath()
        for (const bx of [-4.05, -1.35, 1.35, 4.05]) { const a = P(bx, wallZ + 0.1), b = P(bx, wallZ + 5.4); ctx.moveTo(a[0], a[1]); ctx.lineTo(b[0], b[1]) }
        ctx.stroke()

        // beam wedge
        for (let i = 0; i < 14; i++) {
            const a = beam - i * 0.045
            ctx.globalAlpha = alpha * 0.045 * (1 - i / 14)
            ctx.fillStyle = theme.css(A, 1)
            const p1 = P(Math.sin(a) * 7, -Math.cos(a) * 7), p2 = P(Math.sin(a - 0.05) * 7, -Math.cos(a - 0.05) * 7)
            ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(p1[0], p1[1]); ctx.lineTo(p2[0], p2[1]); ctx.closePath(); ctx.fill()
        }
        ctx.globalAlpha = alpha

        const nearCi = gap < 0.6 ? 10 : gap < 1.2 ? 11 : 8
        function cloud(x, z, ci, base) {
            const p = P(x + (hash(x * 91 + z * 13) - 0.5) * 0.05, z)
            pt(bt, ci, base + (1 - base) * beamI(x, z), p[0] - 1.5, p[1] - 1.5, 3, 3)
        }
        for (let x = -6.5; x <= 6.5; x += 0.14) { cloud(x, wallZ, Math.abs(x) < 1.4 ? nearCi : 9, 0.3); cloud(x, wallZ - 0.18, 9, 0.12) }
        for (const px of [-5.4, 5.4]) for (let a = 0; a < tau; a += 0.22) cloud(px + Math.cos(a) * 0.35, wallZ + 0.4 + Math.sin(a) * 0.35, 9, 0.25)
        for (const pxc of [-2.7, 2.7]) {
            const zc = wallZ + 0.45 + 2.3
            const body = carPoly(0.95, zc + 2.3, zc - 2.3, 0.45)
            ctx.globalAlpha = alpha * 0.10; ctx.fillStyle = cols[8]
            poly(ctx, body.map(q => P(pxc + q[0], q[1]))); ctx.fill()
            for (let i = 0; i < body.length; i++) {
                const a = body[i], b = body[(i + 1) % body.length]
                const n = Math.max(2, Math.floor(Math.hypot(b[0] - a[0], b[1] - a[1]) / 0.13))
                for (let k = 0; k < n; k++) {
                    const f = k / n
                    const x = pxc + a[0] + (b[0] - a[0]) * f, z = a[1] + (b[1] - a[1]) * f
                    const facing = (pxc < 0 && x > pxc + 0.5) || (pxc > 0 && x < pxc - 0.5)
                    cloud(x, z, facing ? 8 : 9, facing ? 0.4 : 0.15)
                }
            }
        }
        // pedestrian
        if (sim.pedActive) {
            const pz = wallZ + 1.2
            const ci = Math.abs(sim.pedX) < 1.7 ? 10 : 11
            for (let a = 0; a < tau; a += 0.3) cloud(sim.pedX + Math.cos(a) * 0.25, pz + Math.sin(a) * 0.18, ci, 0.9)
        }
        ctx.globalAlpha = alpha
        flush(ctx, bt, cols, alpha)

        // guide lines
        const st = sim.steer
        ctx.setLineDash([10, 8])
        for (const sx of [-0.95, 0.95]) {
            ctx.beginPath()
            for (let s = 0; s <= Math.min(3.4, gap); s += 0.2) { const p = P(sx + st * s * s * 0.45, rearZ - s); s === 0 ? ctx.moveTo(p[0], p[1]) : ctx.lineTo(p[0], p[1]) }
            ctx.lineWidth = 3; ctx.strokeStyle = theme.css(A, 0.8); ctx.stroke()
        }
        ctx.setLineDash([])

        // proximity bands
        const level = gap < 0.55 ? 3 : gap < 1.0 ? 2 : gap < 1.8 ? 1 : 0
        const pulse = level === 3 ? 0.55 + 0.45 * Math.abs(Math.sin(t * 9)) : 1
        function bands(cz, down, lvl) {
            const c = P(0, cz)
            const base = down ? Math.PI / 2 : -Math.PI / 2
            const secs = 4, spread = 1.75, stp = spread / secs
            const bc = [theme.danger, theme.warn, theme.good]
            for (let b = 0; b < 3; b++) {
                const r = S * (1.2 + b * 0.36)
                const on = lvl >= 3 - b
                for (let si = 0; si < secs; si++) {
                    const a0 = base - spread / 2 + si * stp + 0.03
                    ctx.beginPath(); ctx.arc(c[0], c[1], r, a0, a0 + stp - 0.06, false)
                    if (on) glow(ctx, bc[b], 0.9 * pulse, 8)
                    else { ctx.lineWidth = 8; ctx.strokeStyle = theme.css(theme.dim, 0.22); ctx.stroke() }
                }
            }
        }
        bands(rearZ + 0.7, true, level)
        bands(2.3 - 0.7, false, 0)

        drawEgoTop(ctx, P, alpha, S)

        const tagP = P(0, wallZ - 1.5)
        ctx.globalAlpha = alpha
        ctx.font = "300 22px '" + theme.face + "'"; ctx.textAlign = "center"
        ctx.fillStyle = cols[nearCi]
        ctx.fillText(gap.toFixed(2) + " m", tagP[0], tagP[1] + 8)
        ctx.restore()
    }

    function drawEgoTop(ctx, P, alpha) {
        const A = theme.accent
        const body = carPoly(0.96, 2.32, -2.32, 0.5)
        ctx.save()
        ctx.globalAlpha = alpha
        const top = P(0, 2.32), bot = P(0, -2.32)
        const bg = ctx.createLinearGradient(0, top[1], 0, bot[1])
        bg.addColorStop(0, "rgba(22,30,40,0.98)"); bg.addColorStop(1, "rgba(10,14,20,0.98)")
        ctx.fillStyle = bg
        poly(ctx, body.map(q => P(q[0], q[1]))); ctx.fill()
        glow(ctx, A, 0.95, 2)
        function fillPoly(pts, fill) { poly(ctx, pts.map(q => P(q[0], q[1]))); ctx.fillStyle = fill; ctx.fill() }
        fillPoly([[-0.78, 1.25], [0.78, 1.25], [0.66, 0.45], [-0.66, 0.45]], theme.css(A, 0.30))
        fillPoly([[-0.66, 0.38], [0.66, 0.38], [0.66, -1.15], [-0.66, -1.15]], theme.css(A, 0.10))
        fillPoly([[-0.66, -1.22], [0.66, -1.22], [0.74, -1.75], [-0.74, -1.75]], theme.css(A, 0.24))
        fillPoly([[-0.96, 0.95], [-1.18, 0.88], [-1.18, 0.72], [-0.96, 0.75]], theme.css(A, 0.6))
        fillPoly([[0.96, 0.95], [1.18, 0.88], [1.18, 0.72], [0.96, 0.75]], theme.css(A, 0.6))
        let a = P(-0.7, -2.3), b = P(0.7, -2.3)
        ctx.beginPath(); ctx.moveTo(a[0], a[1]); ctx.lineTo(b[0], b[1]); glow(ctx, theme.danger, 0.95, 3)
        ctx.beginPath()
        a = P(-0.75, 2.3); b = P(-0.35, 2.3); ctx.moveTo(a[0], a[1]); ctx.lineTo(b[0], b[1])
        a = P(0.35, 2.3); b = P(0.75, 2.3); ctx.moveTo(a[0], a[1]); ctx.lineTo(b[0], b[1])
        glow(ctx, theme.text, 0.9, 3)
        ctx.restore()
    }

    // =====================================================================
    // UNDER — see-through underbody + wheel alignment / TPMS
    // =====================================================================
    function drawUnder(ctx, alpha) {
        const cx = 960, cy = 405, S = 66
        const t = sim.time, odo = sim.odometer, lat = sim.lateral
        const A = theme.accent, B = theme.accent2
        const cols = palette()
        const bt = {}
        function P(x, z) { return [cx + x * S, cy - z * S] }
        ctx.save()
        ctx.globalAlpha = alpha

        let rg = ctx.createRadialGradient(cx, cy, 0, cx, cy, 380)
        rg.addColorStop(0, "rgba(40,48,60,0.55)"); rg.addColorStop(1, "rgba(10,14,20,0)")
        ctx.fillStyle = rg; ctx.fillRect(cx - 400, cy - 400, 800, 800)

        // ground texture (world-fixed, scrolls with travel)
        const step = 0.22
        const r0 = Math.floor((odo - 5) / step), r1 = Math.floor((odo + 5) / step)
        for (let r = r0; r <= r1; r++) {
            const z = r * step - odo
            for (let c = -16; c <= 16; c++) {
                const h = hash(r * 31.7 + c * 7.3)
                if (h < 0.35) continue
                const x = c * step + (hash(r + c * 3.1) - 0.5) * step
                const d = Math.hypot(x / 4, z / 5)
                if (d > 1) continue
                const p = P(x, z)
                const s = 1.5 + h * 2
                pt(bt, 14, (0.25 + 0.5 * h) * (1 - d), p[0], p[1], s, s)
            }
        }
        // lane marking passing under the car
        for (const lx of [-5.4, -1.8, 1.8, 5.4]) {
            const x = lx - lat
            if (Math.abs(x) > 3.6) continue
            for (let k = Math.floor((odo - 5) / 9); k <= Math.floor((odo + 5) / 9); k++) {
                const z0 = Math.max(-3.4, k * 9 - odo), z1 = Math.min(3.4, k * 9 + 3.2 - odo)
                if (z1 <= z0) continue
                const a = P(x - 0.07, z1), b = P(x + 0.07, z0)
                ctx.fillStyle = "rgba(234,242,247,0.22)"
                ctx.fillRect(a[0], a[1], b[0] - a[0], b[1] - a[1])
            }
        }
        // obstacle under / near the car
        const ob = sim.obstacle
        const oz = sim.obstacleDist + 2.3
        let obsLabel = null
        if (oz > -5 && oz < 5.5) {
            const risk = sim.underbodyRisk
            if (ob.type === "Speed bump") {
                for (let x = -2.2; x <= 2.2; x += 0.45) {
                    const a = P(x, oz + 0.25), b = P(x + 0.45, oz - 0.25)
                    ctx.fillStyle = theme.css((Math.round(x / 0.45) % 2) ? theme.warn : theme.text, 0.55)
                    ctx.fillRect(a[0], a[1], b[0] - a[0], b[1] - a[1])
                }
            } else if (ob.type === "Pothole") {
                const p = P(0.35, oz)
                ctx.save(); ctx.translate(p[0], p[1]); ctx.scale(1, 0.7)
                ctx.beginPath(); ctx.arc(0, 0, 0.45 * S, 0, tau)
                ctx.fillStyle = "rgba(0,0,0,0.85)"; ctx.fill()
                ctx.restore()
                ctx.beginPath(); ctx.arc(p[0], p[1], 0.45 * S, 0, tau)
                ctx.lineWidth = 2; ctx.strokeStyle = theme.css(theme.warn, 0.8); ctx.stroke()
            } else {
                for (let a = 0; a < tau; a += 0.12)
                    for (let rr = 0.05; rr < 0.35; rr += 0.07) {
                        const p = P(-0.3 + Math.cos(a) * rr, oz + Math.sin(a) * rr * 0.8)
                        pt(bt, risk ? 10 : 11, 0.9, p[0] - 2, p[1] - 2, 4, 4)
                    }
            }
            const lp = P(1.25, oz)
            obsLabel = [lp[0], lp[1], ob.type.toUpperCase() + "  " + Math.abs(ob.h) + " mm" + (ob.h < 0 ? " deep" : ""),
                        (sim.crossSpeed === 0 ? "STEER AROUND" : "CROSS ≤ " + sim.crossSpeed + " km/h") + " · SCRAPE " + Math.round(sim.scrapeProb * 100)
                        + " % · CLEARANCE " + Math.round(sim.effClearance) + " mm", risk]
        }
        flush(ctx, bt, cols, alpha)

        // predicted tyre tracks
        const st = sim.steer
        const dir = sim.gear === "R" ? -1 : 1
        ctx.setLineDash([6, 8])
        for (const sx of [-0.8, 0.8]) {
            ctx.beginPath()
            for (let s = 0; s <= 3.5; s += 0.25) {
                const p = P(sx + st * s * s * 0.3 * dir, dir * (1.4 + s))
                s === 0 ? ctx.moveTo(p[0], p[1]) : ctx.lineTo(p[0], p[1])
            }
            ctx.lineWidth = 2; ctx.strokeStyle = theme.css(A, 0.6); ctx.stroke()
        }
        ctx.setLineDash([])

        // transparent body
        const body = carPoly(0.96, 2.32, -2.32, 0.5)
        poly(ctx, body.map(q => P(q[0], q[1])))
        ctx.fillStyle = theme.css(A, 0.05); ctx.fill()
        glow(ctx, A, 0.9, 2)
        // chassis rails, motor, battery pack outline
        ctx.lineWidth = 1.2; ctx.strokeStyle = theme.css(B, 0.45)
        let a = P(-0.6, 1.0), b = P(0.6, -1.0)
        ctx.strokeRect(a[0], a[1], b[0] - a[0], b[1] - a[1])
        ctx.fillStyle = theme.css(B, 0.06); ctx.fillRect(a[0], a[1], b[0] - a[0], b[1] - a[1])
        ctx.font = "600 11px '" + theme.face + "'"; ctx.textAlign = "center"; ctx.fillStyle = theme.css(theme.sub, 0.9)
        ctx.fillText("BATTERY PACK  " + Math.round(sim.batteryTemp) + "°C", cx, cy + 4)
        a = P(-0.35, 1.85); b = P(0.35, 1.25)
        ctx.strokeRect(a[0], a[1], b[0] - a[0], b[1] - a[1])
        ctx.fillText("MOTOR " + Math.round(sim.motorTemp) + "°C", cx, a[1] - 6)

        // wheels with TPMS + alignment
        const wp = [[-0.8, 1.38, 0], [0.8, 1.38, 1], [-0.8, -1.38, 2], [0.8, -1.38, 3]]
        for (const w of wp) {
            const data = sim.wheels[w[2]]
            const bad = sim.wheelBad(data)
            const front = w[1] > 0
            const angle = front ? st * 0.9 + (w[2] === 0 && sim.alignFault ? 0.08 : 0) : 0
            const c = P(w[0], w[1])
            ctx.save()
            ctx.translate(c[0], c[1]); ctx.rotate(angle)
            const ww = 0.24 * S, wh = 0.68 * S
            ctx.fillStyle = "rgba(8,11,16,0.95)"
            ctx.fillRect(-ww / 2, -wh / 2, ww, wh)
            ctx.beginPath(); ctx.rect(-ww / 2, -wh / 2, ww, wh)
            glow(ctx, bad ? theme.warn : A, 0.95, 2)
            // tread marks
            ctx.strokeStyle = theme.css(bad ? theme.warn : A, 0.35); ctx.lineWidth = 1
            ctx.beginPath()
            for (let k = -3; k <= 3; k++) { ctx.moveTo(-ww / 2 + 2, k * wh / 8); ctx.lineTo(ww / 2 - 2, k * wh / 8 + 3) }
            ctx.stroke()
            ctx.restore()
            // label
            const side = w[0] < 0 ? -1 : 1
            const lx = c[0] + side * 36
            ctx.textAlign = side < 0 ? "right" : "left"
            ctx.font = "600 12px '" + theme.face + "'"
            ctx.fillStyle = theme.css(bad ? theme.warn : theme.text, 1)
            ctx.fillText(data.id + "  " + data.psi.toFixed(1) + " psi  ·  " + Math.round(data.temp) + "°C", lx, c[1] - 8)
            ctx.font = "400 12px '" + theme.face + "'"
            ctx.fillStyle = theme.css(Math.abs(data.toe) > 0.25 ? theme.warn : theme.sub, 1)
            ctx.fillText("toe " + (data.toe >= 0 ? "+" : "") + data.toe.toFixed(2) + "°  camber " + data.camber.toFixed(2) + "°", lx, c[1] + 10)
        }
        if (sim.alignFault) {
            const p = P(-0.8, 1.38)
            const x0 = p[0] - 36, y0 = p[1] + 34
            ctx.beginPath(); ctx.moveTo(x0 - 60, y0); ctx.lineTo(x0, y0); ctx.lineTo(x0 - 9, y0 - 7)
            ctx.moveTo(x0, y0); ctx.lineTo(x0 - 9, y0 + 7)
            glow(ctx, theme.warn, 1, 2.5)
            ctx.textAlign = "right"; ctx.fillStyle = theme.css(theme.warn, 1); ctx.font = "600 12px '" + theme.face + "'"
            ctx.fillText("PULLING RIGHT", x0 - 70, y0 + 4)
        }
        if (obsLabel) {
            ctx.textAlign = "left"
            ctx.font = "600 13px '" + theme.face + "'"
            ctx.fillStyle = theme.css(obsLabel[4] ? theme.danger : theme.warn, 1)
            ctx.fillText(obsLabel[2], obsLabel[0], obsLabel[1] - 4)
            ctx.font = "400 12px '" + theme.face + "'"
            ctx.fillText(obsLabel[3], obsLabel[0], obsLabel[1] + 13)
        }
        ctx.textAlign = "center"
        ctx.font = "600 12px '" + theme.face + "'"
        ctx.fillStyle = theme.css(theme.accent, 0.9)
        ctx.fillText("UNDERBODY VIEW  ·  CLEARANCE " + sim.clearance + " mm nominal → " + Math.round(sim.effClearance) + " mm with " + sim.passengers + " aboard at " + Math.round(sim.speed) + " km/h", cx, 604)
        ctx.restore()
    }
}
