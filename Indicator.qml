import QtQuick

// Turn indicator chevron triplet that "flows" outward when active.
Item {
    id: ind
    property int side: -1          // -1 left, 1 right
    property bool active: false
    property bool on: false
    property color color: "#3DFFA2"
    property color offColor: "#18222D"
    width: 64; height: 30

    Row {
        anchors.centerIn: parent
        spacing: -4
        layoutDirection: ind.side < 0 ? Qt.RightToLeft : Qt.LeftToRight
        Repeater {
            model: 3
            Canvas {
                required property int index
                width: 24; height: 30
                property color c: ind.active && ind.on ? ind.color : ind.offColor
                opacity: ind.active && ind.on ? 1 - index * 0.28 : 1
                onCChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d"); ctx.reset()
                    ctx.strokeStyle = c; ctx.lineWidth = 4; ctx.lineCap = "round"; ctx.lineJoin = "round"
                    if (ind.side < 0) { ctx.translate(width, 0); ctx.scale(-1, 1) }
                    ctx.beginPath(); ctx.moveTo(7, 5); ctx.lineTo(17, 15); ctx.lineTo(7, 25); ctx.stroke()
                }
            }
        }
    }
}
