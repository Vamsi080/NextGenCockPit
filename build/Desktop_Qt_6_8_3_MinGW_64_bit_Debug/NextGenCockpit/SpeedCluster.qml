import QtQuick

// Speed core: light numerals, ACC set speed, speed-limit sign, linear ribbon.
Item {
    id: sc
    property var sim
    property var theme
    width: 680
    height: 230

    readonly property bool speeding: sim.speed > sim.speedLimit + 3 && sim.gear === "D"
    readonly property bool driving: sim.gear === "D" || sim.gear === "N"

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        text: Math.round(sc.sim.speed)
        font.family: sc.theme.face
        font.pixelSize: 150
        font.weight: Font.Light
        font.letterSpacing: -4
        color: sc.speeding ? sc.theme.warn : sc.theme.text
        Behavior on color { ColorAnimation { duration: 300 } }
    }
    Caption {
        theme: sc.theme
        anchors.horizontalCenter: parent.horizontalCenter
        y: 182
        text: "KM/H  ·  " + (sc.sim.gear === "R" ? "REVERSE" : sc.sim.gear === "P" ? "PARK" : sc.sim.gear === "N" ? "NEUTRAL" : sc.theme.modeTitle)
    }

    Column {
        x: sc.width / 2 - 250; y: 66
        spacing: 2
        opacity: sc.driving ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 400 } }
        Caption { theme: sc.theme; text: sc.sim.autoDrive ? "ACC SET" : "ACC OFF"; color: sc.sim.autoDrive ? sc.theme.accent : sc.theme.dim }
        Text { text: Math.round(sc.sim.setSpeed); font.family: sc.theme.face; font.pixelSize: 30; font.weight: Font.Light
               color: sc.sim.autoDrive ? sc.theme.text : sc.theme.dim }
    }

    Item {
        x: sc.width / 2 + 190; y: 62
        width: 58; height: 58
        opacity: sc.driving ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 400 } }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: 4
            border.color: sc.theme.danger
            SequentialAnimation on scale {
                running: sc.speeding
                loops: Animation.Infinite
                alwaysRunToEnd: true
                NumberAnimation { to: 1.12; duration: 380; easing.type: Easing.OutQuad }
                NumberAnimation { to: 1.0; duration: 380; easing.type: Easing.InQuad }
            }
        }
        Text { anchors.centerIn: parent; text: sc.sim.speedLimit; font.family: sc.theme.face; font.pixelSize: 22; font.weight: Font.DemiBold; color: sc.theme.text }
    }

    Item {
        id: ribbon
        anchors.horizontalCenter: parent.horizontalCenter
        y: 208
        width: 520; height: 18
        readonly property real maxV: 220
        Rectangle { y: 7; width: parent.width; height: 2; color: sc.theme.line }
        Rectangle {
            y: 6; height: 4; radius: 2
            width: parent.width * Math.min(1, sc.sim.speed / ribbon.maxV)
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.6; color: sc.theme.accent2 }
                GradientStop { position: 1; color: sc.theme.accent }
            }
        }
        Rectangle {
            x: parent.width * Math.min(1, sc.sim.speed / ribbon.maxV) - 5
            y: 3; width: 10; height: 10; radius: 5
            color: sc.theme.text; border.color: sc.theme.accent; border.width: 2
        }
        Repeater {
            model: 12
            Rectangle {
                required property int index
                x: ribbon.width * index / 11
                y: index % 2 === 0 ? 12 : 13
                width: 1; height: index % 2 === 0 ? 6 : 4
                color: sc.theme.dim
            }
        }
        Rectangle {
            x: ribbon.width * sc.sim.speedLimit / ribbon.maxV - 1
            y: -2; width: 2; height: 10
            color: sc.theme.danger
            opacity: sc.driving ? 0.9 : 0
        }
    }
}
