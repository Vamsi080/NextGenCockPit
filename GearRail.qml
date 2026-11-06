import QtQuick

// Gear position indicator (read-only; the gear lever is a vehicle signal).
Item {
    id: rail
    property var sim
    property var theme
    width: 260
    height: 46

    readonly property var gears: ["P", "R", "N", "D"]
    readonly property int idx: gears.indexOf(sim.gear)

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Qt.rgba(1, 1, 1, 0.02)
        border.color: rail.theme.line
        border.width: 1
    }
    Rectangle {
        id: knob
        width: 52; height: 36; radius: 18
        y: 5
        x: 8 + rail.idx * 61
        color: Qt.rgba(rail.theme.accent.r, rail.theme.accent.g, rail.theme.accent.b, 0.18)
        border.color: rail.theme.accent
        border.width: 1.5
        Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutBack } }
    }
    Repeater {
        model: rail.gears
        Text {
            required property string modelData
            required property int index
            x: 8 + index * 61; width: 52; y: 5; height: 36
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: modelData
            font.family: rail.theme.face
            font.pixelSize: rail.sim.gear === modelData ? 22 : 17
            font.weight: rail.sim.gear === modelData ? Font.Bold : Font.Normal
            color: rail.sim.gear === modelData ? rail.theme.text : rail.theme.dim
        }
    }
}
