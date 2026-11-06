import QtQuick

// Read-only segmented indicator with a sliding light bar (shows the current
// drive mode / camera view as reported by the vehicle).
Item {
    id: dock
    property var theme
    property var model: []
    property string current: ""
    property string title: ""
    signal picked(string key)
    width: Math.max(row.width, cap.implicitWidth)
    height: 52

    Caption { id: cap; theme: dock.theme; text: dock.title; font.pixelSize: 11; color: dock.theme.sub }

    Row {
        id: row
        y: 18
        spacing: 26
        Repeater {
            id: rep
            model: dock.model
            Text {
                required property var modelData
                readonly property bool active: dock.current === modelData.key
                text: modelData.label
                font.family: dock.theme.face
                font.pixelSize: 13
                font.weight: active ? Font.Bold : Font.Normal
                font.letterSpacing: 3
                color: active ? dock.theme.text : dock.theme.dim
                Behavior on color { ColorAnimation { duration: 300 } }
            }
        }
    }
    Rectangle {
        id: bar
        readonly property Item target: {
            const c = dock.current
            for (let i = 0; i < rep.count; i++) {
                const it = rep.itemAt(i)
                if (it && it.modelData.key === c) return it
            }
            return null
        }
        y: row.y + 24
        height: 3; radius: 1.5
        x: target ? target.x - 4 : 0
        width: target ? target.width + 3 : 0
        color: dock.theme.accent
        Behavior on x { NumberAnimation { duration: 420; easing.type: Easing.OutBack } }
        Behavior on width { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
    }
}
