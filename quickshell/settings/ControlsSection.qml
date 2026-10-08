// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C O N T R O L S   S E C T I O N                                        │
// │   control centre · its grid, and the buttons over it                     │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../theme"
import "../services"
import "../components"

// The control centre: its grid's size (also under the island while
// arranging), the way into arranging it and back to its default, and the
// buttons of its top row. A toggles or shortcuts block picks what it carries
// in `BlockInspector`.
SettingsSection {
    id: root

    // Unused: this page has no parts, but `SettingsPanel` sets it on all pages.
    property string tab: ""

    // `SettingsPanel` opens the control centre, then closes the window.
    signal arranging()

    SettingGroup {
        title: Tr.t("The panel")
        note: Tr.t("A grid of the size chosen here, arranged on the panel itself.")
        hint: Tr.t("Edit shows the grid, its columns and rows under the island, and a card of every block under them. Drag a block onto the cells, pull a corner or scroll to resize it, and drop it on the card to remove it; a click on a toggles or shortcuts block chooses what it carries. Columns come and go on both sides alike, so the blocks stay centred. Escape leaves, and the right button on the panel enters or leaves without opening settings.")

        SettingRow {
            label: Tr.t("Columns")

            SegmentedControl {
                options: [2, 3, 4, 5, 6].map(count => ({ id: `${count}`, label: `${count}` }))
                current: `${ControlsService.columns}`
                onSelected: id => ControlsService.resize(parseInt(id), ControlsService.rows)
            }
        }

        SettingRow {
            label: Tr.t("Rows")

            SegmentedControl {
                options: [2, 3, 4, 5, 6, 7, 8].map(count => ({ id: `${count}`, label: `${count}` }))
                current: `${ControlsService.rows}`
                onSelected: id => ControlsService.resize(ControlsService.columns, parseInt(id))
            }
        }

        SettingRow {
            label: Tr.t("Arrange the control centre")

            Row {
                spacing: 8

                PillButton {
                    text: Tr.t("Default layout")
                    implicitHeight: 30
                    onClicked: ControlsService.restore()
                }

                PillButton {
                    text: Tr.t("Edit")
                    implicitHeight: 30
                    onClicked: {
                        ControlsService.edit(true)
                        root.arranging()
                    }
                }
            }
        }
    }

    // ── THE TOP ROW ─────────────────────────────────────────────────────────

    SettingGroup {
        title: Tr.t("The top row")
        note: Tr.t("Small buttons over the grid, on either side. With none, there is no row.")

        SettingBlock {
            TopRowEditor {
                Layout.fillWidth: true
            }
        }
    }
}
