import QtQuick

// NAV · MEDIA: battery & range, turn-by-turn, now playing.
Column {
    id: card
    property var sim
    property var theme
    width: 272
    spacing: 0

    function fmtDist(m) { return m >= 1000 ? (m / 1000).toFixed(1) + " km" : (Math.round(m / 10) * 10) + " m" }
    function fmtTime(s) { s = Math.max(0, Math.floor(s)); return Math.floor(s / 60) + ":" + ("0" + (s % 60)).slice(-2) }

    Caption { theme: card.theme; text: "BATTERY"; anchors.right: parent.right }
    Row {
        anchors.right: parent.right
        spacing: 8
        Text { id: bt; text: Math.floor(card.sim.battery); font.family: card.theme.face; font.pixelSize: 60; font.weight: Font.Light
               color: card.sim.battery < 20 ? card.theme.warn : card.theme.text }
        Text { anchors.baseline: bt.baseline; text: "%"; font.family: card.theme.face; font.pixelSize: 18; color: card.theme.sub }
    }
    Text { anchors.right: parent.right; text: Math.round(card.sim.range) + " km range  ·  " + card.theme.modeTitle
           font.family: card.theme.face; font.pixelSize: 14; color: card.theme.sub }
    Item { width: 1; height: 12 }
    Rectangle { width: parent.width; height: 1; color: card.theme.line }
    Item { width: 1; height: 16 }

    Row {
        anchors.right: parent.right
        spacing: 16
        Column {
            anchors.verticalCenter: parent.verticalCenter
            Text { anchors.right: parent.right; text: card.fmtDist(card.sim.navRemain)
                   font.family: card.theme.face; font.pixelSize: 32; font.weight: Font.Light; color: card.theme.text }
            Text { anchors.right: parent.right; text: card.sim.nav.road
                   font.family: card.theme.face; font.pixelSize: 15; color: card.theme.accent }
        }
        Rectangle {
            width: 72; height: 72; radius: 20
            color: "transparent"; border.color: card.theme.accent; border.width: 1.5
            TurnArrow { anchors.centerIn: parent; dir: card.sim.nav.dir; color: card.theme.text; scale: 0.78 }
        }
    }
    Item { width: 1; height: 8 }
    Text {
        anchors.right: parent.right
        readonly property real mins: card.sim.routeRemainKm / Math.max(28, card.sim.speed) * 60
        text: card.sim.destination + "  ·  " + card.sim.routeRemainKm.toFixed(1) + " km  ·  ETA "
              + Qt.formatTime(new Date(card.sim.now.getTime() + mins * 60000), "hh:mm")
        font.family: card.theme.face; font.pixelSize: 13; color: card.theme.sub
    }
    Item { width: 1; height: 16 }
    Rectangle { width: parent.width; height: 1; color: card.theme.line }
    Item { width: 1; height: 16 }

    Caption { theme: card.theme; anchors.right: parent.right; text: card.sim.playing ? "NOW PLAYING" : "PAUSED" }
    Item { width: 1; height: 4 }
    Text { anchors.right: parent.right; text: card.sim.track.title; font.family: card.theme.face; font.pixelSize: 21; color: card.theme.text }
    Text { anchors.right: parent.right; text: card.sim.track.artist; font.family: card.theme.face; font.pixelSize: 14; color: card.theme.sub }
    Item { width: 1; height: 10 }
    Item {
        width: parent.width; height: 14
        Rectangle { y: 6; width: parent.width; height: 2; radius: 1; color: card.theme.line }
        Rectangle { y: 6; height: 2; radius: 1; width: parent.width * card.sim.trackPos / card.sim.track.dur; color: card.theme.accent }
    }
    Text { anchors.right: parent.right; text: card.fmtTime(card.sim.trackPos) + " / " + card.fmtTime(card.sim.track.dur)
           font.family: card.theme.face; font.pixelSize: 12; color: card.theme.dim }
}
