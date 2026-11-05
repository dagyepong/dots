import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services

Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property var modelData
            screen: modelData

            // ---- Regolazioni ----
            readonly property int panelW: 132        // visible width of the panel
            readonly property int corner: 34         // rounding of the right side
            readonly property int stripW: 6          // thickness of the sensitive strip on the edge
            readonly property int stripH: 300        // height of the sensitive strip (centered)
            readonly property bool showHandle: true  // small line marking where it opens

            readonly property bool here: SysStats.shown
                && (SysStats.screen === "" || SysStats.screen === modelData.name)

            // Panel position: 0 = open, -panelW = hidden.
            // The spring animation makes it bounce past 0, and past 0 the panel stretches.
            property real offset: win.here ? 0 : -win.panelW
            Behavior on offset {
                SpringAnimation { spring: 3.0; damping: 0.28; epsilon: 0.2 }
            }

            // Only "left": the compositor centers it vertically
            anchors { left: true }
            implicitWidth: win.panelW + 70           // room for the elastic stretch
            implicitHeight: 480
            color: "transparent"

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Top        // does not cover fullscreen games
            WlrLayershell.namespace: "shell-system"

            // The mouse arrives only here: a strip on the edge (closed) or the whole panel (open)
            mask: Region { item: inputArea }

            Item {
                id: inputArea

                x: 0
                width: win.here ? win.panelW : win.stripW
                height: win.here ? pill.height : win.stripH
                y: (win.height - height) / 2

                HoverHandler {
                    onHoveredChanged: SysStats.setEdge(hovered, win.modelData.name)
                }
            }

            // Small line marking where it opens (disappears when the panel leaves)
            Rectangle {
                visible: win.showHandle
                anchors.verticalCenter: parent.verticalCenter
                x: -3
                width: 6
                height: 64
                radius: 3
                color: Theme.accent
                opacity: win.here ? 0 : 0.5
                Behavior on opacity { NumberAnimation { duration: 250 } }
            }

            // ---------- The panel ----------
            Rectangle {
                id: pill

                anchors.verticalCenter: parent.verticalCenter
                x: Math.min(0, win.offset) - win.corner
                width: win.panelW + win.corner + Math.max(0, win.offset)
                height: col.implicitHeight + 40
                radius: win.corner
                color: Theme.island
                border.width: 1
                border.color: Theme.border

                Column {
                    id: col

                    x: win.corner + (win.panelW - 96) / 2
                    y: 20
                    width: 96
                    spacing: 12

                    Ring {
                        width: 96
                        height: 96
                        label: "CPU"
                        value: win.here ? SysStats.cpu : 0
                        sweep: 550
                    }

                    Ring {
                        width: 96
                        height: 96
                        label: "RAM"
                        value: win.here ? SysStats.ram : 0
                        tone: Theme.note
                        sweep: 750
                    }

                    Ring {
                        width: 96
                        height: 96
                        label: "DISK"
                        value: win.here ? SysStats.disk : 0
                        sweep: 950
                    }

                    // Network: download and upload speed
                    Rectangle {
                        width: 96
                        height: 70
                        radius: 22
                        color: Theme.surfaceSoft

                        Column {
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "NET"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                font.bold: true
                            }

                            Row {
                                spacing: 4
                                anchors.horizontalCenter: parent.horizontalCenter

                                Text {
                                    text: "↓"
                                    color: Theme.accent
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                                Text {
                                    text: SysStats.fmtRate(SysStats.netDown)
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                }
                            }

                            Row {
                                spacing: 4
                                anchors.horizontalCenter: parent.horizontalCenter

                                Text {
                                    text: "↑"
                                    color: Theme.muted
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                                Text {
                                    text: SysStats.fmtRate(SysStats.netUp)
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
