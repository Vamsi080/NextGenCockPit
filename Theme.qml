import QtQuick

// Mode-driven palette. ECO = mint, COMFORT = azure, SPORT = ember,
// reverse gear = violet. Colours glide between states.
Item {
    id: theme
    visible: false

    property string mode: "comfort"
    property string gear: "D"
    readonly property string key: gear === "R" ? "rev" : mode

    property color accent:  key === "sport" ? "#FF5233" : key === "rev" ? "#B48CFF" : key === "eco" ? "#2EE6A6" : "#4DA3FF"
    property color accent2: key === "sport" ? "#FFC247" : key === "rev" ? "#5ED8FF" : key === "eco" ? "#36C9F1" : "#36F1D6"
    Behavior on accent  { ColorAnimation { duration: 900; easing.type: Easing.InOutQuad } }
    Behavior on accent2 { ColorAnimation { duration: 900; easing.type: Easing.InOutQuad } }

    readonly property color bg:     "#03050A"
    readonly property color panel:  "#070B12"
    readonly property color text:   "#EAF2F7"
    readonly property color sub:    "#A3B1BF"
    readonly property color dim:    "#6B7A88"
    readonly property color line:   "#223040"
    readonly property color warn:   "#FFB23F"
    readonly property color danger: "#FF3355"
    readonly property color good:   "#3DFFA2"
    readonly property color beam:   "#3D8BFF"

    readonly property string face: "Segoe UI"
    readonly property string modeTitle: key === "rev" ? "REVERSE ASSIST" : mode.toUpperCase()

    function levelColor(l) { return l >= 3 ? danger : l === 2 ? warn : accent }

    function css(c, a) {
        return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + ","
                + Math.round(c.b * 255) + "," + (a === undefined ? 1 : a) + ")"
    }
    function mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1)
    }
}
