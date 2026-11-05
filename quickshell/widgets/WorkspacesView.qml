import QtQuick
import Quickshell
import qs.theme
import qs.services

Item {
    id: root

    property string screenName: ""

    // ---- Dimensioni (modificale qui) ----
    readonly property int cell: 24        // width of each number
    readonly property int gap: 4          // space between the numbers
    readonly property int pad: 14         // margine ai lati
    readonly property int fontSize: 12

    readonly property var ids: Workspaces.idsFor(screenName)
    readonly property int count: Math.max(2, ids.length)

    // The "shown" workspace: starts from the old one and slides to the new one
    property int shownId: Workspaces.currentId

    implicitWidth: count * cell + (count - 1) * gap + pad * 2
    implicitHeight: Theme.islandHeight

    function indexOfId(id) {
        for (let i = 0; i < ids.length; i++) if (ids[i] === id) return i
        return -1
    }

    function restart() {
        shownId = Workspaces.previousId
        slideTimer.restart()
    }

    Timer {
        id: slideTimer
        interval: 120
        onTriggered: root.shownId = Workspaces.currentId
    }

    Connections {
        target: Workspaces
        function onFlashSerialChanged() { root.restart() }
    }

    HoverHandler {
        onHoveredChanged: Workspaces.paused = hovered
    }

    // Rotella: workspace successivo / precedente
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => {
            Compositor.focusWorkspaceRelative(wheel.angleDelta.y > 0 ? -1 : 1)
        }
    }

    // Sliding highlight
    Rectangle {
        readonly property int idx: root.indexOfId(root.shownId)

        visible: idx >= 0
        x: root.pad + Math.max(0, idx) * (root.cell + root.gap)
        y: (root.implicitHeight - root.cell) / 2
        width: root.cell
        height: root.cell
        radius: root.cell / 2
        color: Theme.accent

        Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    }

    Repeater {
        model: root.ids

        delegate: Item {
            id: cellItem

            required property int modelData
            required property int index

            readonly property bool current: modelData === root.shownId

            x: root.pad + index * (root.cell + root.gap)
            y: (root.implicitHeight - root.cell) / 2
            width: root.cell
            height: root.cell

            Text {
                anchors.centerIn: parent
                text: cellItem.modelData
                color: cellItem.current ? Theme.island : Theme.foreground
                opacity: cellItem.current ? 1 : 0.7
                font.family: Theme.fontFamily
                font.pixelSize: root.fontSize
                font.bold: cellItem.current
                Behavior on color { ColorAnimation { duration: 160 } }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Compositor.focusWorkspace(cellItem.modelData)
            }
        }
    }
}
