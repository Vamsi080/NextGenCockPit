import QtQuick

// ============================================================================
// NextGenQT Cluster — vehicle data model
// Every screen element only READS these properties. To go live, replace the
// simulation in step()/slowStep() with your CAN / SOME-IP / VSS signals.
// ============================================================================
Item {
    id: sim
    visible: false

    // ---------------------------------------------------------------- inputs
    property string mode: "comfort"         // eco | comfort | sport
    property string gear: "D"               // P | R | N | D
    property string view: "front"           // front | rear | top | under
    property bool autoView: true            // R -> rear camera automatically
    property bool autoDrive: true           // adaptive cruise
    property bool accelHeld: false
    property bool brakeHeld: false
    property int indicator: 0               // -1 left, 0 off, 1 right
    property bool hazard: false
    property bool blinkOn: false
    property bool highBeam: false

    // ------------------------------------------------------- vehicle profile
    // Approximate public figures; edit to match the exact variant you target.
    property int profileIndex: 0
    readonly property var profiles: [
        { name: "Nexon-class EV",  body: "Compact SUV",  batt: 45,  power: 106, torque: 215, range: 489,
          mass: 1550, clearance: 190, tyre: "215/60 R16", psi: 35, wheelbase: 2.50, height: 1.62, mirrorWidth: 2.03, wading: 300 },
        { name: "City Hatch EV",   body: "Hatchback",    batt: 30,  power: 55,  torque: 170, range: 315,
          mass: 1250, clearance: 165, tyre: "185/65 R15", psi: 33, wheelbase: 2.45, height: 1.52, mirrorWidth: 1.90, wading: 250 },
        { name: "Grand Tourer EV", body: "Sedan",        batt: 82,  power: 250, torque: 420, range: 560,
          mass: 2100, clearance: 145, tyre: "235/45 R19", psi: 38, wheelbase: 2.90, height: 1.45, mirrorWidth: 2.10, wading: 200 },
        { name: "Trail SUV EV",    body: "Off-road SUV", batt: 100, power: 300, torque: 600, range: 450,
          mass: 2600, clearance: 240, tyre: "265/65 R18", psi: 36, wheelbase: 2.95, height: 1.85, mirrorWidth: 2.20, wading: 600 }
    ]
    readonly property var profile: profiles[profileIndex]
    function nextProfile() { profileIndex = (profileIndex + 1) % profiles.length }
    function prevProfile() { profileIndex = (profileIndex + profiles.length - 1) % profiles.length }

    // ------------------------------------------------------------- dynamics
    property real speed: 0                  // km/h (magnitude, also in reverse)
    property real targetSpeed: 0
    property real accel: 0                  // km/h per s
    property real power: 0                  // kW (negative = regen)
    property real battery: 78.6
    property real efficiency: 14.6          // kWh/100 km
    property real odometer: 0               // m, drives scene scrolling
    property real odoTotal: 12846.3         // km
    property real tripKm: 12.4
    property real time: 0
    property real lateral: 0
    property int egoLane: 0
    property real steer: 0                  // -0.4 .. 0.4 (rad-ish)
    readonly property real maxPower: profile.power * (mode === "sport" ? 1.0 : mode === "eco" ? 0.6 : 0.85)
    readonly property real vmax: mode === "sport" ? 180 : mode === "eco" ? 110 : 150
    readonly property real range: battery / 100 * profile.range * (mode === "eco" ? 1.08 : mode === "sport" ? 0.86 : 1.0)
    readonly property real setSpeed: mode === "sport" ? 100 : mode === "eco" ? 70 : 80
    property int speedLimit: 80
    property int regenLevel: mode === "eco" ? 3 : mode === "sport" ? 1 : 2

    // ------------------------------------------------------------------ ADAS
    property real leadDistance: -1
    property real leadGapSec: 0
    property real ttc: 99
    property bool fcw: false                // forward collision warning
    property bool aeb: false                // automatic emergency braking
    property bool bsLeft: false             // blind spot
    property bool bsRight: false
    property real attention: 100            // driver attention %
    property real _blockedUntil: 0
    readonly property bool laneChangeBlocked: time < _blockedUntil

    // reverse assist
    property real parkGap: 5.5              // m to wall behind
    property real pedX: -7                  // pedestrian crossing behind (m, lateral)
    readonly property real pedU: parkGap - 1.0  // pedestrian distance behind bumper
    readonly property bool pedActive: gear === "R" && pedU > 0.25 && pedX > -6.5 && pedX < 6.5
    property bool rcta: false               // rear cross-traffic alert
    property bool rearAeb: false            // rear auto brake engaged
    property real _parkHold: 0
    readonly property real sideGapL: 0.78
    readonly property real sideGapR: 0.84

    // ------------------------------------------------------------------ body
    property bool doorOpenRL: false
    property bool passengerBelted: true
    readonly property bool driverBelted: true
    readonly property bool parkingBrake: gear === "P"
    property bool absActive: false
    property bool espActive: false

    // --------------------------------------------------- tyres & alignment
    property bool tyreLeak: false
    property bool alignFault: false
    property real _leakPsi: 35
    onTyreLeakChanged: { if (tyreLeak) { _leakPsi = wheels[1].psi; hist.psiFR = [] } }
    property var wheels: [
        { id: "FL", psi: 35, temp: 30, toe: 0.05, camber: -0.6 },
        { id: "FR", psi: 35, temp: 30, toe: -0.04, camber: -0.55 },
        { id: "RL", psi: 35, temp: 29, toe: 0.08, camber: -0.9 },
        { id: "RR", psi: 35, temp: 29, toe: 0.07, camber: -0.85 }
    ]
    function wheelBad(w) { return w.psi < profile.psi - 4 || Math.abs(w.toe) > 0.25 }

    // ------------------------------------------------------------ underbody
    readonly property real clearance: profile.clearance        // mm
    property bool rockAhead: false
    property var obstacle: ({ type: "Speed bump", h: 75, at: 160 })
    readonly property real obstacleDist: obstacle.at - odometer // m ahead of front bumper
    property int _obsIdx: 0
    readonly property var _obsTypes: [
        { type: "Speed bump", h: 75 }, { type: "Pothole", h: -60 },
        { type: "Debris", h: 110 }, { type: "Speed bump", h: 95 }
    ]
    property int passengers: 2
    // effective clearance: each occupant ~6 mm of squat, plus dynamic squat above 20 km/h
    readonly property real effClearance: clearance - passengers * 6 - Math.max(0, speed - 20) * 0.3
    readonly property real scrapeProb: Math.max(0, Math.min(1, (obstacle.h - (effClearance - 40)) / 40))
    readonly property real crossSpeed: obstacle.h >= effClearance - 15 ? 0 : obstacle.h > effClearance * 0.45 ? 8 : obstacle.h > 0 ? 20 : 30
    readonly property bool underbodyRisk: obstacle.h > effClearance - 25 && obstacleDist > -5 && obstacleDist < 45

    // =============================================== NEXT-GEN CONCEPTS =====
    // (1) Sensor Trust Meter — agreement of each sensor with the fused picture
    property bool cameraBlocked: false
    property real trustCam: 1
    property real trustRadar: 1
    property real trustLidar: 1
    readonly property real adasConfidence: Math.min(trustCam * 0.6 + trustRadar * 0.4, Math.min(trustCam, trustLidar) + 0.25)
    // (2) Takeover countdown — lane markings missing ahead (construction zone)
    property real laneGapAt: 900            // odometer position where markings end (m)
    readonly property real laneGapLen: 220
    readonly property real laneGapDist: laneGapAt - odometer
    readonly property bool lanesMissing: odometer > laneGapAt && odometer < laneGapAt + laneGapLen
    property real takeoverIn: -1            // s until lane centering hands back, -1 = none
    property real _camBlockedAt: -1
    readonly property bool laneAssistAvailable: !lanesMissing && trustCam > 0.35
    // (3) Escape path — free adjacent lane when the lead brakes hard
    property int escapeLane: 0              // -1 / 1 relative, 0 = none
    // (4) 3D fit check (reverse into garage)
    property bool roofBox: false
    readonly property real openingHeight: 2.10
    readonly property real vehicleHeight: profile.height + (roofBox ? 0.52 : 0)
    readonly property real heightMargin: openingHeight - vehicleHeight
    readonly property real widthMargin: (2.70 - profile.mirrorWidth) / 2
    // (6) Evidence history — 1 Hz samples, last 180 s
    property var hist: ({ speed: [], psiFR: [], motorTemp: [], attention: [], ttc: [], parkGap: [],
                          battery: [], trustCam: [], glance: [], temp: [] })
    property int _histTick: 0
    // (7) Drive-on budget
    property real leakRate: 0               // psi per minute (fitted)
    readonly property real minSafePsi: profile.psi - 12
    readonly property real driveOnKm: leakRate > 0.05 ? Math.max(0, (wheels[1].psi - minSafePsi) / leakRate) : -1   // at 60 km/h: 1 km per minute
    property real serviceKm: 9.2
    // (8) Alignment drift trend — steering bias per 100 km, last 12 blocks
    readonly property var alignHist: alignFault ? [0.04, 0.05, 0.04, 0.06, 0.08, 0.11, 0.15, 0.19, 0.24, 0.29, 0.34, 0.38]
                                                : [0.04, 0.05, 0.04, 0.05, 0.04, 0.05, 0.06, 0.05, 0.04, 0.05, 0.05, 0.04]
    // (9) Pack heat-map
    property bool weakModule: false
    readonly property var modules: {
        const out = []
        for (let i = 0; i < 12; i++) {
            const weak = weakModule && i === 7
            out.push({ t: batteryTemp + Math.sin(i * 1.7) * 0.8 + (i % 3) * 0.3 + (weak ? 6.5 : 0),
                       mv: 3720 + Math.round(Math.cos(i * 2.3) * 6) - (weak ? 42 : 0), weak: weak })
        }
        return out
    }
    // (10) Fault future — wear items projected on your own usage
    readonly property real dailyKm: 38
    readonly property var futureItems: [
        { name: "Front brake pads", now: "31 %", km: 3350, unit: "km" },
        { name: "Brake fluid moisture", now: "2.1 %", km: 5300, unit: "km" },
        { name: "12 V battery", now: "SoH 82 %", km: 9100, unit: "km" },
        { name: "FR tyre (leak)", now: wheels[1].psi.toFixed(1) + " psi", km: driveOnKm, unit: "km", live: true }
    ]
    // (11) Community hazards with confidence decay
    property var hazards: [
        { type: "Pothole",         dist: 820,  confirms: 3, age: 240 },
        { type: "Stalled vehicle", dist: 2400, confirms: 1, age: 900 },
        { type: "Oil on road",     dist: 5200, confirms: 5, age: 60 }
    ]
    function hazardConf(h) { return Math.min(1, h.confirms / 4) * Math.exp(-h.age / 1800) }
    // (12) Offline road memory
    property int memoryEvents: 11
    property int memoryToday: 2
    // (13) Monsoon wading check
    property real waterAt: 650
    property int waterDepth: 250
    property bool deepWater: false
    readonly property real waterDist: waterAt - odometer
    readonly property bool waterActive: weatherIndex === 1 && waterDist > -15 && waterDist < 400
    // (14) Glance budget
    property bool eyesOff: false
    property real glance: 0                 // rolling eyes-off-road seconds
    readonly property bool glanceExceeded: glance > 2.0
    // (15) Energy receipt (kWh this trip; seeded for the first 12.4 km)
    property real eAero: 0.62
    property real eRolling: 0.48
    property real eClimb: 0.21
    property real eHvac: 0.33
    property real eAccel: 0.29
    property real eRegen: 0.27
    property real eSaving80: 0.06           // what-if: kWh saved had speed been capped at 80 km/h
    property real grade: 0

    // ---------------------------------------------------------- environment
    property int weatherIndex: 0
    readonly property var weathers: [
        { name: "Clear", temp: 29, hum: 54, road: "DRY",      vis: 10 },
        { name: "Rain",  temp: 23, hum: 92, road: "WET",      vis: 3.5 },
        { name: "Fog",   temp: 17, hum: 97, road: "DAMP",     vis: 0.2 },
        { name: "Cold",  temp: 2,  hum: 71, road: "ICE RISK", vis: 8 }
    ]
    readonly property var weather: weathers[weatherIndex]
    function nextWeather() { weatherIndex = (weatherIndex + 1) % weathers.length }
    readonly property bool iceRisk: weather.temp <= 3
    readonly property int hour: now.getHours()
    readonly property bool lowBeam: weatherIndex === 1 || weatherIndex === 2 || hour >= 18 || hour < 6
    readonly property bool fogLamps: weatherIndex === 2
    readonly property bool wipers: weatherIndex === 1
    property real cabinTemp: 24.5
    property real cabinSet: 22
    property real batteryTemp: 31
    property real motorTemp: 52
    property real inverterTemp: 45

    // --------------------------------------------------------------- sensors
    readonly property var sensors: [
        { name: "LiDAR 360°",        range: weatherIndex === 2 ? "70 m" : "200 m",  health: Math.min(1, trustLidar + 0.03),
          note: weatherIndex === 2 ? "Reduced range (fog)" : "Nominal" },
        { name: "Front radar",       range: "210 m", health: 1,   note: "Nominal" },
        { name: "Corner radars ×4",  range: "80 m",  health: 1,   note: "BSM / RCTA active" },
        { name: "Front camera",      range: cameraBlocked ? "0 m" : "150 m", health: Math.min(1, trustCam + 0.03),
          note: cameraBlocked ? "BLOCKED — clean windscreen" : weatherIndex === 1 ? "Rain — wipers synced" : weatherIndex === 2 ? "Low visibility" : "Nominal" },
        { name: "Rear camera",       range: "25 m",  health: 1,   note: "Nominal" },
        { name: "Underbody camera",  range: "1.5 m", health: weatherIndex === 1 ? 0.8 : 1, note: weatherIndex === 1 ? "Spray detected" : "Nominal" },
        { name: "Ultrasonic ×12",    range: "5 m",   health: 1,   note: "Nominal" },
        { name: "GNSS + IMU",        range: "±0.3 m", health: 1,  note: "RTK fix" }
    ]

    // ----------------------------------------------------- scripted demo
    // A 200 s test drive that injects every scenario, so the read-only
    // cluster can be demonstrated hands-free. Toggle from the Signal Simulator.
    property bool scenario: true
    property real scnT: 0
    property real _scnPrev: 0
    property string scnPhase: "Highway cruise"
    function _at(t0) { return _scnPrev < t0 && scnT >= t0 }
    function runScenario(dt) {
        _scnPrev = scnT
        scnT += dt
        if (_at(1))   { weatherIndex = 0; cameraBlocked = false; tyreLeak = false; alignFault = false; weakModule = false
                        passengerBelted = true; doorOpenRL = false; eyesOff = false; attention = 100; roofBox = false; waterDepth = 250
                        autoDrive = true; brakeHeld = false; if (gear !== "D") requestGear("D"); scnPhase = "Highway cruise · adaptive cruise" }
        if (_at(15))  { indicator = 1;  scnPhase = "Lane change right · blind-spot check" }
        if (_at(28))  { indicator = -1; scnPhase = "Lane change left" }
        if (_at(40))  { weatherIndex = 1; scnPhase = "Monsoon rain · wading check · camera degraded" }
        if (_at(70))  { cameraBlocked = true;  scnPhase = "Camera blocked · lane assist hands back" }
        if (_at(80))  { cameraBlocked = false; tyreLeak = true; scnPhase = "Slow puncture FR · drive-on budget" }
        if (_at(100)) { weakModule = true; scnPhase = "Battery module drifting" }
        if (_at(112)) { tyreLeak = false; weakModule = false; weatherIndex = 0
                        obstacle = { type: "Rock", h: 230, at: odometer + 90 }; scnPhase = "Rock ahead · underbody strike predictor" }
        if (_at(132)) { attention = 25; scnPhase = "Driver drowsy · take a break" }
        if (_at(142)) { attention = 100; alignFault = true; scnPhase = "Alignment drift · pulling right" }
        if (_at(156)) { alignFault = false; brakeHeld = true; scnPhase = "Arriving · braking to stop" }
        if (_at(168)) { brakeHeld = false; requestGear("P"); scnPhase = "Parked" }
        if (_at(172)) { requestGear("R"); scnPhase = "Reversing into bay · pedestrian · rear auto-brake" }
        if (_at(190)) { requestGear("P"); scnPhase = "Parked · 360° view" }
        if (_at(196)) { requestGear("D"); autoDrive = true; scnPhase = "Pulling away" }
        if (scnT >= 200) { scnT = 0; _scnPrev = 0 }
    }

    // ------------------------------------------------------------ alerts
    // level: 3 critical (red), 2 warning (amber), 1 info (accent)
    property var alerts: []
    property string _flashText: ""
    property int _flashLevel: 2
    property real _flashUntil: 0
    function flash(t, level, secs) { _flashText = t; _flashLevel = level; _flashUntil = time + secs; slowStep() }

    // -------------------------------------------------------- navigation
    property var route: [
        { dir: "right",    road: "ORR Exit 1 · Gachibowli", dist: 640 },
        { dir: "straight", road: "Old Mumbai Highway",      dist: 2200 },
        { dir: "left",     road: "Cyber Towers Road",       dist: 900 },
        { dir: "arrive",   road: "HITEC City",              dist: 450 }
    ]
    readonly property string destination: "HITEC City"
    property int navIndex: 0
    property real navRemain: route[0].dist
    readonly property var nav: route[navIndex]
    readonly property real routeRemainKm: {
        let m = navRemain
        for (let i = navIndex + 1; i < route.length; i++) m += route[i].dist
        return m / 1000
    }

    // -------------------------------------------------------------- media
    property var tracks: [
        { title: "Neon Tide",       artist: "Kaiyo",           dur: 214 },
        { title: "Lidar Lullaby",   artist: "Points & Planes", dur: 187 },
        { title: "Monsoon Drive",   artist: "Aarav Rao",       dur: 242 },
        { title: "Afterglow",       artist: "Mira Ono",        dur: 199 }
    ]
    property int trackIndex: 0
    property real trackPos: 38
    property bool playing: true
    readonly property var track: tracks[trackIndex]
    function nextTrack() { trackIndex = (trackIndex + 1) % tracks.length; trackPos = 0 }
    function prevTrack() { trackIndex = (trackIndex + tracks.length - 1) % tracks.length; trackPos = 0 }

    // ------------------------------------------------------------- traffic
    // absolute lanes; z = metres ahead of ego centre (negative = behind)
    property var traffic: [
        { lane: -1, x: -3.6, z: 34,  v: 21.0 },
        { lane:  0, x:  0.0, z: 58,  v: 20.0 },
        { lane:  1, x:  3.6, z: 16,  v: 25.5 },
        { lane:  1, x:  3.6, z: 120, v: 19.0 },
        { lane: -1, x: -3.6, z: -16, v: 22.6 },
        { lane:  0, x:  0.0, z: -38, v: 19.8 }
    ]

    // ---------------------------------------------------------------- clock
    property date now: new Date()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: sim.now = new Date() }

    Timer {
        interval: 380; running: sim.indicator !== 0 || sim.hazard; repeat: true
        onTriggered: sim.blinkOn = !sim.blinkOn
        onRunningChanged: if (!running) sim.blinkOn = false
    }

    // ------------------------------------------------------------ commands
    function requestGear(g) {
        if (g === gear) return
        const moving = speed > 3
        if (moving && (g === "P" || g === "R" || (gear === "R" && g === "D"))) {
            flash("STOP THE VEHICLE TO SHIFT INTO " + g, 2, 2.5)
            return
        }
        if (g === "R") resetReverse()
        if (g === "R" || gear === "R") speed = 0
        gear = g
        targetSpeed = speed
        if (autoView) {
            if (g === "R") view = "rear"
            else if (view === "rear") view = "front"
        }
    }
    function cycleView() {
        const vs = ["front", "rear", "top", "under"]
        view = vs[(vs.indexOf(view) + 1) % vs.length]
    }
    function toggleIndicator(side) { indicator = indicator === side ? 0 : side }
    function resetReverse() { parkGap = 5.5; pedX = -5; _parkHold = 0; rearAeb = false }
    function driverInput() { attention = Math.min(100, attention + 20) }

    property real _indicatorTime: 0
    property bool _laneChanging: false
    onIndicatorChanged: _indicatorTime = 0

    // ----------------------------------------------------------- main loop
    property double _last: 0
    Timer { interval: 16; running: true; repeat: true; onTriggered: sim.step() }
    Timer { interval: 200; running: true; repeat: true; onTriggered: sim.slowStep() }

    function clamp(v, a, b) { return Math.max(a, Math.min(b, v)) }

    function step() {
        const nowMs = Date.now()
        if (_last === 0) { _last = nowMs; return }
        // real-time even when the frame rate drops (capped to avoid jumps)
        const dt = Math.min(0.25, (nowMs - _last) / 1000)
        _last = nowMs
        time += dt
        if (scenario) runScenario(dt)
        const v0 = speed / 3.6

        // ---------------- target speed per gear
        let maxA = mode === "sport" ? 24 : mode === "eco" ? 8 : 12
        let minA = -30
        if (gear !== "R") { rcta = false; rearAeb = false }
        if (gear === "P") {
            targetSpeed = 0; minA = -40
        } else if (gear === "N") {
            targetSpeed = Math.max(0, speed - 3)
            maxA = 0; minA = -1.5
        } else if (gear === "R") {
            pedX += 1.25 * dt
            const pedInPath = pedActive && Math.abs(pedX) < 1.8 && pedU < 3.4
            rcta = pedActive && pedU < 5
            // stop with margin: 0.40 m plus the distance needed to brake
            const wallStop = parkGap <= 0.45 + v0 * 0.3
            const fitStop = heightMargin < 0 && parkGap < 3.0          // (4) roof would hit the lintel
            rearAeb = pedInPath || wallStop || fitStop
            targetSpeed = rearAeb ? 0 : Math.min(rcta ? 2.5 : 6.5, Math.max(0, (parkGap - 0.4) * 3))
            maxA = 4; minA = -40
            if (wallStop) {
                _parkHold += dt
                if (_parkHold > 8) resetReverse()
            }
        } else { // D
            if (accelHeld) targetSpeed = Math.min(vmax, speed + 40)
            else if (brakeHeld) targetSpeed = Math.max(0, speed - 60)
            else if (autoDrive) {
                const base = mode === "sport" ? 98 : mode === "eco" ? 62 : 72
                let tgt = base + 16 * Math.sin(time / 11) + 7 * Math.sin(time / 4.3)
                tgt = Math.min(tgt, setSpeed + 4)
                if (weatherIndex === 1 || weatherIndex === 2) tgt = Math.min(tgt, weatherIndex === 2 ? 50 : 65)
                if (iceRisk) tgt = Math.min(tgt, 55)
                const follow = weatherIndex === 0 ? 34 : 48
                const lead = leadCar()
                if (lead && leadDistance < follow) tgt = Math.min(tgt, lead.v * 3.6 - (follow - leadDistance) * 1.2)
                // slow down for what the underbody camera sees ahead
                if (obstacleDist > 0 && obstacleDist < 40) {
                    if (underbodyRisk) tgt = Math.min(tgt, 12)
                    else if (obstacle.type === "Speed bump") tgt = Math.min(tgt, 25)
                    else if (obstacle.type === "Pothole") tgt = Math.min(tgt, 35)
                }
                targetSpeed = clamp(tgt, 0, vmax)
            }
            if (aeb) { const ld = leadCar(); targetSpeed = Math.min(targetSpeed, ld ? ld.v * 3.6 - 12 : speed - 30); minA = -45 }
            if (waterActive && waterDist < 40 && autoDrive)
                targetSpeed = Math.min(targetSpeed, waterDepth > profile.wading ? 0 : 15)   // (13)
        }

        // ---------------- longitudinal
        const gain = (gear === "R" && rearAeb) || aeb ? 12 : 1.4   // emergency braking is firm
        accel = clamp((targetSpeed - speed) * gain, minA, maxA)
        speed = Math.max(0, speed + accel * dt)
        const v = speed / 3.6

        // ---------------- energy
        const m = profile.mass
        grade = gear === "D" ? 0.035 * Math.sin(odometer / 420) : 0
        const aero = 0.5 * 1.225 * 0.3 * 2.4 * v * v * v
        const roll = 0.012 * m * 9.81 * v
        const climb = m * 9.81 * grade * v
        const drag = aero + roll + climb
        let p = (m * (accel / 3.6) * v + drag) / 1000
        p = clamp(p, -25 - regenLevel * 30, maxPower)
        power += (p - power) * Math.min(1, dt * 7)
        battery = Math.max(0, battery - power * dt / (profile.batt * 3600) * 100)
        if (speed > 5) {
            const inst = clamp(power / speed * 100, -40, 60)
            efficiency += (inst - efficiency) * Math.min(1, dt * 0.15)
        }
        // energy receipt (15)
        const h = dt / 3600
        eAero += aero / 1000 * h
        eRolling += roll / 1000 * h
        eClimb += Math.max(0, climb) / 1000 * h
        eHvac += 1.2 * h
        eAccel += Math.max(0, m * (accel / 3.6) * v) / 1000 * h
        eRegen += Math.max(0, -power) * h
        const v80 = Math.min(v, 80 / 3.6)
        eSaving80 += (aero - 0.5 * 1.225 * 0.3 * 2.4 * v80 * v80 * v80) / 1000 * h * (v80 < v ? v80 / v : 1)
        odometer += (gear === "R" ? -v : v) * dt
        tripKm += v * dt / 1000
        odoTotal += v * dt / 1000
        motorTemp += ((48 + Math.abs(power) * 0.22) - motorTemp) * dt * 0.05
        inverterTemp += ((40 + Math.abs(power) * 0.15) - inverterTemp) * dt * 0.05
        batteryTemp += ((weather.temp * 0.4 + 20 + Math.abs(power) * 0.05) - batteryTemp) * dt * 0.01
        cabinTemp += (cabinSet - cabinTemp) * dt * 0.02

        // ---------------- lateral
        if (gear === "D" || gear === "N") {
            if (indicator !== 0) {
                _indicatorTime += dt
                const want = egoLane + indicator
                if (!_laneChanging && _indicatorTime > 1.4 && speed > 20 && want >= -1 && want <= 1) {
                    const blocked = indicator < 0 ? bsLeft : bsRight
                    if (blocked || !laneFree(want)) {
                        if (!laneChangeBlocked) flash("BLIND SPOT — LANE CHANGE BLOCKED", 3, 2.2)
                        _blockedUntil = time + 2.2
                    } else {
                        egoLane = want
                        _laneChanging = true
                    }
                }
            }
            const d = egoLane * 3.6 - lateral
            lateral += d * Math.min(1, dt * 1.1)
            steer = clamp(d * 0.12, -0.4, 0.4) + (alignFault ? 0.03 : 0)
            if (_laneChanging && Math.abs(d) < 0.15) { _laneChanging = false; indicator = 0 }
        } else if (gear === "R") {
            steer = 0.38 * clamp((parkGap - 1.0) / 4, 0, 1)
            parkGap = Math.max(0.05, parkGap - v * dt)
        } else {
            steer *= 0.95
        }

        // ---------------- traffic
        if (gear !== "R") {
            let leadZ = -1, leadV = 0
            let bl = false, br = false
            for (let i = 0; i < traffic.length; i++) {
                const c = traffic[i]
                c.v += Math.sin(time * 0.3 + i * 1.7) * 0.25 * dt
                c.z += (c.v - v) * dt
                c.x += (c.lane * 3.6 - c.x) * Math.min(1, dt * 0.9)
                const rel = c.x - lateral
                const inEgoLane = Math.abs(rel) < 1.7
                if (inEgoLane && c.z > -7 && c.z < 9) {
                    const opts = [c.lane - 1, c.lane + 1].filter(l => l >= -1 && l <= 1 && l !== egoLane)
                    if (opts.length) c.lane = opts[0]
                }
                if (c.z > 190) { c.z = -58; c.v = 23 + Math.random() * 6 }
                if (c.z < -62) { c.z = 185; c.v = 15 + Math.random() * 6 }
                if (inEgoLane && c.z > 0 && (leadZ < 0 || c.z < leadZ)) { leadZ = c.z; leadV = c.v }
                if (c.z > -10 && c.z < 3) {
                    if (rel < -1.8 && rel > -5.6) bl = true
                    if (rel > 1.8 && rel < 5.6) br = true
                }
            }
            bsLeft = bl; bsRight = br
            leadDistance = leadZ > 0 ? leadZ - 4.6 : -1
            leadGapSec = leadZ > 0 && v > 1 ? leadDistance / v : 0
            const closing = v - leadV
            ttc = leadZ > 0 && closing > 0.5 ? leadDistance / closing : 99
            fcw = gear === "D" && speed > 15 && ttc < 2.6
            // AEB latches until time-to-collision is comfortably safe again
            aeb = gear === "D" && speed > 10 && (ttc < 1.3 || (aeb && ttc < 3.5))
        } else {
            bsLeft = false; bsRight = false; fcw = false; aeb = false
        }

        // ---------------- (1) sensor trust
        const wC = weatherIndex === 1 ? 0.72 : weatherIndex === 2 ? 0.48 : 0.97
        const wL = weatherIndex === 2 ? 0.58 : weatherIndex === 1 ? 0.9 : 0.98
        trustCam += ((cameraBlocked ? 0.12 : wC + 0.02 * Math.sin(time * 1.3)) - trustCam) * Math.min(1, dt * 1.5)
        trustRadar += ((0.97 + 0.02 * Math.sin(time * 0.7)) - trustRadar) * Math.min(1, dt * 1.5)
        trustLidar += ((wL + 0.015 * Math.sin(time * 0.9)) - trustLidar) * Math.min(1, dt * 1.5)

        // ---------------- (2) takeover countdown
        if (cameraBlocked && _camBlockedAt < 0) _camBlockedAt = time
        if (!cameraBlocked) _camBlockedAt = -1
        if (gear === "D" && speed > 20) {
            if (_camBlockedAt >= 0) takeoverIn = Math.max(0, 6 - (time - _camBlockedAt))
            else if (laneGapDist > 0 && laneGapDist < 350) takeoverIn = laneGapDist / Math.max(1, v)
            else takeoverIn = -1
        } else takeoverIn = -1
        if (odometer > laneGapAt + laneGapLen + 50) laneGapAt = odometer + 1300 + Math.random() * 600

        // ---------------- (3) escape path
        escapeLane = 0
        if (gear === "D" && (fcw || (leadDistance > 0 && leadDistance < 14 && speed > 25))) {
            for (const side of [1, -1]) {
                const lane = egoLane + side
                if (lane < -1 || lane > 1) continue
                let free = true
                for (const c of traffic) if (Math.abs(c.x - lane * 3.6) < 1.8 && c.z > -6 && c.z < 30) free = false
                if (free) { escapeLane = side; break }
            }
        }

        // ---------------- (11) hazards age, approach and get re-confirmed
        if (gear === "D") {
            const hz = hazards
            for (const hh of hz) {
                hh.dist -= v * dt; hh.age += dt
                if (hh.dist < -10) { hh.dist = 3000 + Math.random() * 4000; hh.confirms = 1 + Math.floor(Math.random() * 5); hh.age = Math.random() * 1500 }
            }
        }

        // ---------------- (13) water ahead in rain
        if (weatherIndex === 1 && waterDist < -20) { waterAt = odometer + 700 + Math.random() * 500 }
        if (weatherIndex !== 1 && waterDist < 400) waterAt = odometer + 600
        // ---------------- (14) glance budget
        glance = eyesOff ? Math.min(5, glance + dt) : Math.max(0, glance - dt * 1.5)
        serviceKm = Math.max(0.3, serviceKm - (gear === "D" ? v * dt / 1000 : 0))

        // ---------------- underbody obstacle cycle
        if (obstacleDist < -8) {
            let o
            if (rockAhead) { o = { type: "Rock", h: 230 }; rockAhead = false }
            else { o = _obsTypes[_obsIdx % _obsTypes.length]; _obsIdx++ }
            obstacle = { type: o.type, h: o.h, at: odometer + 120 + Math.random() * 80 }
            memoryEvents++; memoryToday++                                  // (12) learned offline
        }

        absActive = (brakeHeld && speed > 25) || aeb || (iceRisk && accel < -15)
        espActive = ((weatherIndex === 1 || iceRisk) && accel > 7) || (mode === "sport" && accel > 18)

        // ---------------- driver attention (drowsiness demo)
        if (gear === "D" && speed > 30) attention = Math.max(0, attention - dt * 0.25)

        // ---------------- nav
        if (gear === "D") {
            navRemain -= v * dt
            if (navRemain <= 0) { navIndex = (navIndex + 1) % route.length; navRemain = route[navIndex].dist }
            speedLimit = navIndex === 1 ? 100 : 80
        }

        // ---------------- media
        if (playing) { trackPos += dt; if (trackPos >= track.dur) nextTrack() }
    }

    // 5 Hz: tyres, alignment and the prioritised alert list
    function slowStep() {
        // tyres
        const base = profile.psi
        if (tyreLeak) _leakPsi = Math.max(base - 13, _leakPsi - 0.008)   // ~2.4 psi/min
        else _leakPsi = base
        const toe0 = [0.05, -0.04, 0.08, 0.07], cam0 = [-0.6, -0.55, -0.9, -0.85], ids = ["FL", "FR", "RL", "RR"]
        const w = []
        for (let i = 0; i < 4; i++) {
            let psi = base + 0.3 * Math.sin(time * 0.1 + i) + speed * 0.008
            if (i === 1 && tyreLeak) psi = _leakPsi
            let toe = toe0[i] + 0.01 * Math.sin(time * 0.7 + i)
            if (i === 0 && alignFault) toe = 0.38 + 0.01 * Math.sin(time)
            w.push({ id: ids[i], psi: psi, temp: 26 + speed * 0.09 + weather.temp * 0.12 + i * 0.4,
                     toe: toe, camber: cam0[i] + 0.01 * Math.cos(time * 0.5 + i) })
        }
        wheels = w

        hazards = hazards.slice()        // notify cards (objects are mutated in step)

        // (6) evidence history at 1 Hz
        _histTick++
        if (_histTick % 5 === 0) {
            const hs = hist
            function push(k, val) { const a = hs[k]; a.push(val); if (a.length > 180) a.shift() }
            push("speed", speed); push("psiFR", w[1].psi); push("motorTemp", motorTemp); push("attention", attention)
            push("ttc", Math.min(10, ttc)); push("parkGap", parkGap); push("battery", battery)
            push("trustCam", trustCam * 100); push("glance", glance); push("temp", weather.temp)
            hist = hs
            // (7) leak rate = least-squares slope of the last 30 s of FR pressure, psi/min
            const a = hs.psiFR, n = Math.min(30, a.length)
            if (n > 5) {
                let sx = 0, sy = 0, sxy = 0, sxx = 0
                for (let i = 0; i < n; i++) { const y = a[a.length - n + i]; sx += i; sy += y; sxy += i * y; sxx += i * i }
                const slope = (n * sxy - sx * sy) / (n * sxx - sx * sx)
                leakRate = Math.max(0, -slope * 60)
            }
        }

        // alerts
        const a = []
        if (time < _flashUntil) a.push({ level: _flashLevel, text: _flashText })
        if (aeb) a.push({ level: 3, text: "AUTO EMERGENCY BRAKING", sig: "ttc" })
        else if (fcw) a.push({ level: 3, text: "FORWARD COLLISION WARNING — BRAKE" + (escapeLane ? (escapeLane > 0 ? " · ESCAPE GAP RIGHT" : " · ESCAPE GAP LEFT") : ""), sig: "ttc" })
        if (gear === "R" && heightMargin < 0)
            a.push({ level: 3, text: "WILL NOT FIT · ROOF " + Math.round(-heightMargin * 100) + " cm TOO TALL FOR " + openingHeight.toFixed(2) + " m OPENING" })
        if (takeoverIn >= 0)
            a.push({ level: takeoverIn < 4 ? 3 : 2, sig: "trustCam",
                     text: "LANE ASSIST HANDS BACK IN " + Math.ceil(takeoverIn) + " s · " + (_camBlockedAt >= 0 ? "CAMERA BLOCKED" : "MARKINGS END IN " + Math.round(laneGapDist) + " m") })
        if (glanceExceeded && gear === "D") a.push({ level: 2, text: "EYES ON ROAD · NON-ESSENTIAL INFO HIDDEN", sig: "glance" })
        if (waterActive) a.push({ level: waterDepth > profile.wading ? 3 : 2,
                                 text: waterDepth > profile.wading ? "WATER " + waterDepth + " mm > WADING LIMIT " + profile.wading + " mm · TURN BACK"
                                                                  : "WATER AHEAD " + Math.round(waterDist) + " m · " + waterDepth + " mm · LIMIT " + profile.wading + " mm · ≤15 km/h" })
        for (const hh of hazards) if (gear === "D" && hh.dist > 0 && hh.dist < 350 && hazardConf(hh) > 0.15)
            a.push({ level: 1, text: "COMMUNITY HAZARD · " + hh.type.toUpperCase() + " " + Math.round(hh.dist) + " m · " + hh.confirms + " CARS · " + Math.round(hh.age / 60) + " MIN AGO" })
        if (gear === "R" && rearAeb)
            a.push({ level: 3, sig: "parkGap", text: pedActive && Math.abs(pedX) < 1.7 ? "REAR AUTO-BRAKE · PEDESTRIAN BEHIND"
                                                                       : "REAR AUTO-BRAKE · OBJECT " + parkGap.toFixed(2) + " m" })
        else if (rcta) a.push({ level: 2, text: "REAR CROSS TRAFFIC · PEDESTRIAN" })
        if (!passengerBelted && speed > 10) a.push({ level: 3, text: "FASTEN SEATBELT · FRONT PASSENGER" })
        if (doorOpenRL) a.push({ level: speed > 3 ? 3 : 2, text: "DOOR OPEN · REAR LEFT" })
        if (underbodyRisk && gear === "D")
            a.push({ level: 2, text: "UNDERBODY RISK · " + obstacle.type.toUpperCase() + " " + obstacle.h + " mm · CLEARANCE " + Math.round(effClearance) + " mm · STEER AROUND" })
        for (const wh of wheels) if (wh.psi < base - 4)
            a.push({ level: 2, sig: "psiFR", text: "LOW TYRE " + wh.id + " " + wh.psi.toFixed(1) + " psi" +
                     (driveOnKm >= 0 ? " · SAFE ~" + Math.round(driveOnKm) + " km AT ≤60 · SHOP " + serviceKm.toFixed(1) + " km" : "") })
        if (alignFault) a.push({ level: 2, text: "WHEEL ALIGNMENT DRIFT · FL TOE +0.38° · PULLING RIGHT" })
        if (attention < 35) a.push({ level: 2, sig: "attention", text: "DRIVER ATTENTION LOW · TAKE A BREAK" })
        if (iceRisk) a.push({ level: 2, sig: "temp", text: "ICE RISK · " + weather.temp + "°C OUTSIDE" })
        if (battery < 15) a.push({ level: 2, sig: "battery", text: "LOW BATTERY · CHARGE SOON" })
        if (motorTemp > 110) a.push({ level: 2, sig: "motorTemp", text: "MOTOR TEMPERATURE HIGH · POWER LIMITED" })
        if (weakModule) a.push({ level: 2, text: "BATTERY MODULE 8 · +6.5°C / −42 mV vs PACK · SERVICE CHECK" })
        if (trustCam < 0.6 && takeoverIn < 0 && gear === "D") a.push({ level: 1, sig: "trustCam", text: "CAMERA CONFIDENCE " + Math.round(trustCam * 100) + " % · ADAS DEGRADED" })
        if (bsLeft && indicator === -1 || bsRight && indicator === 1)
            a.push({ level: 2, text: "VEHICLE IN BLIND SPOT" })
        if (gear === "D" && obstacleDist > 0 && obstacleDist < 40 && !underbodyRisk)
            a.push({ level: 1, text: obstacle.type.toUpperCase() + " AHEAD · " + Math.round(obstacleDist) + " m · CLEARANCE OK" })
        if (weatherIndex === 1 && gear === "D") a.push({ level: 1, text: "WET ROAD · FOLLOWING GAP INCREASED" })
        if (weatherIndex === 2 && gear === "D") a.push({ level: 1, text: "LOW VISIBILITY · FOG LAMPS ON · SPEED CAPPED" })
        if (gear === "D" && speed > speedLimit + 3) a.push({ level: 1, text: "SPEED LIMIT " + speedLimit })
        a.sort((p, q) => q.level - p.level)
        alerts = a
    }

    function leadCar() {
        let best = null
        for (const c of traffic)
            if (Math.abs(c.x - lateral) < 1.7 && c.z > 0 && (!best || c.z < best.z)) best = c
        return best
    }
    function laneFree(lane) {
        for (const c of traffic)
            if (c.lane === lane && c.z > -10 && c.z < 12) return false
        return true
    }
}
