import QtQuick

// ROAD: weather & surface, monsoon wading check (13), community hazards with
// confidence decay (11), offline road memory (12), underbody strike predictor (5).
Column {
    id: card
    property var sim
    property var theme
    width: 272
    spacing: 8

    Row {
        spacing: 12
        Text { text: card.sim.weather.temp + "°"; font.family: card.theme.face; font.pixelSize: 44; font.weight: Font.Light
               color: card.sim.iceRisk ? card.theme.warn : card.theme.text }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            Text { text: card.sim.weather.name + "  ·  road " + card.sim.weather.road.toLowerCase()
                   font.family: card.theme.face; font.pixelSize: 16; color: card.sim.weather.road === "DRY" ? card.theme.text : card.theme.warn }
            Text { text: "Humidity " + card.sim.weather.hum + " %  ·  visibility " + (card.sim.weather.vis >= 1 ? card.sim.weather.vis + " km" : Math.round(card.sim.weather.vis * 1000) + " m")
                   font.family: card.theme.face; font.pixelSize: 12; color: card.theme.sub }
        }
    }

    // wading check
    Rectangle { width: card.width; height: 1; color: card.theme.line }
    Caption { theme: card.theme; text: "WADING · LIMIT " + card.sim.profile.wading + " mm" }
    Text {
        width: card.width; wrapMode: Text.WordWrap
        text: card.sim.waterActive
              ? "Water " + Math.max(0, Math.round(card.sim.waterDist)) + " m ahead · reported " + card.sim.waterDepth + " mm, 2 h ago · "
                + (card.sim.waterDepth > card.sim.profile.wading ? "TOO DEEP — turn back" : "passable at ≤ 15 km/h")
              : card.sim.weatherIndex === 1 ? "No water reports on route yet" : "Dry route · no water reports"
        font.family: card.theme.face; font.pixelSize: 13
        color: card.sim.waterActive ? (card.sim.waterDepth > card.sim.profile.wading ? card.theme.danger : card.theme.warn) : card.theme.sub
    }

    // community hazards
    Rectangle { width: card.width; height: 1; color: card.theme.line }
    Caption { theme: card.theme; text: "HAZARDS · CONFIDENCE" }
    Repeater {
        model: card.sim.hazards.length
        Item {
            required property int index
            readonly property var h: card.sim.hazards[index]
            readonly property real conf: card.sim.hazardConf(h)
            width: card.width; height: 30
            Text { text: parent.h.type; font.family: card.theme.face; font.pixelSize: 13; color: card.theme.text }
            Text { anchors.right: parent.right
                   text: (parent.h.dist >= 1000 ? (parent.h.dist / 1000).toFixed(1) + " km" : Math.round(parent.h.dist) + " m")
                   font.family: card.theme.face; font.pixelSize: 13; color: card.theme.text }
            Rectangle { y: 19; width: 100; height: 4; radius: 2; color: card.theme.line
                Rectangle { height: 4; radius: 2; width: 100 * parent.parent.conf
                            color: parent.parent.conf > 0.5 ? card.theme.accent : card.theme.dim } }
            Text { x: 108; y: 14; text: parent.h.confirms + " cars · " + Math.round(parent.h.age / 60) + " min ago"
                   font.family: card.theme.face; font.pixelSize: 11; color: card.theme.sub }
        }
    }

    // road memory + strike predictor
    Rectangle { width: card.width; height: 1; color: card.theme.line }
    Caption { theme: card.theme; text: "ROAD MEMORY · UNDERBODY" }
    Text { text: card.sim.memoryEvents + " bumps learned on-device · " + card.sim.memoryToday + " today"
           font.family: card.theme.face; font.pixelSize: 13; color: card.theme.text }
    Text {
        width: card.width; wrapMode: Text.WordWrap
        text: "Next: " + card.sim.obstacle.type.toLowerCase() + " " + Math.abs(card.sim.obstacle.h) + " mm in " + Math.max(0, Math.round(card.sim.obstacleDist)) + " m · "
              + (card.sim.crossSpeed === 0 ? "steer around" : "cross ≤ " + card.sim.crossSpeed + " km/h")
              + " · scrape " + Math.round(card.sim.scrapeProb * 100) + " % (clearance " + Math.round(card.sim.effClearance) + " mm, " + card.sim.passengers + " aboard)"
        font.family: card.theme.face; font.pixelSize: 12
        color: card.sim.scrapeProb > 0.3 ? card.theme.warn : card.theme.sub
    }
}
