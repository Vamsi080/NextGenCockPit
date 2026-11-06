import QtQuick

// Clickable tab header for a card deck.
Row {
    id: tabs
    property var theme
    property var titles: []
    property int index: 0
    property bool alignRight: false
    signal picked(int i)
    spacing: 18
    layoutDirection: alignRight ? Qt.RightToLeft : Qt.LeftToRight

    Repeater {
        model: tabs.titles
        Column {
            required property string modelData
            required property int index
            spacing: 5
            Caption {
                theme: tabs.theme
                text: parent.modelData
                font.pixelSize: 11
                color: tabs.index === parent.index ? tabs.theme.text : tabs.theme.dim
            }
            Rectangle {
                width: parent.width - 3; height: 2; radius: 1
                color: tabs.index === parent.index ? tabs.theme.accent : tabs.theme.line
            }
        }
    }
}
