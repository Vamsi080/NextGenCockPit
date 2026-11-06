import QtQuick

// DRIVE: power, efficiency, cruise / lane, or rear clearance in reverse.
Column {
    id: card
    property var sim
    property var theme
    width: 272
    spacing: 0
    readonly property bool regen: sim.power < -1
    readonly property bool rev: sim.gear === "R"

    Caption { theme: card.theme; text: card.regen ? "REGENERATING · LEVEL " + card.sim.regenLevel : "POWER"; color: card.regen ? card.theme.good : card.theme.sub }
    Row {
        spacing: 8
        Text {
            id: pw
            text: Math.round(Math.abs(card.sim.power))
            font.family: card.theme.face; font.pixelSize: 60; font.weight: Font.Light
            color: card.regen ? card.theme.good : card.theme.text
        }
        Text { anchors.baseline: pw.baseline; text: "kW"; font.family: card.theme.face; font.pixelSize: 18; color: card.theme.sub }
    }
    Item { width: 1; height: 8 }
    Rectangle { width: parent.width; height: 1; color: card.theme.line }
    Item { width: 1; height: 14 }
    Caption { theme: card.theme; text: "EFFICIENCY  ·  TRIP " + card.sim.tripKm.toFixed(1) + " km" }
    Item { width: 1; height: 4 }
    Row {
        spacing: 8
        Text { id: ef; text: Math.max(0, card.sim.efficiency).toFixed(1); font.family: card.theme.face; font.pixelSize: 30; font.weight: Font.Light; color: card.theme.text }
        Text { anchors.baseline: ef.baseline; text: "kWh/100 km"; font.family: card.theme.face; font.pixelSize: 14; color: card.theme.sub }
    }
    Item { width: 1; height: 14 }
    Rectangle { width: parent.width; height: 1; color: card.theme.line }
    Item { width: 1; height: 16 }

    Item {
        width: parent.width
        height: 250

        // ----- driving assist
        Column {
            anchors.fill: parent
            spacing: 10
            opacity: card.rev ? 0 : 1
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 400 } }
            Row {
                spacing: 10
                Rectangle { width: 8; height: 8; radius: 4; anchors.verticalCenter: parent.verticalCenter
                            color: card.sim.autoDrive ? card.theme.accent : card.theme.dim }
                Caption { theme: card.theme; text: "ADAPTIVE CRUISE  " + (card.sim.autoDrive ? Math.round(card.sim.setSpeed) + " km/h" : "OFF")
                          color: card.sim.autoDrive ? card.theme.text : card.theme.dim }
            }
            Row {
                spacing: 6
                Repeater {
                    model: 4
                    Rectangle {
                        required property int index
                        width: 40 + index * 10; height: 6; radius: 3
                        readonly property bool on: card.sim.leadDistance > 0 && index < Math.ceil(Math.min(4, card.sim.leadDistance / 18))
                        color: on ? (card.sim.fcw ? card.theme.danger : card.theme.accent) : card.theme.line
                    }
                }
            }
            Text {
                text: card.sim.leadDistance > 0 ? Math.round(card.sim.leadDistance) + " m  ·  " + card.sim.leadGapSec.toFixed(1) + " s" : "Lane clear"
                font.family: card.theme.face; font.pixelSize: 22; font.weight: Font.Light
                color: card.sim.fcw ? card.theme.danger : card.theme.text
            }
            Item { width: 1; height: 4 }
            Row {
                spacing: 10
                Item {
                    width: 26; height: 22
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle { x: 2; width: 3; height: 22; radius: 1.5; color: card.sim.bsLeft ? card.theme.danger : card.theme.accent }
                    Rectangle { x: 21; width: 3; height: 22; radius: 1.5; color: card.sim.bsRight ? card.theme.danger : card.theme.accent }
                    Rectangle { x: 11; y: 4; width: 4; height: 14; radius: 2; color: card.theme.text; opacity: 0.8 }
                }
                Column {
                    Caption { theme: card.theme; text: "LANE CENTERING"; color: card.theme.text }
                    Text {
                        text: card.sim.takeoverIn >= 0 ? "Hands back in " + Math.ceil(card.sim.takeoverIn) + " s"
                              : !card.sim.laneAssistAvailable ? "Unavailable — take control"
                              : card.sim.laneChangeBlocked ? "Lane change blocked — blind spot"
                              : card.sim.indicator !== 0 ? (card.sim.indicator < 0 ? "Changing lane ←" : "Changing lane →")
                              : "Lane " + (card.sim.egoLane + 2) + " of 3"
                        font.family: card.theme.face; font.pixelSize: 14
                        color: card.sim.takeoverIn >= 0 || !card.sim.laneAssistAvailable || card.sim.laneChangeBlocked ? card.theme.warn : card.theme.sub
                    }
                }
            }
            // Sensor Trust Meter (concept 1)
            Row {
                spacing: 10
                Caption { theme: card.theme; text: "SENSOR TRUST"; anchors.verticalCenter: parent.verticalCenter }
                Repeater {
                    model: [ { k: "CAM", v: card.sim.trustCam }, { k: "RADAR", v: card.sim.trustRadar }, { k: "LIDAR", v: card.sim.trustLidar } ]
                    Text {
                        required property var modelData
                        text: modelData.k + " " + Math.round(modelData.v * 100)
                        font.family: card.theme.face; font.pixelSize: 13; font.weight: Font.DemiBold
                        color: modelData.v > 0.85 ? card.theme.good : modelData.v > 0.5 ? card.theme.warn : card.theme.danger
                    }
                }
            }
            Text {
                text: "ADAS confidence " + Math.round(card.sim.adasConfidence * 100) + " %"
                font.family: card.theme.face; font.pixelSize: 13
                color: card.sim.adasConfidence > 0.85 ? card.theme.sub : card.theme.warn
            }
        }

        // ----- reverse assist
        Column {
            id: rv
            anchors.fill: parent
            spacing: 8
            opacity: card.rev ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 400 } }
            readonly property real g: card.sim.parkGap
            readonly property color c: card.sim.rearAeb ? card.theme.danger : g < 1.0 ? card.theme.warn : card.theme.accent
            Caption { theme: card.theme; text: "REAR CLEARANCE"; color: card.theme.text }
            Row {
                spacing: 8
                Text { id: rg; text: rv.g.toFixed(2); font.family: card.theme.face; font.pixelSize: 54; font.weight: Font.Light; color: rv.c }
                Text { anchors.baseline: rg.baseline; text: "m"; font.family: card.theme.face; font.pixelSize: 20; color: card.theme.sub }
            }
            Text {
                text: "Side  L " + card.sim.sideGapL.toFixed(2) + " m   ·   R " + card.sim.sideGapR.toFixed(2) + " m"
                font.family: card.theme.face; font.pixelSize: 15; color: card.theme.sub
            }
            Text {
                text: card.sim.rearAeb ? (card.sim.pedActive && Math.abs(card.sim.pedX) < 1.7 ? "AUTO-BRAKE · pedestrian in path" : "AUTO-BRAKE · stopped before contact")
                      : card.sim.rcta ? "Cross traffic detected — slowing" : "Reversing · steering guided"
                font.family: card.theme.face; font.pixelSize: 15
                color: card.sim.rearAeb ? card.theme.danger : card.sim.rcta ? card.theme.warn : card.theme.accent
            }
        }
    }
}
