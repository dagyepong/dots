import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import QtQuick.VectorImage




RowLayout {
    height: 100
    Layout.margins: 1
    spacing: 16

    Rectangle {
        id: shutdown_button
        radius: 22
        Layout.preferredHeight: 60
        Layout.preferredWidth: 104
        Layout.fillWidth: true
        color: "#000000"
        border.color: "#333333"
        border.width: 1
        HoverHandler {
            id: shutdown_hover
            onHoveredChanged: {
                shutdown_button.color = shutdown_hover.hovered ? "#333333" : "#000000"
            }
        }
        TapHandler{
            onTapped: Quickshell.execDetached(["systemctl", "poweroff"])
        }

        Behavior on color {
            ColorAnimation{duration:250;easing.type: Easing.OutCubic}
        }
        VectorImage {
            id: shutdown_icon
            anchors.centerIn: parent
            source: "shutdown.svg"
            width: 25
            height: 25
            preferredRendererType: VectorImage.CurveRenderer
        }
    }


    Rectangle {
        id: reboot_button
        radius: 22
        Layout.preferredHeight: 60
        Layout.preferredWidth: 104
        Layout.fillWidth: true
        color: "#000000"
        border.color: "#333333"
        border.width: 1
        HoverHandler {
            id: reboot_hover
            onHoveredChanged: {
                reboot_button.color = reboot_hover.hovered ? "#333333" : "#000000"
            }
        }
        TapHandler{
            onTapped: Quickshell.execDetached(["systemctl", "reboot"])
        }

        Behavior on color {
            ColorAnimation{duration:250;easing.type: Easing.OutCubic}
        }
        VectorImage {
            id: reboot_icon
            anchors.centerIn: parent
            source: "reboot.svg"
            width: 25
            height: 25
            preferredRendererType: VectorImage.CurveRenderer
        }
    }

    Rectangle {
        id: sleep_button
        radius: 22
        Layout.preferredHeight: 60
        Layout.preferredWidth: 104
        Layout.fillWidth: true
        color: "#000000"
        border.color: "#333333"
        border.width: 1
        HoverHandler {
            id: sleep_hover
            onHoveredChanged: {
                sleep_button.color = sleep_hover.hovered ? "#333333" : "#000000"
            }
        }
        TapHandler{
            onTapped: Quickshell.execDetached(["systemctl", "sleep"])
        }

        Behavior on color {
            ColorAnimation{duration:250;easing.type: Easing.OutCubic}
        }

        VectorImage {
            id: sleep_icon
            anchors.centerIn: parent
            source: "sleep.svg"
            width: 25
            height: 25
            preferredRendererType: VectorImage.CurveRenderer
        }
    }
}
