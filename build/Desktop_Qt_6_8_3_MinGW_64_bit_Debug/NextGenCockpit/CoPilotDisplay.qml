import QtQuick
import QtQuick.Window

// Second, linked display (passenger / centre screen). Anything changed here
// is reflected on the cluster instantly — and vice versa — because both
// windows bind to the same VehicleSim + Theme objects.
Window {
    id: cp
    property var sim
    property var theme
    width: 1280
    height: 480
    color: theme.bg
    title: "NextGenQT Cluster — Co-Pilot Display"

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(cp.theme.accent.r, cp.theme.accent.g, cp.theme.accent.b, 0.10) }
            GradientStop { position: 1; color: "transparent" }
        }
    }

    // header
    Row {
        x: 48; y: 32; spacing: 12
        Rectangle {
            width: 10; height: 10; radius: 5
            anchors.verticalCenter: parent.verticalCenter
            color: cp.theme.accent
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { to: 0.25; duration: 700 }
                NumberAnimation { to: 1; duration: 700 }
            }
        }
        Caption { theme: cp.theme; text: "LINKED TO CLUSTER  ·  " + cp.theme.modeTitle; color: cp.theme.text }
    }
    Text {
        anchors.right: parent.right; anchors.rightMargin: 48; y: 26
        text: Math.round(cp.sim.speed) + " km/h   ·   " + Math.floor(cp.sim.battery) + "%   ·   "
              + Qt.formatTime(cp.sim.now, "hh:mm")
        font.family: cp.theme.face; font.pixelSize: 18; color: cp.theme.sub
    }

    // media (left)
    Column {
        x: 48; y: 110; width: 560; spacing: 6
        Caption { theme: cp.theme; text: cp.sim.playing ? "NOW PLAYING" : "PAUSED" }
        Text { text: cp.sim.track.title; font.family: cp.theme.face; font.pixelSize: 46; font.weight: Font.Light; color: cp.theme.text }
        Text { text: cp.sim.track.artist; font.family: cp.theme.face; font.pixelSize: 20; color: cp.theme.accent }
        Item { width: 1; height: 18 }
        Rectangle {
            width: 520; height: 3; radius: 1.5; color: cp.theme.line
            Rectangle { height: 3; radius: 1.5; color: cp.theme.accent; width: parent.width * cp.sim.trackPos / cp.sim.track.dur }
        }
        Item { width: 1; height: 26 }
        Row {
            spacing: 18
            Repeater {
                model: [ { t: "PREV", f: "prev" }, { t: cp.sim.playing ? "PAUSE" : "PLAY", f: "play" }, { t: "NEXT", f: "next" } ]
                Rectangle {
                    required property var modelData
                    width: 128; height: 52; radius: 26
                    color: ma.containsMouse ? Qt.rgba(cp.theme.accent.r, cp.theme.accent.g, cp.theme.accent.b, 0.15) : "transparent"
                    border.color: modelData.f === "play" ? cp.theme.accent : cp.theme.dim
                    border.width: 1.5
                    Text { anchors.centerIn: parent; text: parent.modelData.t; font.family: cp.theme.face; font.pixelSize: 13; font.letterSpacing: 3; color: cp.theme.text }
                    MouseArea {
                        id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (parent.modelData.f === "prev") cp.sim.prevTrack()
                            else if (parent.modelData.f === "next") cp.sim.nextTrack()
                            else cp.sim.playing = !cp.sim.playing
                        }
                    }
                }
            }
        }
    }

    // controls (right)
    Column {
        x: 680; y: 100; spacing: 12
        Caption { theme: cp.theme; text: "DRIVE EXPERIENCE" }
        Row {
            spacing: 14
            Repeater {
                model: [ { k: "eco", t: "ECO", d: "Max range · mint light" },
                         { k: "comfort", t: "COMFORT", d: "Balanced · azure light" },
                         { k: "sport", t: "SPORT", d: "Full power · ember light" } ]
                Rectangle {
                    required property var modelData
                    readonly property bool active: cp.sim.mode === modelData.k
                    width: 176; height: 96; radius: 18
                    color: active ? Qt.rgba(cp.theme.accent.r, cp.theme.accent.g, cp.theme.accent.b, 0.14) : "transparent"
                    border.color: active ? cp.theme.accent : cp.theme.line
                    border.width: 1.5
                    Column {
                        x: 16; y: 16; spacing: 6; width: parent.width - 32
                        Text { text: parent.parent.modelData.t; font.family: cp.theme.face; font.pixelSize: 19; font.letterSpacing: 3
                               font.weight: Font.DemiBold; color: parent.parent.active ? cp.theme.text : cp.theme.sub }
                        Text { text: parent.parent.modelData.d; wrapMode: Text.WordWrap; width: parent.width
                               font.family: cp.theme.face; font.pixelSize: 12; color: cp.theme.sub }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: cp.sim.mode = parent.modelData.k }
                }
            }
        }
        Caption { theme: cp.theme; text: "CLUSTER VIEW  ·  GEAR" }
        Row {
            spacing: 10
            Repeater {
                model: [ { k: "front", t: "FRONT" }, { k: "rear", t: "REAR CAM" }, { k: "top", t: "360°" }, { k: "under", t: "UNDERBODY" } ]
                Rectangle {
                    required property var modelData
                    readonly property bool active: cp.sim.view === modelData.k
                    width: 92; height: 40; radius: 20
                    color: active ? Qt.rgba(cp.theme.accent.r, cp.theme.accent.g, cp.theme.accent.b, 0.16) : "transparent"
                    border.color: active ? cp.theme.accent : cp.theme.line; border.width: 1.5
                    Text { anchors.centerIn: parent; text: parent.modelData.t; font.family: cp.theme.face; font.pixelSize: 11; font.letterSpacing: 2; color: cp.theme.text }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: cp.sim.view = parent.modelData.k }
                }
            }
            Item { width: 8; height: 1 }
            Repeater {
                model: ["P", "R", "N", "D"]
                Rectangle {
                    required property string modelData
                    width: 40; height: 40; radius: 20
                    color: cp.sim.gear === modelData ? cp.theme.accent : "transparent"
                    border.color: cp.sim.gear === modelData ? cp.theme.accent : cp.theme.line; border.width: 1.5
                    Text { anchors.centerIn: parent; text: parent.modelData; font.pixelSize: 15; font.bold: true
                           color: cp.sim.gear === parent.modelData ? "#03050A" : cp.theme.text }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: cp.sim.requestGear(parent.modelData) }
                }
            }
        }
        Caption { theme: cp.theme; text: "VEHICLE PROFILE" }
        Row {
            spacing: 12
            Rectangle {
                width: 40; height: 40; radius: 20; color: "transparent"; border.color: cp.theme.line; border.width: 1.5
                Text { anchors.centerIn: parent; text: "‹"; font.pixelSize: 22; color: cp.theme.text }
                MouseArea { anchors.fill: parent; onClicked: cp.sim.prevProfile(); cursorShape: Qt.PointingHandCursor }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: 300
                Text { text: cp.sim.profile.name + "  ·  " + cp.sim.profile.body; font.family: cp.theme.face; font.pixelSize: 17; color: cp.theme.text }
                Text { text: cp.sim.profile.batt + " kWh · " + cp.sim.profile.power + " kW · " + cp.sim.profile.range + " km · "
                             + cp.sim.profile.clearance + " mm"
                       font.family: cp.theme.face; font.pixelSize: 12; color: cp.theme.sub }
            }
            Rectangle {
                width: 40; height: 40; radius: 20; color: "transparent"; border.color: cp.theme.line; border.width: 1.5
                Text { anchors.centerIn: parent; text: "›"; font.pixelSize: 22; color: cp.theme.text }
                MouseArea { anchors.fill: parent; onClicked: cp.sim.nextProfile(); cursorShape: Qt.PointingHandCursor }
            }
        }
        Text {
            text: cp.sim.alerts.length ? "⚠  " + cp.sim.alerts[0].text : "All systems normal"
            font.family: cp.theme.face; font.pixelSize: 15
            color: cp.sim.alerts.length ? cp.theme.levelColor(cp.sim.alerts[0].level) : cp.theme.good
        }
    }
}
