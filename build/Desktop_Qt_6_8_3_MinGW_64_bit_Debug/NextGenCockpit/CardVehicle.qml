import QtQuick

// VEHICLE: model profile (switchable), specs, tyres (TPMS) and alignment.
Column {
    id: card
    property var sim
    property var theme
    width: 272
    spacing: 8

    // profile selector
    Item {
        width: card.width; height: 46
        Column {
            anchors.right: parent.right; anchors.rightMargin: 0
            Text { anchors.right: parent.right; text: card.sim.profile.name
                   font.family: card.theme.face; font.pixelSize: 22; color: card.theme.text }
            Caption { anchors.right: parent.right; theme: card.theme; text: card.sim.profile.body.toUpperCase() + "  ·  PROFILE " + (card.sim.profileIndex + 1) + "/" + card.sim.profiles.length }
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 36; height: 36; radius: 10
            color: "transparent"; border.color: card.theme.dim; border.width: 1
            Text { anchors.centerIn: parent; text: card.sim.profileIndex + 1; color: card.theme.text; font.pixelSize: 16 }
        }
    }

    // spec grid
    Grid {
        columns: 3
        columnSpacing: 12
        rowSpacing: 6
        Repeater {
            model: [
                { k: "BATTERY",   v: card.sim.profile.batt + " kWh" },
                { k: "POWER",     v: card.sim.profile.power + " kW" },
                { k: "TORQUE",    v: card.sim.profile.torque + " Nm" },
                { k: "RANGE",     v: card.sim.profile.range + " km" },
                { k: "CLEARANCE", v: card.sim.profile.clearance + " mm" },
                { k: "TYRES",     v: card.sim.profile.tyre }
            ]
            Column {
                required property var modelData
                width: 92
                Caption { theme: card.theme; text: parent.modelData.k; font.pixelSize: 10; font.letterSpacing: 2 }
                Text { text: parent.modelData.v; font.family: card.theme.face; font.pixelSize: 15; color: card.theme.text }
            }
        }
    }

    Rectangle { width: card.width; height: 1; color: card.theme.line }
    Caption { theme: card.theme; text: "TYRES · TPMS · ALIGNMENT · " + card.sim.profile.psi + " psi" }

    // tyre diagram
    Item {
        width: card.width; height: 150
        Rectangle {
            x: card.width / 2 - 30; y: 6; width: 60; height: 138; radius: 22
            color: "transparent"; border.color: card.theme.dim; border.width: 1.5
        }
        Repeater {
            model: 4
            Item {
                required property int index
                readonly property var w: card.sim.wheels[index]
                readonly property bool bad: card.sim.wheelBad(w)
                readonly property bool isLeft: index % 2 === 0
                x: isLeft ? 0 : card.width / 2 + 40
                y: index < 2 ? 4 : 84
                width: card.width / 2 - 40; height: 60
                Rectangle {
                    x: parent.isLeft ? parent.width - 8 : -2
                    y: 6; width: 10; height: 36; radius: 3
                    color: parent.bad ? card.theme.warn : card.theme.accent
                }
                Column {
                    x: parent.isLeft ? 0 : 16
                    width: parent.width - 20
                    Text { width: parent.width; horizontalAlignment: parent.parent.isLeft ? Text.AlignRight : Text.AlignLeft
                           text: parent.parent.w.id + "  " + parent.parent.w.psi.toFixed(1)
                           font.family: card.theme.face; font.pixelSize: 17; color: parent.parent.bad ? card.theme.warn : card.theme.text }
                    Text { width: parent.width; horizontalAlignment: parent.parent.isLeft ? Text.AlignRight : Text.AlignLeft
                           text: Math.round(parent.parent.w.temp) + "°C · toe " + (parent.parent.w.toe >= 0 ? "+" : "") + parent.parent.w.toe.toFixed(2) + "°"
                           font.family: card.theme.face; font.pixelSize: 11
                           color: Math.abs(parent.parent.w.toe) > 0.25 ? card.theme.warn : card.theme.sub }
                }
            }
        }
    }
    Text {
        text: card.sim.alignFault ? "Alignment drift detected — service soon" : "Alignment within spec  ·  ODO " + Math.round(card.sim.odoTotal) + " km"
        font.family: card.theme.face; font.pixelSize: 13
        color: card.sim.alignFault ? card.theme.warn : card.theme.sub
    }
}
