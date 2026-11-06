import QtQuick

// Concept 6 — Evidence Card (pops up automatically, read-only): why a warning is on, the signal behind it,
// the threshold it crossed, and one action. Deterministic rule table, no AI.
Rectangle {
    id: ev
    property var sim
    property var theme
    property string sig: "psiFR"
    property string headline: ""
    signal closed()
    width: 760
    height: 330
    radius: 22
    color: Qt.rgba(0.02, 0.03, 0.05, 0.96)
    border.color: theme.accent
    border.width: 1.5

    readonly property var rules: ({
        psiFR:     { label: "FR tyre pressure", unit: "psi", thr: sim.profile.psi - 4, below: true,
                     why: "Pressure is falling at " + sim.leakRate.toFixed(1) + " psi/min, measured over the last 30 s. The warning threshold is target − 4 psi.",
                     act: sim.driveOnKm >= 0 ? "Drive ≤ 60 km/h. Safe for ~" + Math.round(sim.driveOnKm) + " km. Tyre shop " + sim.serviceKm.toFixed(1) + " km ahead." : "Check tyre at next stop." },
        ttc:       { label: "Time to collision", unit: "s", thr: 2.6, below: true,
                     why: "Closing speed on the lead vehicle makes time-to-collision short. The warning is set at 2.6 s and auto-braking at 1.3 s.",
                     act: sim.escapeLane ? "Brake now. A free gap is open on the " + (sim.escapeLane > 0 ? "right." : "left.") : "Brake now and increase the following gap." },
        attention: { label: "Driver attention", unit: "%", thr: 35, below: true,
                     why: "The attention score falls with continuous driving above 30 km/h. Below 35 % a break is advised.",
                     act: "Take a 15-minute break. Rest area in 6 km." },
        motorTemp: { label: "Motor temperature", unit: "°C", thr: 110, below: false,
                     why: "Motor temperature is above the 110 °C derating point.",
                     act: "Power is limited automatically. Ease off until it cools." },
        parkGap:   { label: "Rear clearance", unit: "m", thr: 0.45, below: true,
                     why: "Rear clearance from LiDAR and ultrasonic sensors reached the 0.45 m stop margin, or a pedestrian entered the path.",
                     act: "The vehicle is held. Check behind before moving." },
        battery:   { label: "State of charge", unit: "%", thr: 15, below: true,
                     why: "State of charge is below 15 %.",
                     act: "Charge soon. Nearest charger 4.1 km." },
        trustCam:  { label: "Camera confidence", unit: "%", thr: 35, below: true,
                     why: "Camera confidence comes from lane-detection quality and agreement with radar and LiDAR. Lane centering needs more than 35 %.",
                     act: "Keep hands on the wheel. Clean the windscreen camera area if it is blocked." },
        glance:    { label: "Eyes off road", unit: "s", thr: 2.0, below: false,
                     why: "Rolling eyes-off-road time from the driver camera is above 2 s.",
                     act: "Non-essential info is hidden until your eyes return to the road." },
        temp:      { label: "Outside temperature", unit: "°C", thr: 3, below: true,
                     why: "At 3 °C or below, black ice is possible on bridges and in shade.",
                     act: "Gentle inputs. Traction control is set to winter mode." }
    })
    readonly property var r: rules[sig] || rules.psiFR
    readonly property var series: sim.hist[sig] || []

    Column {
        x: 32; y: 26; width: parent.width - 64
        spacing: 10
        Row {
            spacing: 12
            Caption { theme: ev.theme; text: "EVIDENCE CARD"; color: ev.theme.accent }
            Caption { theme: ev.theme; text: "· WHY THIS WARNING · LAST " + ev.series.length + " s" }
        }
        Text {
            width: parent.width
            text: ev.headline !== "" ? ev.headline : ev.r.label
            font.family: ev.theme.face; font.pixelSize: 21; color: ev.theme.text; elide: Text.ElideRight
        }
        Row {
            spacing: 22
            Item {
                width: 430; height: 150
                Sparkline {
                    anchors.fill: parent
                    values: ev.series
                    threshold: ev.r.thr
                    thresholdBelow: ev.r.below
                    color: ev.theme.accent
                    warnColor: ev.theme.warn
                    gridColor: ev.theme.line
                }
            }
            Column {
                width: 230; spacing: 6
                Caption { theme: ev.theme; text: ev.r.label.toUpperCase() }
                Text {
                    text: ev.series.length ? ev.series[ev.series.length - 1].toFixed(1) + " " + ev.r.unit : "—"
                    font.family: ev.theme.face; font.pixelSize: 34; font.weight: Font.Light; color: ev.theme.text
                }
                Text { text: "threshold " + (ev.r.below ? "< " : "> ") + ev.r.thr.toFixed(1) + " " + ev.r.unit
                       font.family: ev.theme.face; font.pixelSize: 14; color: ev.theme.warn }
                Text { text: "Rule-based · deterministic · no AI"; font.family: ev.theme.face; font.pixelSize: 12; color: ev.theme.sub }
            }
        }
        Text { width: parent.width; wrapMode: Text.WordWrap; text: "Why: " + ev.r.why
               font.family: ev.theme.face; font.pixelSize: 14; color: ev.theme.sub }
        Text { width: parent.width; wrapMode: Text.WordWrap; text: "Do: " + ev.r.act
               font.family: ev.theme.face; font.pixelSize: 15; font.weight: Font.DemiBold; color: ev.theme.text }
    }
}
