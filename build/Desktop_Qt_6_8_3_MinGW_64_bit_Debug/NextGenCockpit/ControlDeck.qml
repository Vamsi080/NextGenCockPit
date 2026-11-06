import QtQuick

// Signal-injection panel used by the Signal Simulator window. These are the
// inputs a real car would send over CAN (driver controls, sensors, faults).
// The cluster itself never takes input.
Rectangle {
    id: deck
    property var sim
    property var theme
    property bool copilotOpen: false
    signal toggleCopilot()
    signal toggleFullscreen()
    width: 1920
    height: 180
    color: "#060A10"

    Rectangle { width: parent.width; height: 1; color: deck.theme.line }

    component Group: Column {
        property string title
        default property alias content: row.data
        spacing: 8
        Caption { theme: deck.theme; text: parent.title; font.pixelSize: 11; color: deck.theme.sub }
        Flow { id: row; width: parent.width; spacing: 6 }
    }

    Row {
        x: 40; y: 16
        spacing: 26

        Group {
            title: "DRIVE"
            width: 300
            DeckButton { theme: deck.theme; label: "▲ ACCEL"; hint: "HOLD ↑"; hold: true; active: deck.sim.accelHeld
                onPressedChanged2: (d) => { deck.sim.accelHeld = d; if (d) deck.sim.autoDrive = false; else deck.sim.targetSpeed = deck.sim.speed } }
            DeckButton { theme: deck.theme; label: "▼ BRAKE"; hint: "HOLD ↓"; hold: true; active: deck.sim.brakeHeld; activeColor: deck.theme.danger
                onPressedChanged2: (d) => { deck.sim.brakeHeld = d; if (d) deck.sim.autoDrive = false; else deck.sim.targetSpeed = deck.sim.speed } }
            DeckButton { theme: deck.theme; label: "ACC"; hint: "A"; active: deck.sim.autoDrive; onClicked: deck.sim.autoDrive = !deck.sim.autoDrive }
            DeckButton { theme: deck.theme; label: "◀ TURN"; hint: "←"; active: deck.sim.indicator === -1; activeColor: deck.theme.good; onClicked: deck.sim.toggleIndicator(-1) }
            DeckButton { theme: deck.theme; label: "TURN ▶"; hint: "→"; active: deck.sim.indicator === 1; activeColor: deck.theme.good; onClicked: deck.sim.toggleIndicator(1) }
            DeckButton { theme: deck.theme; label: "HAZARD"; hint: "Z"; active: deck.sim.hazard; activeColor: deck.theme.danger; onClicked: deck.sim.hazard = !deck.sim.hazard }
            DeckButton { theme: deck.theme; label: "HIGH BEAM"; hint: "H"; active: deck.sim.highBeam; activeColor: deck.theme.beam; onClicked: deck.sim.highBeam = !deck.sim.highBeam }
        }

        Group {
            title: "GEAR LEVER · DRIVE MODE SWITCH"
            width: 360
            Repeater {
                model: ["P", "R", "N", "D"]
                DeckButton { required property string modelData; theme: deck.theme; label: modelData; hint: modelData; implicitWidth: 44
                             active: deck.sim.gear === modelData; onClicked: deck.sim.requestGear(modelData) }
            }
            Repeater {
                model: [{ k: "eco", t: "ECO", h: "1" }, { k: "comfort", t: "COMFORT", h: "2" }, { k: "sport", t: "SPORT", h: "3" }]
                DeckButton { required property var modelData; theme: deck.theme; label: modelData.t; hint: modelData.h
                             active: deck.sim.mode === modelData.k; onClicked: deck.sim.mode = modelData.k }
            }
        }

        Group {
            title: "ROAD & LOAD"
            width: 280
            DeckButton { theme: deck.theme; label: "WEATHER: " + deck.sim.weather.name.toUpperCase(); hint: "X"
                         active: deck.sim.weatherIndex !== 0; activeColor: deck.theme.warn; onClicked: deck.sim.nextWeather() }
            DeckButton { theme: deck.theme; label: "DEEP WATER"; hint: "rain only"; active: deck.sim.waterDepth > deck.sim.profile.wading; activeColor: deck.theme.danger
                         onClicked: { deck.sim.waterDepth = deck.sim.waterDepth > deck.sim.profile.wading ? 250 : deck.sim.profile.wading + 80; if (deck.sim.weatherIndex !== 1) deck.sim.weatherIndex = 1 } }
            DeckButton { theme: deck.theme; label: "ROCK AHEAD"; hint: "U"; activeColor: deck.theme.warn; active: deck.sim.obstacle.type === "Rock"
                         onClicked: deck.sim.obstacle = { type: "Rock", h: 230, at: deck.sim.odometer + 70 } }
            DeckButton { theme: deck.theme; label: "−"; hint: "people"; implicitWidth: 44; onClicked: deck.sim.passengers = Math.max(1, deck.sim.passengers - 1) }
            DeckButton { theme: deck.theme; label: deck.sim.passengers + " ABOARD"; hint: "load"; active: deck.sim.passengers > 3; activeColor: deck.theme.warn }
            DeckButton { theme: deck.theme; label: "+"; hint: "people"; implicitWidth: 44; onClicked: deck.sim.passengers = Math.min(7, deck.sim.passengers + 1) }
            DeckButton { theme: deck.theme; label: "ROOF BOX"; hint: "fit check"; active: deck.sim.roofBox; activeColor: deck.theme.warn; onClicked: deck.sim.roofBox = !deck.sim.roofBox }
        }

        Group {
            title: "FAULT & SAFETY DEMOS"
            width: 520
            DeckButton { theme: deck.theme; label: "SEATBELT"; hint: "B"; active: !deck.sim.passengerBelted; activeColor: deck.theme.danger; onClicked: deck.sim.passengerBelted = !deck.sim.passengerBelted }
            DeckButton { theme: deck.theme; label: "DOOR"; hint: "O"; active: deck.sim.doorOpenRL; activeColor: deck.theme.danger; onClicked: deck.sim.doorOpenRL = !deck.sim.doorOpenRL }
            DeckButton { theme: deck.theme; label: "TYRE LEAK"; hint: "T"; active: deck.sim.tyreLeak; activeColor: deck.theme.warn; onClicked: deck.sim.tyreLeak = !deck.sim.tyreLeak }
            DeckButton { theme: deck.theme; label: "ALIGNMENT"; hint: "W"; active: deck.sim.alignFault; activeColor: deck.theme.warn; onClicked: deck.sim.alignFault = !deck.sim.alignFault }
            DeckButton { theme: deck.theme; label: "CAMERA BLOCKED"; hint: "J"; active: deck.sim.cameraBlocked; activeColor: deck.theme.warn; onClicked: deck.sim.cameraBlocked = !deck.sim.cameraBlocked }
            DeckButton { theme: deck.theme; label: "WEAK MODULE"; hint: "Y"; active: deck.sim.weakModule; activeColor: deck.theme.warn; onClicked: deck.sim.weakModule = !deck.sim.weakModule }
            DeckButton { theme: deck.theme; label: "EYES OFF ROAD"; hint: "L"; active: deck.sim.eyesOff; activeColor: deck.theme.warn; onClicked: deck.sim.eyesOff = !deck.sim.eyesOff }
            DeckButton { theme: deck.theme; label: "DROWSY"; hint: "K"; active: deck.sim.attention < 35; activeColor: deck.theme.warn; onClicked: deck.sim.attention = deck.sim.attention < 35 ? 100 : 25 }
        }

        Group {
            title: "SYSTEM"
            width: 300
            DeckButton { theme: deck.theme; label: "‹ " + deck.sim.profile.name + " ›"; hint: "G · VEHICLE PROFILE"; onClicked: deck.sim.nextProfile() }
            DeckButton { theme: deck.theme; label: "SCRIPTED DEMO"; hint: "S · 200 s loop"; active: deck.sim.scenario
                         onClicked: { deck.sim.scenario = !deck.sim.scenario; if (deck.sim.scenario) { deck.sim.scnT = 0; deck.sim._scnPrev = 0 } } }
            DeckButton { theme: deck.theme; label: "CO-PILOT"; hint: "C"; active: deck.copilotOpen; onClicked: deck.toggleCopilot() }
            DeckButton { theme: deck.theme; label: "CLUSTER FULLSCREEN"; hint: "F"; onClicked: deck.toggleFullscreen() }
        }
    }
}
