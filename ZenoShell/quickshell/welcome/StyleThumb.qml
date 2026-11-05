import QtQuick
import qs.theme
import qs.services

// A drawn miniature of a shell style
Rectangle {
    id: root

    property string kind: "island"        // island | classic | dash | side
    property string label: ""
    property string hint: ""
    property bool selected: false
    signal clicked()

    width: 224
    height: 190
    radius: 20
    color: mouse.containsMouse ? Theme.islandHover : Theme.surfaceSoft
    border.width: selected ? 2 : 1
    border.color: selected ? Theme.accent : Theme.border
    scale: selected ? 1.0 : 0.97
    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
    Behavior on color { ColorAnimation { duration: 120 } }

    // the "screen"
    Rectangle {
        id: scr
        x: 12; y: 12
        width: parent.width - 24
        height: 112
        radius: 12
        clip: true
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.mix(Theme.island, Theme.accent, 0.32) }
            GradientStop { position: 1; color: Theme.mix(Theme.island, Theme.accent, 0.08) }
        }

        // island: three little pills
        Row {
            visible: root.kind === "island"
            x: 10; y: 8; spacing: 6
            Rectangle { width: 38; height: 9; radius: 4.5; color: Theme.island }
            Rectangle { width: 54; height: 9; radius: 4.5; color: Theme.island }
            Rectangle { width: 38; height: 9; radius: 4.5; color: Theme.island }
        }

        // classic: a bar across the whole width
        Rectangle {
            visible: root.kind === "classic"
            x: 6; y: 6; width: parent.width - 12; height: 11; radius: 5.5
            color: Theme.island
            Rectangle { x: 8; anchors.verticalCenter: parent.verticalCenter; width: 14; height: 5; radius: 2.5; color: Theme.accent }
            Rectangle { anchors.centerIn: parent; width: 30; height: 5; radius: 2.5; color: Theme.foreground; opacity: 0.7 }
        }

        // dashboard: one pill (or a bar fused with the edge)
        Rectangle {
            visible: root.kind === "dash"
            anchors.horizontalCenter: parent.horizontalCenter
            y: Style.dashVariant === "attached" ? -6 : 7
            width: 92; height: Style.dashVariant === "attached" ? 25 : 12
            radius: 8
            color: Theme.island
            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: Style.dashVariant === "attached" ? 12 : 3.5; width: 40; height: 5; radius: 2.5; color: Theme.foreground; opacity: 0.7 }
        }

        // vertical: bar on the left and a thin frame
        Item {
            visible: root.kind === "side"
            anchors.fill: parent
            Rectangle { x: 0; y: 0; width: 15; height: parent.height; color: Theme.island }
            Rectangle { x: 0; y: 0; width: parent.width; height: 4; color: Theme.island }
            Rectangle { x: 0; y: parent.height - 4; width: parent.width; height: 4; color: Theme.island }
            Rectangle { x: parent.width - 4; y: 0; width: 4; height: parent.height; color: Theme.island }
            Rectangle { x: 4; y: 12; width: 7; height: 7; radius: 3.5; color: Theme.accent }
            Rectangle { x: 4; y: 24; width: 7; height: 7; radius: 3.5; color: Theme.foreground; opacity: 0.6 }
        }

        // a window, so it looks like a desktop
        Rectangle {
            x: root.kind === "side" ? 30 : 28; y: 38; width: 90; height: 56; radius: 7
            color: Theme.island; opacity: 0.85
            Rectangle { x: 8; y: 8; width: 40; height: 4; radius: 2; color: Theme.foreground; opacity: 0.5 }
            Rectangle { x: 8; y: 17; width: 62; height: 4; radius: 2; color: Theme.foreground; opacity: 0.25 }
        }
    }

    Text {
        x: 14
        y: 134
        text: root.label
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: 14
        font.bold: true
    }

    Text {
        x: 14
        y: 156
        width: parent.width - 28
        text: root.hint
        elide: Text.ElideRight
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 11
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
