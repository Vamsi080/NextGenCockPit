import QtQuick

// Full telltale strip. Every lamp is always present (ghosted when off) so the
// driver learns the layout; active lamps light in their regulated colour.
Row {
    id: strip
    property var sim
    property var theme
    spacing: 6
    signal picked(string kind)
    property bool blinkPhase: true
    Timer { interval: 200; running: true; repeat: true; onTriggered: strip.blinkPhase = !strip.blinkPhase }

    readonly property var lamps: [
        { k: "seatbelt",  on: !sim.passengerBelted || !sim.driverBelted, c: theme.danger, f: sim.speed > 10 },
        { k: "airbag",    on: false,                                     c: theme.danger },
        { k: "parkbrake", on: sim.parkingBrake,                          c: theme.danger },
        { k: "door",      on: sim.doorOpenRL,                            c: theme.danger },
        { k: "temp",      on: sim.motorTemp > 110,                       c: theme.danger },
        { k: "battery12", on: false,                                     c: theme.danger },
        { k: "fcw",       on: sim.fcw || sim.aeb,                        c: theme.danger, f: true },
        { k: "abs",       on: sim.absActive,                             c: theme.warn },
        { k: "esp",       on: sim.espActive,                             c: theme.warn, f: true },
        { k: "tpms",      on: sim.wheels.some(w => w.psi < sim.profile.psi - 4), c: theme.warn },
        { k: "ice",       on: sim.iceRisk,                               c: theme.warn },
        { k: "drowsy",    on: sim.attention < 35,                        c: theme.warn },
        { k: "bsm",       on: sim.bsLeft || sim.bsRight,                 c: theme.warn },
        { k: "lka",       on: sim.gear === "D" && sim.speed > 50,        c: theme.good },
        { k: "autohold",  on: sim.gear === "D" && sim.speed < 0.5,       c: theme.good },
        { k: "lowbeam",   on: sim.lowBeam,                               c: theme.good },
        { k: "fog",       on: sim.fogLamps,                              c: theme.good },
        { k: "highbeam",  on: sim.highBeam,                              c: theme.beam },
        { k: "hazard",    on: sim.hazard,                                c: theme.danger, f: true }
    ]

    Repeater {
        model: strip.lamps.length
        TelltaleIcon {
            required property int index
            readonly property var lamp: strip.lamps[index]
            kind: lamp.k
            active: lamp.on
            color: lamp.c
            flashing: lamp.f === true
            blink: strip.blinkPhase
        }
    }
    Text {
        anchors.verticalCenter: parent.verticalCenter
        leftPadding: 6
        text: "READY"
        font.family: strip.theme.face; font.pixelSize: 13; font.weight: Font.Bold; font.letterSpacing: 2
        color: strip.theme.good
    }
}
