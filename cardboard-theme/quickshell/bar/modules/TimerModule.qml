// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   T I M E R   M O D U L E                                                │
// │   countdown timer · set, pause and cancel                                │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../../theme"
import "../../services"
import "../../components"
import "../widgets"

// Idle, the ring is empty and the detail sets a countdown; running, the ring
// drains and the detail holds, restarts or stops it. Clicking the chip never
// cancels.
Item {
    id: root

    property bool compact: false

    // The duration Start will use, seeded from the last run so restarting is
    // one click.
    property int hours: 0
    property int minutes: 5
    property int seconds: 0

    // The countdown Start would begin, shown on the idle ring.
    readonly property string preview: {
        const pad = value => value < 10 ? `0${value}` : `${value}`
        if (root.hours > 0)
            return `${root.hours}:${pad(root.minutes)}:${pad(root.seconds)}`
        return `${root.minutes}:${pad(root.seconds)}`
    }

    implicitWidth: holder.implicitWidth
    implicitHeight: holder.implicitHeight

    readonly property int pending:
        (root.hours * 3600 + root.minutes * 60 + root.seconds) * 1000

    Loader {
        id: holder
        anchors.fill: parent
        sourceComponent: root.compact ? chip : detail
    }

    // Ring face; `ChipFace` draws the remaining time beside it.
    Component {
        id: chip

        Item {
            TimerWidget {
                id: mark
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                size: Theme.capsuleHeight
            }
        }
    }

    Component {
        id: detail

        // A large ring with the time inside it, beside two rows: the duration
        // and the controls.
        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            anchors.leftMargin: 16
            spacing: 16

            RingIndicator {
                Layout.preferredWidth: 66
                Layout.preferredHeight: 66
                Layout.alignment: Qt.AlignVCenter
                thickness: 4
                progress: TimerService.running ? TimerService.progress : 0
                trackColor: Theme.indicatorDim
                fillColor: TimerService.running ? TimerService.tint : Theme.indicatorDim

                Behavior on fillColor { ColorAnimation { duration: Theme.durationMedium } }

                Text {
                    anchors.centerIn: parent
                    text: TimerService.running ? TimerService.display : root.preview
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.DemiBold
                    color: TimerService.paused ? Theme.textMuted : Theme.indicator

                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 10

                // Idle, this row sets the duration; running, it describes the
                // countdown. Same height either way.
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28

                    // A RowLayout so the three fields split the card's width.
                    RowLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 9
                        visible: !TimerService.running

                        Stepper {
                            Layout.fillWidth: true
                            value: root.hours
                            maximum: 23
                            unit: "h"
                            implicitWidth: 40
                            implicitHeight: 28
                            onChanged: value => root.hours = value
                        }

                        Stepper {
                            Layout.fillWidth: true
                            value: root.minutes
                            maximum: 59
                            unit: "m"
                            implicitWidth: 40
                            implicitHeight: 28
                            onChanged: value => root.minutes = value
                        }

                        Stepper {
                            Layout.fillWidth: true
                            value: root.seconds
                            maximum: 59
                            unit: "s"
                            implicitWidth: 40
                            implicitHeight: 28
                            onChanged: value => root.seconds = value
                        }
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1
                        visible: TimerService.running

                        Text {
                            width: parent.width
                            text: TimerService.label || "Countdown"
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }

                        Text {
                            width: parent.width
                            text: TimerService.paused ? "Held" : "Running"
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabel
                            color: Theme.textMuted
                        }
                    }
                }

                // Idle: Start and Clear share the row. Running: Hold takes the
                // spare width and Restart and Stop stay square, icon only.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 9

                    PillButton {
                        Layout.fillWidth: true
                        // Zero preferred width so the buttons split the row
                        // evenly regardless of their labels.
                        Layout.preferredWidth: 0
                        text: {
                            if (!TimerService.running)
                                return "Start"
                            return TimerService.paused ? "Resume" : "Hold"
                        }
                        icon: {
                            if (!TimerService.running)
                                return "󰐊"
                            return TimerService.paused ? "󰐊" : "󰏤"
                        }
                        active: !TimerService.running || TimerService.paused
                        enabled: TimerService.running || root.pending > 0
                        implicitWidth: 88
                        implicitHeight: 30
                        onClicked: {
                            if (TimerService.running)
                                TimerService.toggle()
                            else
                                TimerService.start(root.pending)
                        }
                    }

                    PillButton {
                        Layout.fillWidth: !TimerService.running
                        Layout.preferredWidth: TimerService.running ? 46 : 0
                        text: TimerService.running ? "" : "Clear"
                        icon: "󰜉"
                        implicitWidth: 46
                        implicitHeight: 30
                        onClicked: {
                            if (TimerService.running)
                                TimerService.restart()
                            else {
                                root.hours = 0
                                root.minutes = 0
                                root.seconds = 0
                            }
                        }
                    }

                    PillButton {
                        Layout.preferredWidth: 46
                        visible: TimerService.running
                        icon: "󰓛"
                        implicitWidth: 46
                        implicitHeight: 30
                        onClicked: TimerService.cancel()
                    }
                }
            }
        }
    }
}
