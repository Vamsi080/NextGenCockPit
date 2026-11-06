import QtQuick

// CLIMATE: outside weather + road surface, cabin, powertrain temperatures.
Column {
    id: card
    property var sim
    property var theme
    width: 300
    spacing: 8

    readonly property var w: sim.weather

    Row {
        anchors.right: parent.right
        spacing: 14
        Column {
            anchors.verticalCenter: parent.verticalCenter
            Text { anchors.right: parent.right; text: card.w.name; font.family: card.theme.face; font.pixelSize: 22; color: card.theme.text }
            Caption { anchors.right: parent.right; theme: card.theme; text: "OUTSIDE" }
        }
        Text { text: card.w.temp + "°"; font.family: card.theme.face; font.pixelSize: 60; font.weight: Font.Light
               color: card.sim.iceRisk ? card.theme.warn : card.theme.text }
    }
    Grid {
        anchors.right: parent.right
        columns: 3; columnSpacing: 22; rowSpacing: 4
        Repeater {
            model: [
                { k: "HUMIDITY",   v: card.w.hum + " %" },
                { k: "VISIBILITY", v: card.w.vis >= 1 ? card.w.vis + " km" : Math.round(card.w.vis * 1000) + " m" },
                { k: "ROAD",       v: card.w.road }
            ]
            Column {
                required property var modelData
                Caption { theme: card.theme; text: parent.modelData.k; font.pixelSize: 9; font.letterSpacing: 2 }
                Text { text: parent.modelData.v; font.family: card.theme.face; font.pixelSize: 15
                       color: parent.modelData.k === "ROAD" && parent.modelData.v !== "DRY" ? card.theme.warn : card.theme.text }
            }
        }
    }
    Text {
        anchors.right: parent.right
        text: card.sim.wipers ? "Auto wipers ON · gap +40%" : card.sim.fogLamps ? "Fog lamps ON · speed capped 50" : card.sim.iceRisk ? "Traction mode: winter" : "Auto lights " + (card.sim.lowBeam ? "ON" : "standby")
        font.family: card.theme.face; font.pixelSize: 13; color: card.theme.accent
    }

    Rectangle { width: card.width; height: 1; color: card.theme.line }
    Caption { anchors.right: parent.right; theme: card.theme; text: "CABIN" }
    Row {
        anchors.right: parent.right
        spacing: 10
        Text { text: "Set " + card.sim.cabinSet.toFixed(1) + "°"; font.family: card.theme.face; font.pixelSize: 18; color: card.theme.text }
        Text { text: "·  now " + card.sim.cabinTemp.toFixed(1) + "°  ·  AQI 32"; font.family: card.theme.face; font.pixelSize: 15; color: card.theme.sub
               anchors.baseline: parent.children[0].baseline }
    }

    Rectangle { width: card.width; height: 1; color: card.theme.line }
    Caption { anchors.right: parent.right; theme: card.theme; text: "POWERTRAIN TEMPERATURES" }
    Repeater {
        model: [
            { k: "Battery",  v: card.sim.batteryTemp,  max: 60 },
            { k: "Motor",    v: card.sim.motorTemp,    max: 140 },
            { k: "Inverter", v: card.sim.inverterTemp, max: 120 }
        ]
        Item {
            required property var modelData
            width: card.width; height: 20
            readonly property real f: Math.min(1, modelData.v / modelData.max)
            Text { text: parent.modelData.k; font.family: card.theme.face; font.pixelSize: 13; color: card.theme.sub }
            Rectangle {
                x: 80; y: 8; width: 160; height: 4; radius: 2; color: card.theme.line
                Rectangle { height: 4; radius: 2; width: 160 * parent.parent.f
                            color: parent.parent.f > 0.8 ? card.theme.danger : parent.parent.f > 0.6 ? card.theme.warn : card.theme.accent2 }
            }
            Text { anchors.right: parent.right; text: Math.round(parent.modelData.v) + "°C"; font.family: card.theme.face; font.pixelSize: 13; color: card.theme.text }
        }
    }
}
