import QtQuick

// HEALTH: drive-on budget (7), alignment drift trend (8), fault future (10).
Column {
    id: card
    property var sim
    property var theme
    width: 272
    spacing: 8
    signal evidence(string sig, string headline)

    Caption { theme: card.theme; text: "DRIVE-ON BUDGET  ·  FR TYRE"; anchors.right: parent.right }
    Row {
        anchors.right: parent.right
        spacing: 8
        Text { id: bud
               text: card.sim.driveOnKm >= 0 ? Math.round(card.sim.driveOnKm) : "—"
               font.family: card.theme.face; font.pixelSize: 44; font.weight: Font.Light
               color: card.sim.driveOnKm >= 0 ? card.theme.warn : card.theme.good }
        Text { anchors.baseline: bud.baseline; text: card.sim.driveOnKm >= 0 ? "km at ≤ 60" : card.sim.tyreLeak ? "measuring…" : "no leak"
               font.family: card.theme.face; font.pixelSize: 15; color: card.theme.sub }
    }
    Text {
        anchors.right: parent.right
        text: card.sim.wheels[1].psi.toFixed(1) + " psi · −" + card.sim.leakRate.toFixed(1) + " psi/min · shop " + card.sim.serviceKm.toFixed(1) + " km"
        font.family: card.theme.face; font.pixelSize: 12; color: card.theme.sub
    }
    Item {
        width: card.width; height: 52
        Sparkline { anchors.fill: parent; values: card.sim.hist.psiFR; threshold: card.sim.profile.psi - 4
                    color: card.theme.accent; warnColor: card.theme.warn; gridColor: card.theme.line }
    }

    Rectangle { width: card.width; height: 1; color: card.theme.line }
    Caption { theme: card.theme; text: "ALIGNMENT · BIAS / 100 km"; anchors.right: parent.right }
    Item {
        width: card.width; height: 46
        Sparkline { anchors.fill: parent; values: card.sim.alignHist; threshold: 0.25; thresholdBelow: false; bars: true
                    minY: 0; maxY: 0.45; color: card.theme.accent2; warnColor: card.theme.warn; gridColor: card.theme.line }
    }
    Text {
        anchors.right: parent.right
        text: card.sim.alignFault ? "Bias +0.38° rising for 1,200 km · book alignment" : "Bias 0.05° · steady · within spec"
        font.family: card.theme.face; font.pixelSize: 12; color: card.sim.alignFault ? card.theme.warn : card.theme.sub
    }

    Rectangle { width: card.width; height: 1; color: card.theme.line }
    Caption { theme: card.theme; text: "FAULT FUTURE · " + card.sim.dailyKm + " km/day"; anchors.right: parent.right }
    Repeater {
        model: 4
        Item {
            required property int index
            readonly property var modelData: card.sim.futureItems[index]
            visible: !modelData.live || card.sim.tyreLeak
            width: card.width; height: visible ? 30 : 0
            readonly property real days: modelData.live ? modelData.km / 60 / 24 * 60 / card.sim.dailyKm * 24 : modelData.km / card.sim.dailyKm
            Text { text: parent.modelData.name + "  ·  " + parent.modelData.now; font.family: card.theme.face; font.pixelSize: 13; color: card.theme.text }
            Text {
                anchors.right: parent.right
                text: parent.modelData.live ? (parent.modelData.km >= 0 ? Math.round(parent.modelData.km) + " km at ≤ 60" : "measuring…") : "~" + Math.round(parent.days) + " days"
                font.family: card.theme.face; font.pixelSize: 13
                color: parent.modelData.live || parent.days < 120 ? card.theme.warn : card.theme.good
            }
            Rectangle { y: 20; width: card.width; height: 3; radius: 1.5; color: card.theme.line
                Rectangle { height: 3; radius: 1.5; width: parent.width * Math.min(1, parent.parent.days / 365)
                            color: parent.parent.modelData.live || parent.parent.days < 120 ? card.theme.warn : card.theme.accent } }
        }
    }
}
