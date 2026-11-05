import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services
import qs.settings

// The welcome tour: a card in the middle of the screen, always the same size, with steps.
// Left / Right arrows move between steps, Enter goes on, Esc skips it.
Scope {
    id: root

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property var modelData
            screen: modelData

            readonly property bool here: Welcome.open && !Welcome.hidden
                && (Welcome.screenName === "" || Welcome.screenName === modelData.name)

            visible: here || card.opacity > 0
            color: "transparent"

            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "shell-welcome"
            WlrLayershell.keyboardFocus: win.here ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            onHereChanged: if (here) keys.forceActiveFocus()

            // A soft veil: the changes you make (style, colors) stay visible behind the card
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.38)
                opacity: win.here ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 260 } }
            }

            Item {
                id: keys
                anchors.fill: parent
                focus: true
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Right || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        Welcome.next(); event.accepted = true
                    } else if (event.key === Qt.Key_Left) {
                        Welcome.back(); event.accepted = true
                    } else if (event.key === Qt.Key_Escape) {
                        Welcome.finish(); event.accepted = true
                    }
                }
            }

            Rectangle {
                id: card

                anchors.centerIn: parent
                width: Math.min(1080, win.width - 60)
                height: Math.min(680, win.height - 60)
                radius: 32
                color: Theme.island
                border.width: 1
                border.color: Theme.border
                clip: true
                opacity: win.here ? 1 : 0
                scale: win.here ? 1 : 0.94
                Behavior on opacity { NumberAnimation { duration: 220 } }
                Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }

                MouseArea { anchors.fill: parent }       // clicks do not go through

                // a glow of the accent color in the corner
                Rectangle {
                    x: -card.width * 0.25
                    y: -card.height * 0.55
                    width: card.width * 0.9
                    height: width
                    radius: width / 2
                    color: Theme.accent
                    opacity: 0.10
                }
                Rectangle {
                    x: card.width * 0.62
                    y: card.height * 0.55
                    width: card.width * 0.6
                    height: width
                    radius: width / 2
                    color: Theme.note
                    opacity: 0.06
                }

                // ---------- the step ----------
                Item {
                    id: stepHolder
                    width: parent.width
                    height: parent.height - footer.height

                    Loader {
                        id: stepLoader
                        anchors.fill: parent
                        source: Welcome.steps[Welcome.step].file
                    }

                    ParallelAnimation {
                        id: enter
                        NumberAnimation { target: stepLoader; property: "opacity"; from: 0; to: 1; duration: 280; easing.type: Easing.OutCubic }
                        NumberAnimation { target: stepLoader; property: "x"; from: 46 * Welcome.dir; to: 0; duration: 340; easing.type: Easing.OutCubic }
                    }

                    Connections {
                        target: Welcome
                        function onStepChanged() { enter.restart() }
                    }
                }

                // ---------- skip ----------
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 28
                    y: 26
                    visible: !Welcome.last
                    text: "Skip tour"
                    color: skipMouse.containsMouse ? Theme.foreground : Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    MouseArea {
                        id: skipMouse
                        anchors.fill: parent
                        anchors.margins: -8
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Welcome.finish()
                    }
                }

                // ---------- footer: back, progress, next ----------
                Item {
                    id: footer
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 84

                    Rectangle {
                        x: 28
                        width: parent.width - 56
                        height: 1
                        color: Theme.border
                        opacity: 0.6
                    }

                    SButton {

                        base: Theme.surfaceSoft
                        x: 40
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: 2
                        opacity: Welcome.first ? 0 : 1
                        enabled: !Welcome.first
                        label: "‹  Back"
                        onClicked: Welcome.back()
                        Behavior on opacity { NumberAnimation { duration: 160 } }
                    }

                    // dots: the current one stretches
                    Row {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: 2
                        spacing: 8

                        Repeater {
                            model: Welcome.steps.length

                            delegate: Rectangle {
                                required property int index
                                readonly property bool on: Welcome.step === index

                                width: on ? 28 : 8
                                height: 8
                                radius: 4
                                color: on ? Theme.accent : (index < Welcome.step ? Theme.mix(Theme.accent, Theme.island, 0.5) : Theme.border)
                                Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
                                Behavior on color { ColorAnimation { duration: 200 } }

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Welcome.go(parent.index)
                                }
                            }
                        }
                    }

                    SButton {

                        base: Theme.surfaceSoft
                        anchors.right: parent.right
                        anchors.rightMargin: 40
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: 2
                        accent: true
                        implicitWidth: 120
                        label: Welcome.last ? "Start  ✓" : "Next  ›"
                        onClicked: Welcome.next()
                    }
                }
            }
        }
    }
}
