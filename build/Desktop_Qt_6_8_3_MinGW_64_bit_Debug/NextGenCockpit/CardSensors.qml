import QtQuick

// SENSORS: health, range and notes for every perception sensor.
Column {
    id: card
    property var sim
    property var theme
    width: 272
    spacing: 9

    Repeater {
        model: card.sim.sensors.length
        Column {
            required property int index
            readonly property var s: card.sim.sensors[index]
            readonly property color c: s.health > 0.9 ? card.theme.good : s.health > 0.6 ? card.theme.warn : card.theme.danger
            width: card.width
            spacing: 3
            Item {
                width: parent.width; height: 18
                Text { text: parent.parent.s.name; font.family: card.theme.face; font.pixelSize: 14; color: card.theme.text }
                Text { anchors.right: parent.right; text: parent.parent.s.range; font.family: card.theme.face; font.pixelSize: 13; color: card.theme.sub }
            }
            Item {
                width: parent.width; height: 14
                Rectangle { y: 5; width: 90; height: 4; radius: 2; color: card.theme.line
                    Rectangle { height: 4; radius: 2; width: 90 * parent.parent.parent.s.health; color: parent.parent.parent.c } }
                Text { x: 100; text: parent.parent.s.note; font.family: card.theme.face; font.pixelSize: 12; color: parent.parent.c }
            }
        }
    }
}
