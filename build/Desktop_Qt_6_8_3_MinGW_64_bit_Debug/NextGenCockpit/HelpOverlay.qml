import QtQuick

// Controls reference. Opens on first launch, toggled with F1 or the "?" chip.
Rectangle {
    id: help
    property var theme
    color: Qt.rgba(0.01, 0.02, 0.04, 0.88)
    radius: 24
    border.color: theme.accent
    border.width: 1
    width: 980
    height: 560

    readonly property var groups: [
        { t: "DRIVING", rows: [
            ["↑  /  ↓", "Accelerate / brake (manual)"],
            ["A", "Adaptive cruise on / off"],
            ["←  /  →", "Indicator · hold to change lane"],
            ["P  R  N  D", "Select gear (interlocked)"],
            ["1  2  3", "ECO · COMFORT · SPORT"],
            ["Z", "Hazard lights"],
            ["H", "High beam"] ] },
        { t: "VIEWS & CARDS", rows: [
            ["V", "Front · Rear cam · 360° · Underbody"],
            ["Q", "Left cards: Drive · Safety · Sensors"],
            ["E", "Right cards: Nav · Vehicle · Climate"],
            ["G", "Next vehicle profile"],
            ["C", "Linked co-pilot display"],
            ["M", "Next track"],
            ["F  /  F1", "Fullscreen / this help"],
            ["Tab", "Show / hide Control Deck"],
            ["I  /  click", "Evidence Card for an alert"] ] },
        { t: "SAFETY DEMOS", rows: [
            ["X", "Weather: clear · rain · fog · cold"],
            ["B", "Passenger seatbelt"],
            ["O", "Rear-left door"],
            ["T", "Slow tyre leak (FR)"],
            ["W", "Wheel alignment fault (FL)"],
            ["U", "Rock ahead (underbody risk)"],
            ["K", "Driver drowsiness"],
            ["J", "Camera blocked (takeover)"],
            ["Y", "Weak battery module"],
            ["L", "Eyes off road (glance budget)"] ] }
    ]

    Text {
        x: 40; y: 30
        text: "NextGenQT Cluster  ·  Controls"
        font.family: help.theme.face; font.pixelSize: 24; font.weight: Font.Light; color: help.theme.text
    }
    Caption { x: 40; y: 66; theme: help.theme; text: "EVERYTHING IS ALSO CLICKABLE · PRESS F1 TO CLOSE" }

    Row {
        x: 40; y: 110
        spacing: 40
        Repeater {
            model: help.groups
            Column {
                required property var modelData
                width: 280
                spacing: 12
                Caption { theme: help.theme; text: parent.modelData.t; color: help.theme.accent }
                Repeater {
                    model: parent.modelData.rows
                    Row {
                        required property var modelData
                        spacing: 12
                        Text { width: 86; text: parent.modelData[0]; font.family: help.theme.face; font.pixelSize: 14; font.bold: true; color: help.theme.text }
                        Text { width: 184; text: parent.modelData[1]; font.family: help.theme.face; font.pixelSize: 14; color: help.theme.sub; wrapMode: Text.WordWrap }
                    }
                }
            }
        }
    }
}
