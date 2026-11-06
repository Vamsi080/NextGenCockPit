import QtQuick

// Right card deck: NAV · VEHICLE · HEALTH · ENERGY   (E cycles, or click a tab)
Item {
    id: deck
    property var sim
    property var theme
    property int index: 0
    width: 272
    height: 500
    signal evidence(string sig, string headline)
    function next() { index = (index + 1) % 4 }

    DeckTabs {
        anchors.right: parent.right
        theme: deck.theme
        titles: ["NAV", "VEHICLE", "HEALTH", "ENERGY"]
        spacing: 14
        index: deck.index
        onPicked: (i) => deck.index = i
    }

    Item {
        y: 34
        width: parent.width
        height: parent.height - 34
        CardNavMedia { sim: deck.sim; theme: deck.theme; opacity: deck.index === 0 ? 1 : 0; visible: opacity > 0
                       Behavior on opacity { NumberAnimation { duration: 260 } } }
        CardVehicle  { sim: deck.sim; theme: deck.theme; opacity: deck.index === 1 ? 1 : 0; visible: opacity > 0
                       Behavior on opacity { NumberAnimation { duration: 260 } } }
        CardHealth   { sim: deck.sim; theme: deck.theme; opacity: deck.index === 2 ? 1 : 0; visible: opacity > 0
                       onEvidence: (s, h) => deck.evidence(s, h)
                       Behavior on opacity { NumberAnimation { duration: 260 } } }
        CardEnergy   { sim: deck.sim; theme: deck.theme; opacity: deck.index === 3 ? 1 : 0; visible: opacity > 0
                       Behavior on opacity { NumberAnimation { duration: 260 } } }
    }
}
