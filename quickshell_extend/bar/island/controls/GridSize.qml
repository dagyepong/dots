// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   G R I D   S I Z E                                                      │
// │   the control centre's columns and rows · shown while arranging          │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import "../../../theme"
import "../../../services"

// A pill under the island while the grid is arranged: columns and rows, one
// step at a time, so the grid is sized where its effect is seen
// (`ControlsService.resize`, which keeps the blocks centred).
Rectangle {
    id: root

    implicitWidth: row.implicitWidth + 2 * 10
    implicitHeight: 36
    radius: height / 2
    color: Theme.island
    border.color: Theme.borderIn(QsWindow.window)
    border.width: 1

    component Step: Row {
        id: step

        property string label: ""
        property int value: 0
        property int least: 2
        property int most: 6

        signal changed(int value)

        spacing: 4

        Text {
            anchors.verticalCenter: parent.verticalCenter
            rightPadding: 4
            text: step.label
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.textMuted
        }

        Repeater {
            model: [{ glyph: "󰍴", delta: -1 }, { glyph: "", delta: 0 }, { glyph: "󰐕", delta: 1 }]

            Rectangle {
                id: button

                required property var modelData

                readonly property bool figure: button.modelData.delta === 0
                readonly property int next: step.value + button.modelData.delta
                readonly property bool usable: !button.figure
                    && button.next >= step.least && button.next <= step.most

                anchors.verticalCenter: parent.verticalCenter
                width: button.figure ? 20 : 24
                height: 24
                radius: 12
                color: press.hovered && button.usable
                    ? Theme.surfaceHoverIn(QsWindow.window) : "transparent"
                opacity: button.figure || button.usable ? 1 : 0.3

                Text {
                    anchors.centerIn: parent
                    text: button.figure ? `${step.value}` : button.modelData.glyph
                    font.family: button.figure ? Theme.fontFamily : Theme.fontMono
                    font.pixelSize: button.figure ? Theme.fontSizeRegular : Theme.fontSizeSmall
                    font.weight: button.figure ? Font.DemiBold : Font.Normal
                    color: Theme.text
                }

                HoverHandler {
                    id: press

                    cursorShape: button.usable ? Qt.PointingHandCursor : Qt.ArrowCursor
                }

                TapHandler {
                    enabled: button.usable
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: step.changed(button.next)
                }
            }
        }
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 18

        Step {
            label: Tr.t("Columns")
            value: ControlsService.columns
            most: Theme.centreColumns
            onChanged: value => ControlsService.resize(value, ControlsService.rows)
        }

        Step {
            label: Tr.t("Rows")
            value: ControlsService.rows
            most: Theme.centreRows
            onChanged: value => ControlsService.resize(ControlsService.columns, value)
        }
    }
}
