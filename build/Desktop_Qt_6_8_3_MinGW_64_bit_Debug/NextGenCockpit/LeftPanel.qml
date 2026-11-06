import QtQuick

// Left card deck: DRIVE · SAFETY · SENSORS · ROAD   (Q cycles, or click a tab)
Item {
    id: deck
    property var sim
    property var theme
    property int index: 0
    width: 272
    height: 500
    function next() { index = (index + 1) % 4 }

    DeckTabs {
        theme: deck.theme
        titles: ["DRIVE", "SAFETY", "SENSORS", "ROAD"]
        spacing: 14
        index: deck.index
        onPicked: (i) => deck.index = i
    }

    Item {
        y: 34
        width: parent.width
        height: parent.height - 34
        CardDrive   { sim: deck.sim; theme: deck.theme; opacity: deck.index === 0 ? 1 : 0; visible: opacity > 0
                      Behavior on opacity { NumberAnimation { duration: 260 } } }
        CardSafety  { sim: deck.sim; theme: deck.theme; opacity: deck.index === 1 ? 1 : 0; visible: opacity > 0
                      Behavior on opacity { NumberAnimation { duration: 260 } } }
        CardSensors { sim: deck.sim; theme: deck.theme; opacity: deck.index === 2 ? 1 : 0; visible: opacity > 0
                      Behavior on opacity { NumberAnimation { duration: 260 } } }
        CardRoad    { sim: deck.sim; theme: deck.theme; opacity: deck.index === 3 ? 1 : 0; visible: opacity > 0
                      Behavior on opacity { NumberAnimation { duration: 260 } } }
    }
}
