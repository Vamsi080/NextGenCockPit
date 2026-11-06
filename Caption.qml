import QtQuick

Text {
    property var theme
    color: theme ? theme.sub : "#8A99A8"
    font.family: theme ? theme.face : "Segoe UI"
    font.pixelSize: 11
    font.weight: Font.DemiBold
    font.letterSpacing: 3
}
