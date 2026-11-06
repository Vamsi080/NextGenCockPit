import QtQuick

// Labelled push / toggle / hold button used in the Control Deck.
Rectangle {
    id: b
    property var theme
    property string label: ""
    property string hint: ""               // keyboard shortcut
    property bool active: false
    property bool hold: false               // true = acts while pressed (accelerate / brake)
    property color activeColor: theme.accent
    signal clicked()
    signal pressedChanged2(bool down)
    implicitWidth: Math.max(78, lbl.implicitWidth + 26)
    height: 40
    radius: 10
    color: active ? Qt.rgba(activeColor.r, activeColor.g, activeColor.b, 0.22)
                  : ma.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.025)
    border.width: 1.2
    border.color: active ? activeColor : ma.containsMouse ? theme.sub : theme.line
    scale: ma.pressed ? 0.96 : 1
    Behavior on scale { NumberAnimation { duration: 80 } }

    Text {
        id: lbl
        anchors.centerIn: parent
        anchors.verticalCenterOffset: b.hint !== "" ? -6 : 0
        text: b.label
        font.family: b.theme.face; font.pixelSize: 13; font.weight: Font.DemiBold
        color: b.active ? b.theme.text : "#D4DEE7"
    }
    Text {
        visible: b.hint !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: lbl.bottom; anchors.topMargin: 1
        text: b.hint
        font.family: b.theme.face; font.pixelSize: 10; font.letterSpacing: 1
        color: b.theme.sub
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (!b.hold) b.clicked()
        onPressed: if (b.hold) b.pressedChanged2(true)
        onReleased: if (b.hold) b.pressedChanged2(false)
        onCanceled: if (b.hold) b.pressedChanged2(false)
    }
}
