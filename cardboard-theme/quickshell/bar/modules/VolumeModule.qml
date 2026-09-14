// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   V O L U M E   M O D U L E                                              │
// │   volume · sink level ring, slider when open                             │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../../theme"
import "../../services"
import "../../components"

// The ring is the level and the glyph the output device; the detail is a
// slider and the two mutes. The ring stays white: volume is a choice, not a
// warning.
Item {
    id: root

    property bool compact: false

    implicitWidth: holder.implicitWidth
    implicitHeight: holder.implicitHeight

    Loader {
        id: holder
        anchors.fill: parent
        sourceComponent: root.compact ? chip : detail
    }

    Component {
        id: chip

        Item {
            Item {
                id: mark

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.capsuleHeight
                height: Theme.capsuleHeight

                RingIndicator {
                    anchors.fill: parent
                    thickness: 2.5
                    progress: AudioService.muted ? 0 : AudioService.volume / 100
                    trackColor: Theme.indicatorDim
                    fillColor: Theme.indicator

                    Text {
                        anchors.centerIn: parent
                        text: AudioService.icon
                        font.family: Theme.fontMono
                        font.pixelSize: Math.round(Theme.capsuleHeight * 0.38)
                        color: AudioService.muted ? Theme.textMuted : Theme.indicator
                    }
                }
            }
        }
    }

    Component {
        id: detail

        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 14

            // Same white ring as the chip; the slider follows the palette.
            RingIndicator {
                Layout.preferredWidth: 56
                Layout.preferredHeight: 56
                Layout.alignment: Qt.AlignVCenter
                thickness: 3.5
                progress: AudioService.muted ? 0 : AudioService.volume / 100
                trackColor: Theme.indicatorDim
                fillColor: Theme.indicator

                Text {
                    anchors.centerIn: parent
                    text: AudioService.icon
                    font.family: Theme.fontMono
                    font.pixelSize: 20
                    color: AudioService.muted ? Theme.textMuted : Theme.indicator
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        Layout.fillWidth: true
                        text: "Volume"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    Text {
                        text: AudioService.muted ? "Muted" : `${AudioService.volume}%`
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeSmall
                        color: AudioService.muted ? Theme.textMuted : Theme.text
                    }
                }

                // The whole strip is the hit area.
                Item {
                    id: slider

                    Layout.fillWidth: true
                    Layout.preferredHeight: 16

                    UsageBar {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        implicitHeight: sliderMouse.containsMouse ? 6 : 4
                        progress: AudioService.volume / 100
                        fillColor: AudioService.muted
                            ? Theme.indicatorDim : Theme.accent

                        Behavior on implicitHeight {
                            NumberAnimation {
                                duration: Theme.durationFast
                                easing.type: Theme.easing
                            }
                        }
                    }

                    MouseArea {
                        id: sliderMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: event => AudioService.setVolume(
                            Math.round(event.x / slider.width * 100))
                        onPositionChanged: event => {
                            if (pressed)
                                AudioService.setVolume(Math.max(0, Math.min(100,
                                    Math.round(event.x / slider.width * 100))))
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 9

                    PillButton {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 0
                        text: "Mute"
                        active: AudioService.muted
                        implicitHeight: 28
                        onClicked: AudioService.toggleMute()
                    }

                    PillButton {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 0
                        text: "Mic"
                        active: AudioService.sourceMuted
                        implicitHeight: 28
                        onClicked: AudioService.toggleSourceMute()
                    }
                }
            }
        }
    }
}
