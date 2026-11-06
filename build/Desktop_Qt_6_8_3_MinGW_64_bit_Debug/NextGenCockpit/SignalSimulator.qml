import QtQuick
import QtQuick.Window

// ============================================================================
// Signal Simulator — development test bench, NOT part of the cluster.
// Stands in for the vehicle's CAN / sensor bus: gear lever, pedals, drive-mode
// switch, weather, faults. In the car this window is replaced by real signals
// feeding VehicleSim.qml; the cluster display stays read-only either way.
// ============================================================================
Window {
    id: simWin
    property var sim
    property var theme
    property var cluster
    property var copilot
    width: 1920
    height: 250
    x: 0
    title: "NextGenQT — Signal Simulator (test bench, not part of the cluster)"
    color: "#060A10"

    function handleKey(e, down) {
        if (e.isAutoRepeat) { e.accepted = true; return }
        const v = sim
        switch (e.key) {
        case Qt.Key_Up:    v.accelHeld = down; if (down) v.autoDrive = false; else v.targetSpeed = v.speed; break
        case Qt.Key_Down:  v.brakeHeld = down; if (down) v.autoDrive = false; else v.targetSpeed = v.speed; break
        case Qt.Key_Left:  if (down) v.toggleIndicator(-1); break
        case Qt.Key_Right: if (down) v.toggleIndicator(1); break
        case Qt.Key_P: if (down) v.requestGear("P"); break
        case Qt.Key_R: if (down) v.requestGear("R"); break
        case Qt.Key_N: if (down) v.requestGear("N"); break
        case Qt.Key_D: if (down) v.requestGear("D"); break
        case Qt.Key_1: if (down) v.mode = "eco"; break
        case Qt.Key_2: if (down) v.mode = "comfort"; break
        case Qt.Key_3: if (down) v.mode = "sport"; break
        case Qt.Key_A: if (down) v.autoDrive = !v.autoDrive; break
        case Qt.Key_G: if (down) v.nextProfile(); break
        case Qt.Key_Z: if (down) v.hazard = !v.hazard; break
        case Qt.Key_H: if (down) v.highBeam = !v.highBeam; break
        case Qt.Key_X: if (down) v.nextWeather(); break
        case Qt.Key_B: if (down) v.passengerBelted = !v.passengerBelted; break
        case Qt.Key_O: if (down) v.doorOpenRL = !v.doorOpenRL; break
        case Qt.Key_T: if (down) v.tyreLeak = !v.tyreLeak; break
        case Qt.Key_W: if (down) v.alignFault = !v.alignFault; break
        case Qt.Key_U: if (down) v.obstacle = { type: "Rock", h: 230, at: v.odometer + 70 }; break
        case Qt.Key_K: if (down) v.attention = v.attention < 35 ? 100 : 25; break
        case Qt.Key_J: if (down) v.cameraBlocked = !v.cameraBlocked; break
        case Qt.Key_Y: if (down) v.weakModule = !v.weakModule; break
        case Qt.Key_L: if (down) v.eyesOff = !v.eyesOff; break
        case Qt.Key_S: if (down) { v.scenario = !v.scenario; if (v.scenario) { v.scnT = 0; v._scnPrev = 0 } } break
        case Qt.Key_C: if (down) simWin.copilot.visible = !simWin.copilot.visible; break
        case Qt.Key_M: if (down) v.nextTrack(); break
        case Qt.Key_F: if (down) simWin.toggleClusterFullscreen(); break
        default: return
        }
        e.accepted = true
    }
    function toggleClusterFullscreen() {
        cluster.visibility = cluster.visibility === Window.FullScreen ? Window.Windowed : Window.FullScreen
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onPressed: (e) => simWin.handleKey(e, true)
        Keys.onReleased: (e) => simWin.handleKey(e, false)

        Row {
            x: 40; y: 14; spacing: 14
            Rectangle { width: 10; height: 10; radius: 5; anchors.verticalCenter: parent.verticalCenter
                        color: simWin.sim.scenario ? simWin.theme.good : simWin.theme.dim }
            Text {
                text: simWin.sim.scenario
                      ? "SCRIPTED DEMO  " + Math.floor(simWin.sim.scnT) + " / 200 s  ·  " + simWin.sim.scnPhase
                      : "MANUAL SIGNAL INJECTION  ·  scripted demo off (S)"
                font.family: simWin.theme.face; font.pixelSize: 15; font.weight: Font.DemiBold; color: simWin.theme.text
            }
            Text {
                text: "·  This window replaces the car's CAN bus. The cluster window is display-only."
                font.family: simWin.theme.face; font.pixelSize: 13; color: simWin.theme.sub
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        ControlDeck {
            y: 52
            sim: simWin.sim; theme: simWin.theme
            copilotOpen: simWin.copilot ? simWin.copilot.visible : false
            onToggleCopilot: simWin.copilot.visible = !simWin.copilot.visible
            onToggleFullscreen: simWin.toggleClusterFullscreen()
        }
    }
}
