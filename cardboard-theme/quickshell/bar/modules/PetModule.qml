// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   P E T   M O D U L E                                                    │
// │   pet · the active pet, the shelf when open                              │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../../theme"
import "../../services"
import "../../components"

// The module around `PetFace`: the chip, and the detail where the pet is fed,
// played with and swapped. The ring is progress to the next level, white
// because it warns about nothing. The shelf has one slot per species; clicking
// a sleeping pet brings it out.
Item {
    id: root

    property bool compact: false

    implicitWidth: holder.implicitWidth
    implicitHeight: holder.implicitHeight

    Component.onCompleted: PetService.subscribe()
    Component.onDestruction: PetService.release()

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
                    progress: PetService.progress
                    trackColor: Theme.indicatorDim
                    fillColor: Theme.indicator

                    PetFace {
                        anchors.centerIn: parent
                        size: Math.round(Theme.capsuleHeight * 0.56)
                        lively: true
                    }
                }
            }
        }
    }

    Component {
        id: detail

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                Item {
                    Layout.preferredWidth: 68
                    Layout.preferredHeight: 68
                    Layout.alignment: Qt.AlignVCenter

                    PetFace {
                        id: bigFace

                        anchors.centerIn: parent
                        size: 60
                        lively: true

                        // Idle bob; a hop pauses it for its own length.
                        SequentialAnimation {
                            id: bob
                            running: !hop.running && PetService.mood !== "asleep"
                            loops: Animation.Infinite

                            NumberAnimation {
                                target: bigFace; property: "anchors.verticalCenterOffset"
                                to: -2; duration: 1400; easing.type: Easing.InOutSine
                            }
                            NumberAnimation {
                                target: bigFace; property: "anchors.verticalCenterOffset"
                                to: 0; duration: 1400; easing.type: Easing.InOutSine
                            }
                        }

                        SequentialAnimation {
                            id: hop

                            NumberAnimation {
                                target: bigFace; property: "anchors.verticalCenterOffset"
                                to: -10; duration: 130; easing.type: Easing.OutQuad
                            }
                            NumberAnimation {
                                target: bigFace; property: "anchors.verticalCenterOffset"
                                to: 0; duration: 190; easing.type: Easing.OutBounce
                            }
                        }

                        Connections {
                            target: PetService
                            function onPlayed(): void { hop.restart() }
                            function onCelebrated(level: int): void { hop.restart() }
                            function onBrought(index: int): void { hop.restart() }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            Layout.fillWidth: true
                            // Hatched pets show their name, then their species.
                            text: PetService.titleOf(PetService.pet)
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }

                        Text {
                            visible: PetService.hatched
                            text: `Lv ${PetService.level}`
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.textMuted
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: PetService.moodLine
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.textMuted
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        UsageBar {
                            Layout.fillWidth: true
                            progress: PetService.progress
                            fillColor: bigFace.coat
                        }

                        Text {
                            text: `${PetService.xp}/${PetService.threshold}`
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeLabel
                            color: Theme.textMuted
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 9

                        PillButton {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 0
                            text: PetService.canFeed ? "Feed" : "Fed"
                            enabled: PetService.canFeed
                            opacity: PetService.canFeed ? 1 : 0.45
                            implicitHeight: 28
                            onClicked: PetService.feed()
                        }

                        PillButton {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 0
                            text: PetService.canPlay ? "Play" : "Played"
                            enabled: PetService.canPlay
                            opacity: PetService.canPlay ? 1 : 0.45
                            implicitHeight: 28
                            onClicked: PetService.play()
                        }
                    }
                }
            }

            // ── SHELF ───────────────────────────────────────────────────────

            PetShelf {
                Layout.fillWidth: true
            }
        }
    }
}
