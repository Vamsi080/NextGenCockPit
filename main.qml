import QtQuick
import QtQuick.Window

// ============================================================================
//  NextGenQT Cluster — 1920 x 720 sensor-fusion instrument cluster.
//  READ-ONLY: the cluster takes no touch, mouse or keyboard input. Everything
//  shown comes from vehicle signals (VehicleSim.qml today, CAN tomorrow).
//  Camera view, card pages and Evidence Card switch automatically by context.
//  Inputs are injected from the separate Signal Simulator window.
// ============================================================================
Window {
    id: root
    width: 1920
    height: 720
    visible: true
    color: "#03050A"
    title: qsTr("NextGenQT Cluster")

    VehicleSim { id: vehicle }
    Theme { id: appTheme; mode: vehicle.mode; gear: vehicle.gear }

    property real boot: 0
    SequentialAnimation on boot {
        PauseAnimation { duration: 900 }
        NumberAnimation { from: 0; to: 1; duration: 2200; easing.type: Easing.OutCubic }
    }

    // ------------------------------------------------ context manager
    // Picks camera view and card pages from sensor state, with hold times
    // so the display never flickers between pages.
    property int leftIdx: 0          // 0 DRIVE · 1 SAFETY · 2 SENSORS · 3 ROAD
    property int rightIdx: 0         // 0 NAV · 1 VEHICLE · 2 HEALTH · 3 ENERGY
    property string viewReason: "driving"
    property double _viewUntil: 0
    property double _leftUntil: 0
    property double _rightUntil: 0
    property bool evOpen: false
    property string evSig: "psiFR"
    property string evHead: ""
    property var _evShown: ({})

    Timer { interval: 400; running: true; repeat: true; onTriggered: root.updateContext() }
    Timer { id: evTimer; interval: 6000; onTriggered: root.evOpen = false }

    function updateContext() {
        const v = vehicle, now = Date.now()
        // camera view
        let want = "front", why = "driving"
        if (v.gear === "R") { want = "rear"; why = "reverse gear" }
        else if (v.gear === "P") { want = "top"; why = "parked" }
        else if (v.underbodyRisk || (v.speed < 14 && v.obstacleDist > -3 && v.obstacleDist < 15)) { want = "under"; why = "obstacle under car" }
        else if (v.gear === "D" && (v.indicator !== 0 || ((v.bsLeft || v.bsRight) && v.speed < 40))) { want = "top"; why = "lane change / blind spot" }
        const urgent = (want === "rear") !== (v.view === "rear")       // gear R switches instantly
        if (want !== v.view && (urgent || now > _viewUntil)) { v.view = want; viewReason = why; _viewUntil = now + 3000 }
        else if (want === v.view) viewReason = why

        // left card
        let L = 0
        if (v.fcw || v.aeb || v.rearAeb || v.rcta || v.doorOpenRL || (!v.passengerBelted && v.speed > 10) || v.attention < 35
            || ((v.bsLeft || v.bsRight) && v.indicator !== 0)) L = 1
        else if (v.cameraBlocked || v.takeoverIn >= 0 || v.trustCam < 0.6) L = 2
        else if (v.waterActive || v.underbodyRisk || v.weatherIndex !== 0) L = 3
        if (L !== leftIdx && (L > leftIdx || now > _leftUntil)) { leftIdx = L; _leftUntil = now + 5000 }
        else if (L === leftIdx) _leftUntil = Math.max(_leftUntil, now + 1500)

        // right card
        let R = 0
        if (v.tyreLeak || v.alignFault || v.wheels.some(w => v.wheelBad(w))) R = 2
        else if (v.weakModule || v.battery < 15) R = 3
        else if (v.gear === "P") R = 1
        if (R !== rightIdx && (R >= 2 || now > _rightUntil)) { rightIdx = R; _rightUntil = now + 5000 }
        else if (R === rightIdx) _rightUntil = Math.max(_rightUntil, now + 1500)

        // Evidence Card: shown once per new warning that has signal evidence
        const present = {}
        let critical = false
        for (const a of v.alerts) { if (a.sig) present[a.sig] = true; if (a.level >= 3) critical = true }
        for (const k in _evShown) if (!present[k]) delete _evShown[k]
        if (!evOpen && !critical) {
            for (const a of v.alerts) {
                if (a.level === 2 && a.sig && !_evShown[a.sig]) {
                    _evShown[a.sig] = true
                    evSig = a.sig; evHead = a.text; evOpen = true; evTimer.restart()
                    break
                }
            }
        }
        if (critical && evOpen) evOpen = false     // never cover a critical warning
    }

    Item {
        id: stage
        width: 1920
        height: 720
        anchors.centerIn: parent
        scale: Math.min(root.width / 1920, root.height / 720)
        clip: true

        Backdrop { anchors.fill: parent; theme: appTheme }

        LidarScene {
            sim: vehicle; theme: appTheme
            boot: Math.min(1, root.boot * 1.6)
        }

        // dissolve the scene outside the lens
        Rectangle {
            width: 560; height: parent.height
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0;  color: appTheme.bg }
                GradientStop { position: 0.62; color: Qt.rgba(0.012, 0.02, 0.04, 0.9) }
                GradientStop { position: 1.0;  color: "transparent" }
            }
        }
        Rectangle {
            anchors.right: parent.right
            width: 560; height: parent.height
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0;  color: "transparent" }
                GradientStop { position: 0.38; color: Qt.rgba(0.012, 0.02, 0.04, 0.9) }
                GradientStop { position: 1.0;  color: appTheme.bg }
            }
        }

        LensFrame { anchors.fill: parent; sim: vehicle; theme: appTheme; boot: root.boot }

        // ---------------------------------------------------------- top
        Telltales {
            id: lamps
            sim: vehicle; theme: appTheme
            anchors.horizontalCenter: parent.horizontalCenter
            y: 8
            opacity: root.boot
        }
        Indicator {
            x: 960 - 330 - width / 2; y: 118; side: -1
            active: vehicle.indicator === -1 || vehicle.hazard; on: vehicle.blinkOn
            color: appTheme.good; offColor: appTheme.line
        }
        Indicator {
            x: 960 + 330 - width / 2; y: 118; side: 1
            active: vehicle.indicator === 1 || vehicle.hazard; on: vehicle.blinkOn
            color: appTheme.good; offColor: appTheme.line
        }

        Column {
            x: 70; y: 26
            opacity: root.boot
            Text { text: Qt.formatTime(vehicle.now, "hh:mm"); font.family: appTheme.face; font.pixelSize: 26; font.weight: Font.Light; color: appTheme.text }
            Caption { theme: appTheme; text: Qt.formatDate(vehicle.now, "ddd dd MMM").toUpperCase() + "  ·  ODO " + Math.round(vehicle.odoTotal) + " KM" }
        }
        Column {
            anchors.right: parent.right; anchors.rightMargin: 70; y: 26
            opacity: root.boot
            Text { anchors.right: parent.right; text: vehicle.weather.temp + "°  " + vehicle.weather.name
                   font.family: appTheme.face; font.pixelSize: 26; font.weight: Font.Light
                   color: vehicle.iceRisk ? appTheme.warn : appTheme.text }
            Caption { anchors.right: parent.right; theme: appTheme; text: "ROAD " + vehicle.weather.road + "  ·  " + appTheme.modeTitle }
        }

        SpeedCluster {
            sim: vehicle; theme: appTheme
            anchors.horizontalCenter: parent.horizontalCenter
            readonly property bool compact: vehicle.view !== "front"
            y: compact ? 40 : 48
            scale: compact ? 0.6 : 1
            transformOrigin: Item.Top
            opacity: root.boot
            Behavior on y { NumberAnimation { duration: 700; easing.type: Easing.InOutCubic } }
            Behavior on scale { NumberAnimation { duration: 700; easing.type: Easing.InOutCubic } }
        }

        AlertBanner {
            sim: vehicle; theme: appTheme
            anchors.horizontalCenter: parent.horizontalCenter
            y: vehicle.view === "front" ? 282 : vehicle.view === "rear" ? 592 : 186
            Behavior on y { NumberAnimation { duration: 500 } }
        }

        // -------------------------------------------------------- decks
        LeftPanel {
            id: leftDeck
            objectName: "leftDeck"
            index: root.leftIdx
            x: 70; y: 108
            sim: vehicle; theme: appTheme
            opacity: root.boot * (vehicle.glanceExceeded ? 0.1 : 1)
            Behavior on opacity { NumberAnimation { duration: 300 } }
            transform: Translate { x: (1 - root.boot) * -40 }
        }
        RightPanel {
            id: rightDeck
            objectName: "rightDeck"
            index: root.rightIdx
            x: 1920 - 70 - width; y: 108
            sim: vehicle; theme: appTheme
            opacity: root.boot * (vehicle.glanceExceeded ? 0.1 : 1)
            Behavior on opacity { NumberAnimation { duration: 300 } }
            transform: Translate { x: (1 - root.boot) * 40 }
        }

        // ------------------------------------------------------- bottom
        ModeDock {
            x: 70; y: 632
            theme: appTheme
            title: "DRIVE MODE"
            model: [ { key: "eco", label: "ECO" }, { key: "comfort", label: "COMFORT" }, { key: "sport", label: "SPORT" } ]
            current: vehicle.mode
            opacity: root.boot
        }
        GearRail {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 650
            sim: vehicle; theme: appTheme
            opacity: root.boot
        }
        ModeDock {
            x: 1920 - 70 - width; y: 632
            theme: appTheme
            title: "CAMERA VIEW · AUTO"
            model: [ { key: "front", label: "FRONT" }, { key: "rear", label: "REAR" }, { key: "top", label: "360°" }, { key: "under", label: "UNDER" } ]
            current: vehicle.view
            opacity: root.boot
        }
        Caption {
            x: 70; y: 694
            theme: appTheme; font.pixelSize: 11; color: appTheme.sub
            text: "TRIP " + vehicle.tripKm.toFixed(1) + " km  ·  " + Math.max(0, vehicle.efficiency).toFixed(1) + " kWh/100 km"
            opacity: root.boot * 0.9
        }
        Caption {
            anchors.right: parent.right; anchors.rightMargin: 70; y: 694
            theme: appTheme; font.pixelSize: 11
            text: "AUTO · " + root.viewReason.toUpperCase() + (copilot.visible ? "  ·  ● CO-PILOT LINKED" : "")
            color: appTheme.sub
            opacity: root.boot * 0.9
        }

        // light wipe on drive-mode change
        Rectangle {
            id: wipe
            width: 600; height: parent.height
            x: -width; opacity: 0
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.5; color: Qt.rgba(appTheme.accent.r, appTheme.accent.g, appTheme.accent.b, 0.22) }
                GradientStop { position: 1.0; color: "transparent" }
            }
            ParallelAnimation {
                id: wipeAnim
                NumberAnimation { target: wipe; property: "x"; from: -600; to: 1920; duration: 1100; easing.type: Easing.InOutQuad }
                SequentialAnimation {
                    NumberAnimation { target: wipe; property: "opacity"; from: 0; to: 1; duration: 200 }
                    PauseAnimation { duration: 700 }
                    NumberAnimation { target: wipe; property: "opacity"; to: 0; duration: 200 }
                }
            }
        }
        Connections {
            target: vehicle
            function onModeChanged() { wipeAnim.restart() }
        }

        // ------------------------------------------------- boot splash
        Item {
            id: splash
            anchors.fill: parent
            opacity: 1 - Math.min(1, root.boot * 2.2)
            visible: opacity > 0.01
            Column {
                anchors.centerIn: parent
                spacing: 10
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "NextGenQT"
                    font.family: appTheme.face; font.pixelSize: 64; font.weight: Font.Light; font.letterSpacing: 6
                    color: appTheme.text
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 360; height: 2; radius: 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: "transparent" }
                        GradientStop { position: 0.5; color: appTheme.accent }
                        GradientStop { position: 1; color: "transparent" }
                    }
                }
                Caption {
                    anchors.horizontalCenter: parent.horizontalCenter
                    theme: appTheme; text: "C L U S T E R   ·   S E N S O R   F U S I O N"; color: appTheme.accent
                }
            }
        }

        EvidencePanel {
            sim: vehicle; theme: appTheme
            anchors.horizontalCenter: parent.horizontalCenter
            y: 230
            sig: root.evSig
            headline: root.evHead
            opacity: root.evOpen ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 250 } }
        }
    }

    CoPilotDisplay {
        id: copilot
        sim: vehicle
        theme: appTheme
        visible: false
    }

    // Development test bench (separate window). Remove when real CAN is wired.
    SignalSimulator {
        sim: vehicle
        theme: appTheme
        cluster: root
        copilot: copilot
        visible: true
        y: Math.max(0, Math.min(root.y + root.height + 30, Screen.desktopAvailableHeight - height - 40))
    }
}
