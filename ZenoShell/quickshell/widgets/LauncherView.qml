import QtQuick
import Quickshell
import qs.theme
import qs.services

Item {
    id: root

    signal closeRequested()

    property string query: ""
    property string sector: "All"
    readonly property var results: Apps.filter(query, sector)

    function reset() {
        const initial = UiState.launcherInitial
        UiState.launcherInitial = ""
        search.text = initial
        query = initial
        sector = "All"
        list.currentIndex = 0
        search.forceActiveFocus()
        search.cursorPosition = search.text.length
    }

    function launch(item) {
        Apps.launch(item.entry)
        root.closeRequested()
    }

    function cycleSector(d) {
        const secs = Apps.visibleSectors
        const i = Math.max(0, secs.indexOf(sector))
        sector = secs[(i + d + secs.length) % secs.length]
        if (search.text !== "") search.text = ""
    }

    // ---------- Ricerca ----------
    Canvas {
        x: 20; y: 24
        width: 16; height: 16

        property color fg: Theme.muted
        onFgChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.strokeStyle = fg
            ctx.lineWidth = 1.7
            ctx.lineCap = "round"
            ctx.beginPath()
            ctx.arc(6.5, 6.5, 4.8, 0, Math.PI * 2)
            ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(10.2, 10.2)
            ctx.lineTo(14.5, 14.5)
            ctx.stroke()
        }
    }

    TextInput {
        id: search

        x: 46; y: 14
        width: root.width - 46 - 20
        height: 36
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: 14
        clip: true
        selectByMouse: true

        onTextChanged: {
            root.query = text
            list.currentIndex = 0
        }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Down) {
                list.currentIndex = Math.min(list.count - 1, list.currentIndex + 1)
                event.accepted = true
            } else if (event.key === Qt.Key_Up) {
                list.currentIndex = Math.max(0, list.currentIndex - 1)
                event.accepted = true
            } else if (event.key === Qt.Key_PageDown) {
                list.currentIndex = Math.min(list.count - 1, list.currentIndex + 5)
                event.accepted = true
            } else if (event.key === Qt.Key_PageUp) {
                list.currentIndex = Math.max(0, list.currentIndex - 5)
                event.accepted = true
            } else if (event.key === Qt.Key_Tab) {
                root.cycleSector(1)
                event.accepted = true
            } else if (event.key === Qt.Key_Backtab) {
                root.cycleSector(-1)
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (list.count > 0 && list.currentIndex < root.results.length)
                    root.launch(root.results[list.currentIndex])
                event.accepted = true
            } else if (event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier)) {
                // Ctrl+F: adds/removes the selected app from favorites
                if (list.count > 0 && list.currentIndex < root.results.length)
                    Apps.toggleFavorite(root.results[list.currentIndex].id)
                event.accepted = true
            } else if (event.key === Qt.Key_Escape) {
                root.closeRequested()
                event.accepted = true
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: search.text === ""
            text: "Search…"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 14
        }
    }

    Rectangle {
        x: 14; y: 56
        width: root.width - 28
        height: 1
        color: Theme.border
    }

    // ---------- Settori (sinistra) ----------
    Flickable {
        x: 14; y: 66
        width: 116
        height: root.height - 66 - 14
        contentHeight: sideCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: sideCol
            width: parent.width
            spacing: 3

            Repeater {
                model: Apps.visibleSectors

                delegate: Rectangle {
                    id: chip

                    required property string modelData
                    readonly property bool selected: root.query === "" && root.sector === modelData

                    width: sideCol.width
                    height: 30
                    radius: 15
                    color: selected ? Theme.accent
                                    : (chipMouse.containsMouse ? Theme.islandHover : "transparent")
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Text {
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: chip.modelData
                        color: chip.selected ? Theme.island : Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.bold: chip.selected
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: Apps.count(chip.modelData)
                        color: chip.selected ? Theme.island : Theme.muted
                        opacity: chip.selected ? 0.7 : 1
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }

                    MouseArea {
                        id: chipMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.sector = chip.modelData
                            search.text = ""
                            search.forceActiveFocus()
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        x: 138; y: 68
        width: 1
        height: root.height - 68 - 16
        color: Theme.border
    }

    // ---------- App (destra) ----------
    ListView {
        id: list

        x: 148; y: 66
        width: root.width - 148 - 14
        height: root.height - 66 - 14
        spacing: 2
        clip: true
        model: root.results
        currentIndex: 0
        keyNavigationEnabled: false
        boundsBehavior: Flickable.StopAtBounds

        onCountChanged: if (currentIndex >= count) currentIndex = Math.max(0, count - 1)
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

        delegate: Rectangle {
            id: row

            required property var modelData
            required property int index
            readonly property bool current: ListView.isCurrentItem

            width: ListView.view.width
            height: 48
            radius: 14
            color: current ? Theme.surfaceSoft : "transparent"

            Rectangle {
                x: 0; y: 13
                width: 3; height: 22
                radius: 2
                color: Theme.accent
                visible: row.current
            }

            Image {
                x: 14; y: 10
                width: 28; height: 28
                source: Quickshell.iconPath(row.modelData.icon, "application-x-executable")
                sourceSize: Qt.size(56, 56)
                smooth: true
            }

            Column {
                x: 54
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 54 - 40
                spacing: 1

                Text {
                    width: parent.width
                    text: row.modelData.name
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: row.modelData.sub
                    visible: text !== ""
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }

            // Click: opens the app. Right click: toggle favorite
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onPositionChanged: list.currentIndex = row.index
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) Apps.toggleFavorite(row.modelData.id)
                    else root.launch(row.modelData)
                }
            }

            // Star: filled if favorite, empty (click to add) on the selected row
            Item {
                id: star

                readonly property bool fav: Apps.isFavorite(row.modelData.id)

                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 26; height: 26
                visible: fav || row.current

                Glyph {
                    anchors.centerIn: parent
                    kind: "star"
                    level: star.fav ? 1 : 0
                    size: 14
                    color: star.fav ? Theme.accent : Theme.muted
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Apps.toggleFavorite(row.modelData.id)
                }
            }
        }
    }

    Text {
        x: 148; y: 66
        width: root.width - 148 - 14
        height: 60
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        visible: root.results.length === 0
        wrapMode: Text.WordWrap
        text: root.query !== "" ? "No apps found"
              : (root.sector === "Favorites" ? "No favorites yet: press Ctrl+F or right-click an app"
              : (root.sector === "Recent" ? "No recent apps: open one from the launcher"
              : "No apps found"))
        color: Theme.muted
        opacity: 0.7
        font.family: Theme.fontFamily
        font.pixelSize: 12
    }
}
