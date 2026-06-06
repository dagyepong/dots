import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../core"
import "../../services"

PanelWindow {
    id: root

    visible: GlobalStates.launcherOpen || (content && content.opacity > 0)
    anchors { left: true; right: true; top: true; bottom: true }

    WlrLayershell.namespace: "quickshell:launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: GlobalStates.launcherOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    HyprlandFocusGrab {
        id: grab
        windows: [root]
        active: GlobalStates.launcherOpen
    }

    color: "transparent"

    onVisibleChanged: {
        if (visible) LauncherSearch.query = "";
    }

    readonly property var screenData: Quickshell.screens[0]
    readonly property real screenWidth: screenData ? screenData.width : 1920
    readonly property real screenHeight: screenData ? screenData.height : 1080

    MouseArea {
        anchors.fill: parent
        onClicked: GlobalStates.launcherOpen = false
    }

    LauncherContent {
        id: content
        width: Math.min(root.screenWidth * 0.92, 780 * Appearance.effectiveScale)
        height: Math.min(root.screenHeight * 0.84, 720 * Appearance.effectiveScale)
        anchors.centerIn: parent
        opacity: 0
        scale: 0.92
        focus: true
        transformOrigin: Item.Center

        states: [
            State {
                name: "active"
                when: GlobalStates.launcherOpen
                PropertyChanges {
                    target: content
                    opacity: 1
                    scale: 1
                }
            }
        ]

        transitions: [
            Transition {
                from: ""
                to: "active"
                ParallelAnimation {
                    NumberAnimation {
                        properties: "opacity,scale"
                        duration: Appearance.animation.elementMove.duration
                        easing.type: Appearance.animation.elementMove.type
                        easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                    }
                }
            },
            Transition {
                from: "active"
                to: ""
                ParallelAnimation {
                    NumberAnimation {
                        properties: "opacity,scale"
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Appearance.animation.elementMoveFast.type
                    }
                }
            }
        ]

        Keys.onEscapePressed: GlobalStates.launcherOpen = false
    }
}
