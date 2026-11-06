import QtQuick

// SAFETY: live status of every assistance system + occupants & doors.
Column {
    id: card
    property var sim
    property var theme
    width: 272
    spacing: 9

    readonly property var rows: [
        { n: "Forward collision", s: sim.aeb ? "BRAKING" : sim.fcw ? "WARNING" : "Ready",          l: sim.aeb || sim.fcw ? 3 : 0 },
        { n: "Blind spot  L / R", s: (sim.bsLeft ? "● " : "○ ") + (sim.bsRight ? "●" : "○"),      l: sim.bsLeft || sim.bsRight ? 2 : 0 },
        { n: "Lane keep assist",  s: sim.gear === "D" && sim.speed > 50 ? "Active" : "Standby",   l: 0 },
        { n: "Rear auto-brake",   s: sim.rearAeb ? "BRAKING" : sim.gear === "R" ? "Armed" : "Standby", l: sim.rearAeb ? 3 : 0 },
        { n: "Cross traffic",     s: sim.rcta ? "DETECTED" : "Clear",                              l: sim.rcta ? 2 : 0 },
        { n: "Underbody scan",    s: sim.underbodyRisk ? "RISK" : "Clear",                         l: sim.underbodyRisk ? 2 : 0 },
        { n: "Traction / ABS",    s: sim.espActive ? "ESP ACTIVE" : sim.absActive ? "ABS ACTIVE" : "Ready", l: sim.espActive || sim.absActive ? 2 : 0 }
    ]

    Repeater {
        model: card.rows.length
        Item {
            required property int index
            readonly property var r: card.rows[index]
            width: card.width; height: 20
            Text { text: parent.r.n; font.family: card.theme.face; font.pixelSize: 14; color: card.theme.sub }
            Text {
                anchors.right: parent.right
                text: parent.r.s
                font.family: card.theme.face; font.pixelSize: 14; font.weight: parent.r.l ? Font.Bold : Font.Normal
                color: parent.r.l ? card.theme.levelColor(parent.r.l) : card.theme.good
            }
        }
    }

    Item { width: 1; height: 2 }
    Caption { theme: card.theme; text: "DRIVER ATTENTION" }
    Item {
        width: card.width; height: 10
        Rectangle { anchors.fill: parent; radius: 5; color: card.theme.line }
        Rectangle {
            height: parent.height; radius: 5
            width: parent.width * card.sim.attention / 100
            color: card.sim.attention < 35 ? card.theme.warn : card.theme.good
        }
    }

    Item { width: 1; height: 4 }
    Caption { theme: card.theme; text: "OCCUPANTS · BELTS · DOORS" }
    // mini cabin map
    Item {
        width: card.width; height: 96
        Rectangle {
            id: cabin
            x: 0; width: 120; height: 92; radius: 22
            color: "transparent"; border.color: card.theme.dim; border.width: 1.5
            Grid {
                anchors.centerIn: parent
                columns: 2; spacing: 10
                Repeater {
                    model: [
                        { n: "D",  ok: card.sim.driverBelted, door: false },
                        { n: "P",  ok: card.sim.passengerBelted, door: false },
                        { n: "RL", ok: true, door: card.sim.doorOpenRL },
                        { n: "RR", ok: true, door: false }
                    ]
                    Rectangle {
                        required property var modelData
                        width: 40; height: 30; radius: 7
                        color: "transparent"
                        border.width: 1.5
                        border.color: modelData.door ? card.theme.danger : modelData.ok ? card.theme.good : card.theme.danger
                        Text { anchors.centerIn: parent; text: parent.modelData.n; font.family: card.theme.face; font.pixelSize: 12; color: card.theme.text }
                    }
                }
            }
        }
        Column {
            x: 140; y: 6; spacing: 6
            Text { text: card.sim.passengerBelted ? "All belts fastened" : "Passenger unbelted"
                   font.family: card.theme.face; font.pixelSize: 14; color: card.sim.passengerBelted ? card.theme.good : card.theme.danger }
            Text { text: card.sim.doorOpenRL ? "Rear-left door open" : "All doors closed"
                   font.family: card.theme.face; font.pixelSize: 14; color: card.sim.doorOpenRL ? card.theme.danger : card.theme.good }
            Text { text: "Child lock  ·  ON"; font.family: card.theme.face; font.pixelSize: 14; color: card.theme.sub }
        }
    }
}
