import QtQuick

// Highest-priority active alert, with a counter for the rest.
Item {
    id: ban
    property var sim
    property var theme
    readonly property var cur: sim.alerts.length ? sim.alerts[0] : null
    readonly property color col: cur ? theme.levelColor(cur.level) : theme.accent
    width: pill.width
    height: 38
    opacity: cur ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity { NumberAnimation { duration: 250 } }

    Rectangle {
        id: pill
        height: 38
        width: row.width + 40
        radius: 19
        color: Qt.rgba(ban.col.r * 0.18, ban.col.g * 0.18, ban.col.b * 0.18, 0.92)
        border.color: ban.col
        border.width: 1.5
        SequentialAnimation on border.width {
            running: ban.cur && ban.cur.level >= 3
            loops: Animation.Infinite
            alwaysRunToEnd: true
            NumberAnimation { to: 3.5; duration: 250 }
            NumberAnimation { to: 1.5; duration: 250 }
        }
        Row {
            id: row
            anchors.centerIn: parent
            spacing: 12
            Rectangle {
                width: 20; height: 20; radius: 10
                anchors.verticalCenter: parent.verticalCenter
                color: ban.col
                Text { anchors.centerIn: parent; text: "!"; font.pixelSize: 14; font.bold: true; color: "#03050A" }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ban.cur ? ban.cur.text : ""
                font.family: ban.theme.face; font.pixelSize: 15; font.weight: Font.DemiBold; font.letterSpacing: 1.5
                color: ban.theme.text
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: ban.sim.alerts.length > 1
                text: "+" + (ban.sim.alerts.length - 1)
                font.family: ban.theme.face; font.pixelSize: 13
                color: ban.theme.sub
            }
        }
    }
}
