import QtQuick
import qs.theme
import qs.services

// Workspace pill of the classic bar: dots, the active one stretches
Rectangle {
    id: root

    property string screenName: ""

    readonly property var dots: Compositor.dotsFor(screenName)
    readonly property int activeId: Compositor.activeIdFor(screenName)

    height: Theme.islandHeight
    width: row.implicitWidth + 26
    radius: height / 2
    color: Theme.island
    border.width: 1
    border.color: Theme.border

    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            if (wheelCool.running) return
            Compositor.focusWorkspaceRelative(event.angleDelta.y > 0 ? -1 : 1)
            wheelCool.start()
        }
    }

    Timer {
        id: wheelCool
        interval: 150
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 7

        Repeater {
            model: root.dots

            delegate: Rectangle {
                id: dot

                required property var modelData
                readonly property bool active: modelData.id === root.activeId

                width: active ? 38 : 10
                height: 10
                radius: 5
                anchors.verticalCenter: parent.verticalCenter
                color: active ? Theme.accent
                       : (modelData.occupied ? Theme.foreground : Theme.mix(Theme.island, Theme.foreground, 0.20))

                Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 160 } }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Compositor.focusWorkspace(dot.modelData.id)
                }
            }
        }
    }
}
