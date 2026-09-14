// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   N O T I F I C A T I O N   L A Y E R                                    │
// │   an arriving notification · icon, summary and body                      │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

import Quickshell.Services.Notifications

import "../../theme"
import "../../services"
import "../../components"

// The island while a notification is shown: two lines, no buttons.
RowLayout {
    id: root

    readonly property var notification: NotificationService.current
    readonly property bool critical: NotificationService.critical

    spacing: 11

    // The notification's image, else the app's icon, else a dot.
    ClippingRectangle {
        Layout.preferredWidth: 38
        Layout.preferredHeight: 38
        Layout.alignment: Qt.AlignVCenter
        radius: width * Theme.pictureCorner
        color: root.critical ? Theme.red : Theme.islandSurfaceHover

        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

        Image {
            id: image
            anchors.fill: parent
            source: root.notification ? (root.notification.image ?? "") : ""
            visible: source != "" && status === Image.Ready
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 76
            sourceSize.height: 76
        }

        Text {
            anchors.centerIn: parent
            visible: !image.visible
            text: root.critical ? "󰀪" : "󰂚"
            font.family: Theme.fontMono
            font.pixelSize: 17
            color: root.critical ? Theme.accentText : Theme.accent
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: 1

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                Layout.fillWidth: true
                text: root.notification ? root.notification.summary : ""
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
                color: Theme.text
            }

            Text {
                text: root.notification ? root.notification.appName : ""
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: 9
                color: root.critical ? Theme.red : Theme.textMuted
            }
        }

        Text {
            Layout.fillWidth: true
            visible: text !== ""
            text: root.notification ? (root.notification.body ?? "") : ""
            // Applications send Pango markup and the server advertises support
            // for it, so it has to be rendered rather than shown as tags.
            textFormat: Text.StyledText
            elide: Text.ElideRight
            maximumLineCount: 1
            font.family: Theme.fontFamily
            font.pixelSize: 10
            color: Theme.textMuted
        }
    }

    IconButton {
        Layout.alignment: Qt.AlignVCenter
        icon: "󰅖"
        iconSize: 12
        onClicked: NotificationService.close()
    }
}
