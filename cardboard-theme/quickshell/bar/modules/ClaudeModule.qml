// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C L A U D E   M O D U L E                                              │
// │   claude code usage · current block and week                             │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../../theme"
import "../../services"
import "../../components"

// Token and message counts for the current five-hour block and the last seven
// days, read from the local transcripts. A percentage is shown only when a
// ceiling is set in the settings. The ring is time elapsed in the block.
Item {
    id: root

    property bool compact: false

    implicitWidth: holder.implicitWidth
    implicitHeight: holder.implicitHeight

    Component.onCompleted: ClaudeService.subscribe()
    Component.onDestruction: ClaudeService.release()

    Loader {
        id: holder
        anchors.fill: parent
        sourceComponent: root.compact ? chip : detail
    }

    // Ring face: the block's clock. `ChipFace` draws the figure.
    Component {
        id: chip

        Item {
            RingIndicator {
                id: mark

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.capsuleHeight
                height: Theme.capsuleHeight
                thickness: 2.5
                progress: ClaudeService.gauge
                trackColor: Theme.indicatorDim
                fillColor: ClaudeService.tint

                Behavior on fillColor { ColorAnimation { duration: Theme.durationMedium } }

                ClaudeMark {
                    anchors.centerIn: parent
                    width: Math.round(Theme.capsuleHeight * 0.53)
                    height: Math.round(Theme.capsuleHeight * 0.53)
                    color: Theme.indicator
                }
            }
        }
    }

    Component {
        id: detail

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            anchors.topMargin: 12
            anchors.bottomMargin: 12
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 13

                RingIndicator {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44
                    thickness: 3
                    progress: ClaudeService.gauge
                    trackColor: Theme.indicatorDim
                    fillColor: ClaudeService.tint

                    Behavior on fillColor { ColorAnimation { duration: Theme.durationMedium } }

                    ClaudeMark {
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        color: Theme.indicator
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: "Claude Code"
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    Text {
                        Layout.fillWidth: true
                        // A block runs five hours from its first message, so
                        // the reset time is exact.
                        text: ClaudeService.available
                            ? `Session ${ClaudeService.resetsIn}`
                            : "No sessions on disk"
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.textMuted
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                Repeater {
                    model: [
                        {
                            label: "SESSION",
                            tokens: ClaudeService.blockTokens,
                            count: ClaudeService.blockMessages,
                            fraction: ClaudeService.sessionFraction,
                            measured: ClaudeService.sessionMeasured
                        },
                        {
                            label: "WEEK",
                            tokens: ClaudeService.weekTokens,
                            count: ClaudeService.weekMessages,
                            fraction: ClaudeService.weeklyFraction,
                            measured: ClaudeService.weeklyMeasured
                        }
                    ]

                    ColumnLayout {
                        id: column

                        required property var modelData

                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        spacing: 5

                        Figure {
                            Layout.fillWidth: true
                            label: column.modelData.label
                            value: `${ClaudeService.compact(column.modelData.tokens)} tokens`
                            // Messages as the note: they tell a long session
                            // apart from one large file.
                            note: ClaudeService.messages(column.modelData.count)
                        }

                        // Only with a configured ceiling.
                        RowLayout {
                            Layout.fillWidth: true
                            visible: column.modelData.measured
                            spacing: 7

                            UsageBar {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                implicitWidth: 40
                                implicitHeight: 5
                                progress: column.modelData.fraction
                                fillColor: ClaudeService.tint
                            }

                            Text {
                                text: ClaudeService.percent(column.modelData.fraction)
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeLabel
                                color: Theme.textMuted
                            }
                        }
                    }
                }
            }
        }
    }
}
