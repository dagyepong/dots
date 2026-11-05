import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services
import qs.widgets

// Floating bar at the center of the screen to choose the shell style.
// Opens with:  qs ipc call style toggle   (arrows or 1-3 to choose, Enter to apply, Esc to close)
Scope {
    id: root

    function screensToShow() {
        const all = Quickshell.screens
        const out = []
        for (let i = 0; i < all.length; i++)
            if (Compositor.focusedMonitor === "" || all[i].name === Compositor.focusedMonitor) out.push(all[i])
        return out.length > 0 ? out : all
    }

    Variants {
        model: Style.pickerOpen ? root.screensToShow() : []

        PanelWindow {
            id: win

            required property var modelData
            screen: modelData

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "shell-style"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            property int sel: 0
            property real shown: 0

            Component.onCompleted: {
                for (let i = 0; i < Style.styles.length; i++)
                    if (Style.styles[i].id === Style.current) sel = i
                intro.start()
                keys.forceActiveFocus()
            }

            NumberAnimation {
                id: intro
                target: win
                property: "shown"
                from: 0
                to: 1
                duration: 320
                easing.type: Easing.OutCubic
            }

            function move(d) {
                let n = sel
                for (let k = 0; k < Style.styles.length; k++) {
                    n = (n + d + Style.styles.length) % Style.styles.length
                    if (Style.styles[n].ready) { sel = n; return }
                }
            }

            function pick(i) {
                if (!Style.styles[i].ready) return
                sel = i
                Style.set(Style.styles[i].id)
                closeTimer.restart()
            }

            Timer {
                id: closeTimer
                interval: 380
                onTriggered: Style.pickerOpen = false
            }

            // Outside the bar: click to close
            MouseArea {
                anchors.fill: parent
                onClicked: Style.pickerOpen = false
            }

            Item {
                id: keys
                anchors.fill: parent
                focus: true

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) Style.pickerOpen = false
                    else if (event.key === Qt.Key_Left) win.move(-1)
                    else if (event.key === Qt.Key_Right) win.move(1)
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) win.pick(win.sel)
                    else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_4) win.pick(event.key - Qt.Key_1)
                    else return
                    event.accepted = true
                }
            }

            // ---------- The floating bar ----------
            Rectangle {
                id: card

                anchors.centerIn: parent
                width: Style.styles.length * 190 + (Style.styles.length - 1) * 14 + 40
                height: 238
                radius: 30
                color: Qt.rgba(Theme.island.r, Theme.island.g, Theme.island.b, 0.96)
                border.width: 1
                border.color: Theme.border
                opacity: win.shown
                scale: 0.94 + 0.06 * win.shown

                MouseArea { anchors.fill: parent }   // clicks inside do not close

                Text {
                    x: 24; y: 16
                    text: "Style"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.bold: true
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 24
                    y: 18
                    text: "← →  Enter  ·  Esc"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }

                Row {
                    x: 20; y: 46
                    spacing: 14

                    Repeater {
                        model: Style.styles

                        delegate: Rectangle {
                            id: opt

                            required property var modelData
                            required property int index

                            readonly property bool chosen: win.sel === index
                            readonly property bool current: Style.current === modelData.id

                            width: 190
                            height: 172
                            radius: 20
                            color: optMouse.containsMouse && modelData.ready ? Theme.islandHover : Theme.surfaceSoft
                            border.width: chosen ? 2 : 1
                            border.color: chosen ? Theme.accent : Theme.border
                            opacity: modelData.ready ? 1 : 0.45
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 140 } }

                            // Drawn preview
                            Rectangle {
                                x: 10; y: 10
                                width: parent.width - 20
                                height: 100
                                radius: 12
                                color: Theme.mix(Theme.island, Theme.foreground, 0.05)
                                clip: true

                                // island: three centered pills
                                Row {
                                    visible: opt.modelData.id === "island"
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: 9
                                    spacing: 5
                                    Rectangle { width: 14; height: 14; radius: 7; color: Theme.island; border.width: 1; border.color: Theme.border }
                                    Rectangle { width: 34; height: 14; radius: 7; color: Theme.island; border.width: 1; border.color: Theme.border }
                                    Rectangle { width: 14; height: 14; radius: 7; color: Theme.island; border.width: 1; border.color: Theme.border }
                                }

                                // classic: full-width bar with three groups
                                Item {
                                    visible: opt.modelData.id === "classic"
                                    anchors.fill: parent

                                    Rectangle {
                                        width: parent.width
                                        height: 22
                                        color: Theme.island
                                    }
                                    Rectangle { x: 6; y: 4; width: 14; height: 14; radius: 7; color: Theme.surfaceSoft }
                                    Rectangle { x: 24; y: 5; width: 24; height: 12; radius: 6; color: Theme.surfaceSoft }
                                    Row {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: 8
                                        spacing: 3
                                        Rectangle { width: 5; height: 5; radius: 2.5; color: Theme.foreground }
                                        Rectangle { width: 16; height: 5; radius: 2.5; color: Theme.accent }
                                        Rectangle { width: 5; height: 5; radius: 2.5; color: Theme.muted }
                                    }
                                    Rectangle { x: parent.width - 6 - width; y: 5; width: 36; height: 12; radius: 6; color: Theme.surfaceSoft }
                                }

                                // dashboard: a small pill and a large grid below
                                Item {
                                    visible: opt.modelData.id === "dash"
                                    anchors.fill: parent

                                    Rectangle {
                                        x: (parent.width - 28) / 2; y: 6
                                        width: 28; height: 8; radius: 4
                                        color: Theme.island
                                    }
                                    Rectangle { x: 8; y: 20; width: 22; height: 70; radius: 6; color: Theme.surfaceSoft }
                                    Rectangle { x: 34; y: 20; width: 74; height: 11; radius: 5; color: Theme.surfaceSoft }
                                    Rectangle { x: 34; y: 35; width: 74; height: 7; radius: 3.5; color: Theme.accent }
                                    Rectangle { x: 34; y: 46; width: 34; height: 44; radius: 5; color: Theme.surfaceSoft }
                                    Rectangle { x: 72; y: 46; width: 36; height: 44; radius: 5; color: Theme.surfaceSoft }
                                    Rectangle { x: parent.width - 22; y: 20; width: 14; height: 70; radius: 6; color: Theme.surfaceSoft }
                                }

                                // vertical: bar flush on the left, thin frame, a panel attached to the bar
                                Item {
                                    visible: opt.modelData.id === "side"
                                    anchors.fill: parent

                                    Rectangle { anchors.fill: parent; color: Theme.island }
                                    Rectangle {
                                        x: 16; y: 4
                                        width: parent.width - 20; height: parent.height - 8
                                        radius: 10
                                        color: Theme.mix(Theme.island, Theme.foreground, 0.05)
                                    }
                                    Rectangle { x: 0; y: 28; width: 54; height: 44; radius: 9; color: Theme.island }
                                    Column {
                                        x: 4; y: 8
                                        spacing: 5
                                        Rectangle { width: 8; height: 8; radius: 4; color: Theme.surfaceSoft }
                                        Rectangle { width: 8; height: 8; radius: 4; color: Theme.accent }
                                        Rectangle { width: 8; height: 8; radius: 4; color: Theme.surfaceSoft }
                                    }
                                    Rectangle { x: 14; y: 36; width: 34; height: 8; radius: 4; color: Theme.surfaceSoft }
                                    Rectangle { x: 14; y: 50; width: 22; height: 8; radius: 4; color: Theme.accent }
                                }
                            }

                            Text {
                                x: 14; y: 120
                                text: opt.modelData.name
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.bold: true
                            }

                            Text {
                                x: 14; y: 140
                                text: opt.current ? "In use" : opt.modelData.hint
                                color: opt.current ? Theme.accent : Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                            }

                            MouseArea {
                                id: optMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: opt.modelData.ready ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onEntered: if (opt.modelData.ready) win.sel = opt.index
                                onClicked: win.pick(opt.index)
                            }
                        }
                    }
                }
            }
        }
    }
}
