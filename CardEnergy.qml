import QtQuick

// ENERGY: trip energy receipt with what-if (15), battery pack heat-map (9),
// powertrain and cabin temperatures.
Column {
    id: card
    property var sim
    property var theme
    width: 272
    spacing: 7

    readonly property var parts: [
        { k: "Aero drag",  v: sim.eAero },
        { k: "Rolling",    v: sim.eRolling },
        { k: "Climbs",     v: sim.eClimb },
        { k: "Accelerate", v: sim.eAccel },
        { k: "HVAC",       v: sim.eHvac },
        { k: "Regen back", v: -sim.eRegen }
    ]
    readonly property real maxPart: Math.max(sim.eAero, sim.eRolling, sim.eClimb, sim.eAccel, sim.eHvac, sim.eRegen)

    Caption { theme: card.theme; anchors.right: parent.right
              text: "ENERGY RECEIPT  ·  " + card.sim.tripKm.toFixed(1) + " km TRIP" }
    Repeater {
        model: 6
        Item {
            required property int index
            readonly property var modelData: card.parts[index]
            width: card.width; height: 18
            Text { text: parent.modelData.k; font.family: card.theme.face; font.pixelSize: 12; color: card.theme.sub }
            Rectangle {
                x: 78; y: 6; height: 6; radius: 3
                width: 118 * Math.abs(parent.modelData.v) / Math.max(0.01, card.maxPart)
                color: parent.modelData.v < 0 ? card.theme.good : card.theme.accent
            }
            Text { anchors.right: parent.right; text: (parent.modelData.v < 0 ? "−" : "") + Math.abs(parent.modelData.v).toFixed(2) + " kWh"
                   font.family: card.theme.face; font.pixelSize: 12; color: card.theme.text }
        }
    }
    Text {
        width: card.width; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignRight
        text: "What if: capped at 80 km/h you would have saved " + card.sim.eSaving80.toFixed(2) + " kWh (≈ ₹" + (card.sim.eSaving80 * 9).toFixed(0) + ")"
        font.family: card.theme.face; font.pixelSize: 12; color: card.theme.accent
    }

    Rectangle { width: card.width; height: 1; color: card.theme.line }
    Caption { theme: card.theme; anchors.right: parent.right; text: "BATTERY PACK  ·  12 MODULES" }
    Grid {
        columns: 6; spacing: 4
        Repeater {
            model: 12
            Rectangle {
                required property int index
                readonly property var modelData: card.sim.modules[index]
                width: 41; height: 34; radius: 5
                readonly property real d: modelData.t - card.sim.batteryTemp
                color: modelData.weak ? Qt.rgba(card.theme.danger.r, card.theme.danger.g, card.theme.danger.b, 0.35)
                                      : Qt.rgba(card.theme.accent.r, card.theme.accent.g, card.theme.accent.b, 0.10 + Math.max(0, d) * 0.12)
                border.color: modelData.weak ? card.theme.danger : card.theme.line
                Column {
                    anchors.centerIn: parent
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: parent.parent.modelData.t.toFixed(1) + "°"
                           font.family: card.theme.face; font.pixelSize: 11; color: card.theme.text }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: (parent.parent.modelData.mv / 1000).toFixed(3) + "V"
                           font.family: card.theme.face; font.pixelSize: 9; color: card.theme.sub }
                }
            }
        }
    }
    Text {
        anchors.right: parent.right
        text: card.sim.weakModule ? "Module 8 drifting: +6.5 °C, −42 mV · service check" : "Cell spread 12 mV · balanced"
        font.family: card.theme.face; font.pixelSize: 12; color: card.sim.weakModule ? card.theme.danger : card.theme.sub
    }

    Rectangle { width: card.width; height: 1; color: card.theme.line }
    Text {
        anchors.right: parent.right
        text: "Motor " + Math.round(card.sim.motorTemp) + "°  ·  Inverter " + Math.round(card.sim.inverterTemp) + "°  ·  Cabin " + card.sim.cabinTemp.toFixed(1) + "° (set " + card.sim.cabinSet + "°)"
        font.family: card.theme.face; font.pixelSize: 12; color: card.theme.sub
    }
}
