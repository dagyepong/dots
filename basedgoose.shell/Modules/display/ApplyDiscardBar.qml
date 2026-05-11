import QtQuick 6.10
import QtQuick.Layouts 6.10
import "../../Commons" as Commons

RowLayout {
    id: root

    readonly property color cText: Commons.Theme.foreground
    readonly property color cSurfaceContainer: Qt.lighter(Commons.Theme.background, 1.15)
    readonly property color cPrimary: Commons.Theme.secondary
    readonly property color cBorder: Qt.rgba(cText.r, cText.g, cText.b, 0.08)

    signal discardClicked
    signal applyClicked

    spacing: 12

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 44
        radius: Commons.Theme.radius
        color: discardArea.containsMouse ? Qt.rgba(cText.r, cText.g, cText.b, 0.1) : cSurfaceContainer
        border.color: cBorder
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: "Discard"
            font.family: Commons.Theme.fontUI
            font.pixelSize: 13
            font.weight: Font.Medium
            color: cText
        }

        MouseArea {
            id: discardArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.discardClicked()
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 44
        radius: Commons.Theme.radius
        color: applyArea.containsMouse ? Qt.lighter(cPrimary, 1.1) : cPrimary

        RowLayout {
            anchors.centerIn: parent
            spacing: 8

            Text {
                text: "󰄬"
                font.family: Commons.Theme.fontIcon
                font.pixelSize: 16
                color: Commons.Theme.background
            }

            Text {
                text: "Apply Changes"
                font.family: Commons.Theme.fontUI
                font.pixelSize: 13
                font.weight: Font.Medium
                color: Commons.Theme.background
            }
        }

        MouseArea {
            id: applyArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.applyClicked()
        }
    }
}
