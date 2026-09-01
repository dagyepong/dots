import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Pipewire

Item {
    id: root
    implicitWidth: 300
    implicitHeight: 35

    property alias value: slider.value

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }
    anchors.margins: 16

    Slider {
        id: slider
        anchors.fill: parent
        from: 0.0
        to: 1.25

        background: ClippingRectangle {
                id: volume_slider_outer_rectangle
                x: slider.leftPadding
                y: slider.topPadding + slider.availableHeight / 2 - height / 2

                width: slider.availableWidth
                height: parent.height
                radius: height / 2
                color: "#000000"
                border.color: "#333333"
                border.width: 1

                Rectangle {
                    id: volume_slider_inner_rectangle
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.margins: 3
                    width: slider.visualPosition * parent.width - 6
                    height: parent.height - 6
                    radius: height / 2
                    color: "#000000"
                    Behavior on width {
                        NumberAnimation{duration: 250; easing.type: Easing.OutCubic}
                    }
                    Behavior on color {
                        ColorAnimation{duration:250;easing.type: Easing.OutCubic}
                    }
                }

                HoverHandler {
                    onHoveredChanged: {
                        volume_slider_outer_rectangle.border.color = hovered ? "#888888" : "#333333"
                        volume_slider_inner_rectangle.color = hovered ? "#ffffff" : "#000000"
                        volume_value.color = hovered ? "#888888" : "#ffffff"
                        volume_value.anchors.leftMargin = hovered ? 150 : 16
                        volume_icon.opacity = hovered ? 1 : 0
                    }
                }
            }

        handle: null
        value: Pipewire.defaultAudioSink?.audio.volume ?? 0

        onMoved: {
            if (Pipewire.defaultAudioSink?.ready)
                Pipewire.defaultAudioSink.audio.volume = value
        }
    }
}
