import QtQuick
import "CheatBinds.js" as CB
import qs.modules.common
import qs.modules.common.widgets

// One paper note on the cheatsheet board: a category's binds as rows of
// little keycaps + a label. The paper depends on the category (`kind`):
//   sticky / pink / mint   plain sticky notes
//   index                  ruled index card with a red header line
//   notebook               ruled page with punched holes down the side
//   polaroid               white frame with a "photo" strip on top
// Odd slots are held by a push-pin, even ones by washi tape (same idea as
// OverviewWorkspaceCard). While searching, rows that don't match dim and a
// note with no match at all fades back; hovering straightens + lifts it.
//
// Size comes from CheatBinds.js, which CheatSheet uses to lay the board out.
Item {
    id: root

    property var note: ({ title: "", kind: "sticky", icon: "", rows: [] })
    property int slot: 0
    property string query: ""
    property int modFilter: 0

    readonly property var tilts: [-2.4, 1.8, -1.3, 2.6, -1.9]
    readonly property var pinColors: [ScrapbookTheme.tapeCoral, ScrapbookTheme.tapeTeal, ScrapbookTheme.tag, ScrapbookTheme.tapeMint, ScrapbookTheme.pinPink]
    readonly property var papers: ({
        sticky: ScrapbookTheme.tag, pink: "#f9cfe0", mint: "#dcebc8",
        index: ScrapbookTheme.labelPaper, notebook: ScrapbookTheme.page, polaroid: "#ffffff"
    })

    readonly property string kind: note.kind
    readonly property bool ruled: kind === "index" || kind === "notebook"
    readonly property bool holes: kind === "notebook"
    readonly property bool photo: kind === "polaroid"
    readonly property bool taped: slot % 2 === 1
    readonly property real padL: holes ? 38 : 20
    readonly property real padTop: photo ? 72 : 16
    readonly property real rowsTop: padTop + 34

    readonly property var rows: note.rows
    readonly property var flags: rows.map(r => CB.matches(r, root.query, root.modFilter))
    readonly property bool filtering: query.length > 0 || modFilter !== 0
    readonly property bool hit: flags.indexOf(true) >= 0

    width: CB.NOTE_W
    height: CB.noteHeight(note)
    z: hover.hovered ? 10 : 0
    opacity: (!filtering || hit) ? 1 : 0.2
    Behavior on opacity { NumberAnimation { duration: 160 } }

    HoverHandler { id: hover }

    Item {
        id: sheet
        anchors.fill: parent
        rotation: hover.hovered ? 0 : root.tilts[root.slot % 5] * 0.8
        scale: hover.hovered ? 1.03 : 1
        Behavior on rotation { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        // drop shadow onto the cork
        Rectangle {
            x: 5; y: 6
            width: parent.width; height: parent.height
            radius: 6
            color: ScrapbookTheme.noteShadow
            opacity: 0.38
        }

        Rectangle {
            id: paper
            anchors.fill: parent
            radius: 6
            color: root.papers[root.kind] || ScrapbookTheme.tag
            border.width: 1.5
            border.color: "#664a4536"

            // red header line of an index card
            Rectangle {
                visible: root.kind === "index"
                x: 10; y: root.padTop + 28
                width: paper.width - 20; height: 1.5
                color: ScrapbookTheme.tapeCoral
            }

            // ruled lines under each row
            Repeater {
                model: root.ruled ? root.rows.length : 0
                delegate: Rectangle {
                    required property int index
                    x: root.holes ? 28 : 10
                    y: root.rowsTop + (index + 1) * CB.ROW_H - 2
                    width: paper.width - x - 10
                    height: 1
                    color: "#553fa7c4"
                }
            }

            // punched holes (you see the cork through them)
            Repeater {
                model: root.holes ? Math.max(2, Math.floor(paper.height / 40)) : 0
                delegate: Rectangle {
                    required property int index
                    x: 10; y: 14 + index * 40
                    width: 10; height: 10; radius: 5
                    color: ScrapbookTheme.corkDark
                    border.width: 1
                    border.color: "#664a4536"
                }
            }

            // polaroid "photo"
            Rectangle {
                visible: root.photo
                x: 10; y: 10
                width: paper.width - 20; height: 52
                radius: 3
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: ScrapbookTheme.tapeTeal }
                    GradientStop { position: 1.0; color: ScrapbookTheme.tapePink }
                }
                MaterialIcon {
                    anchors.centerIn: parent
                    name: root.note.icon
                    size: 32
                    color: "#ffffff"
                }
            }
        }

        // ===== title =====
        Row {
            x: root.padL
            y: root.padTop
            spacing: 8
            MaterialIcon {
                visible: !root.photo
                name: root.note.icon
                size: 20
                color: ScrapbookTheme.ink
            }
            Text {
                text: root.note.title
                font.family: Theme.fontFamily
                font.pixelSize: 16
                font.bold: true
                color: ScrapbookTheme.ink
            }
        }

        // ===== rows =====
        Repeater {
            model: root.rows
            delegate: Item {
                id: rowItem
                required property var modelData
                required property int index

                x: root.padL
                y: root.rowsTop + index * CB.ROW_H
                width: sheet.width - root.padL - 14
                height: CB.ROW_H
                opacity: (!root.filtering || root.flags[index]) ? 1 : 0.3
                Behavior on opacity { NumberAnimation { duration: 140 } }

                Row {
                    id: capRow
                    spacing: 4
                    anchors.verticalCenter: parent.verticalCenter

                    Repeater {
                        model: rowItem.modelData.mods.concat(rowItem.modelData.caps)
                        delegate: Item {
                            id: capItem
                            required property string modelData
                            readonly property bool dots: modelData === "…"
                            readonly property bool isMod: CB.MODS.some(m => m[0] === modelData)

                            width: dots ? 12 : Math.max(22, capText.implicitWidth + 12)
                            height: 24

                            Rectangle { // hard bottom edge
                                visible: !capItem.dots
                                y: 2
                                width: parent.width; height: 22; radius: 5
                                color: ScrapbookTheme.ink
                                opacity: 0.55
                            }
                            Rectangle { // the cap
                                visible: !capItem.dots
                                width: parent.width; height: 22; radius: 5
                                color: capItem.isMod ? "#dff0f1" : "#fffdf7"
                                border.width: 1.5
                                border.color: ScrapbookTheme.ink
                            }
                            Text {
                                id: capText
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: capItem.dots ? 0 : -1
                                text: capItem.modelData
                                font.family: Theme.fontFamily
                                font.pixelSize: capItem.dots ? 14 : 11
                                font.bold: true
                                color: ScrapbookTheme.ink
                            }
                        }
                    }
                }

                Text {
                    anchors.left: capRow.right
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.rightMargin: rowItem.modelData.dup ? 64 : 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: rowItem.modelData.label
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: ScrapbookTheme.ink
                }

                // two binds share this combo
                Rectangle {
                    visible: rowItem.modelData.dup
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 58; height: 20; radius: 3
                    color: "transparent"
                    border.width: 2
                    border.color: "#c0392b"
                    rotation: -8
                    Text {
                        anchors.centerIn: parent
                        text: "DOUBLE!"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.bold: true
                        color: "#c0392b"
                    }
                }
            }
        }

        // ===== what holds it up =====
        Item { // push-pin
            visible: !root.taped
            x: Math.round(sheet.width / 2) - 10
            y: -9
            width: 20; height: 20
            z: 5
            Rectangle { x: 3; y: 4; width: 18; height: 18; radius: 9; color: "#55000000" }
            Rectangle {
                width: 18; height: 18; radius: 9
                color: root.pinColors[root.slot % 5]
                border.width: 1.5
                border.color: Qt.darker(root.pinColors[root.slot % 5], 1.55)
            }
            Rectangle { x: 4; y: 3; width: 6; height: 5; radius: 3; color: "#99ffffff" }
        }

        WashiTape {
            visible: root.taped
            x: Math.round(sheet.width / 2) - width / 2
            y: -13
            width: 76; height: 24
            z: 5
            rotation: root.tilts[(root.slot + 2) % 5] * 1.6
            color: root.pinColors[(root.slot + 1) % 5]
        }
    }
}
