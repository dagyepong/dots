// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   A P P E A R A N C E   P A N E L                                        │
// │   wallpaper and palette picker                                           │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

import "../../theme"
import "../../services"
import "../../components"

// The wallpapers and the palettes, each as a strip (`Carousel`): the tile in
// the middle large, its neighbours stepping away. Left and Right slide, Enter
// applies. The palettes are the page below the wallpapers: Down and Up switch,
// as does the second shortcut, and the chevron in the footer does it with the
// pointer.
//
// The wallpaper directory is rescanned whenever the panel opens, so there is
// no refresh button.
FocusScope {
    id: root

    signal closed()
    signal panelRequested(string panel)

    // `wallpaper` or `palette`. Bound to the name the panel was opened under,
    // so the shortcut and the arrows both slide a panel that is already open.
    property string page: "wallpaper"
    readonly property bool onPalette: root.page === "palette"

    readonly property int gap: 12
    readonly property int tileWidth: 160
    readonly property int tileHeight: 100
    readonly property real centreScale: 1.25
    readonly property int daub: 12
    readonly property int loadReach: 8

    readonly property Carousel strip: root.onPalette ? palettes : wallpapers

    readonly property var centredWallpaper: WallpaperService.wallpapers[wallpapers.current] ?? null
    readonly property var centredPalette: ThemeService.availableThemes[palettes.current] ?? null

    Component.onCompleted: {
        WallpaperService.scan()
        root.forceActiveFocus()
    }

    // Initial values for the strips' `current`, so they open on what is
    // applied instead of sliding there from the first tile. `settle` follows
    // the list when the scan returns a moment after opening.
    readonly property int appliedWallpaper: Math.max(0, WallpaperService.wallpapers.findIndex(
        entry => entry.path === WallpaperService.currentWallpaper))
    readonly property int activePalette: Math.max(0, ThemeService.availableThemes.findIndex(
        entry => entry.id === ThemeService.activeId))

    function settle(): void {
        wallpapers.goTo(root.appliedWallpaper)
        palettes.goTo(root.activePalette)
    }

    Connections {
        target: WallpaperService
        function onWallpapersChanged(): void { root.settle() }
        function onCurrentWallpaperChanged(): void { root.settle() }
    }

    function apply(): void {
        if (root.onPalette) {
            if (root.centredPalette)
                ThemeService.setTheme(root.centredPalette.id)
        } else if (root.centredWallpaper) {
            WallpaperService.apply(root.centredWallpaper.path)
        }
    }

    function turn(page: string): void {
        root.panelRequested(page === "palette" ? "palette" : "appearance")
    }

    // Five daubs, in the board's order: the accent and the four status hues.
    // The adaptive entry shows the current theme until the wallpaper has been
    // read.
    function daubsOf(theme: var): var {
        const colors = theme.adaptive ? ThemeService.dynamicColors : theme.colors
        return colors
            ? [colors.accent, colors.green, colors.yellow, colors.red, colors.blue]
            : [Theme.accent, Theme.green, Theme.yellow, Theme.red, Theme.blue]
    }

    Keys.onLeftPressed: root.strip.step(-1)
    Keys.onRightPressed: root.strip.step(1)
    Keys.onDownPressed: root.turn("palette")
    Keys.onUpPressed: root.turn("wallpaper")
    Keys.onReturnPressed: root.apply()
    Keys.onEnterPressed: root.apply()
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Home)
            root.strip.goTo(0)
        else if (event.key === Qt.Key_End)
            root.strip.goTo(root.strip.count - 1)
        else if (event.key === Qt.Key_PageUp)
            root.strip.step(-5)
        else if (event.key === Qt.Key_PageDown)
            root.strip.step(5)
        else
            return
        event.accepted = true
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: root.gap

        // ── STRIPS ──────────────────────────────────────────────────────────

        // Both live here, the hidden one parked a strip's height above or
        // below, so turning the page slides them past each other.
        Item {
            id: pages

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Carousel {
                id: wallpapers

                width: pages.width
                height: pages.height
                y: root.onPalette ? -pages.height : 0
                opacity: root.onPalette ? 0 : 1
                current: root.appliedWallpaper
                model: WallpaperService.wallpapers
                tileWidth: root.tileWidth
                tileHeight: root.tileHeight
                centreScale: root.centreScale
                gap: root.gap
                onActivated: root.apply()

                Behavior on y { NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing } }
                Behavior on opacity { NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing } }

                delegate: CarouselTile {
                    id: tile

                    readonly property bool applied:
                        tile.modelData.path === WallpaperService.currentWallpaper

                    ClippingRectangle {
                        anchors.fill: parent
                        contentUnderBorder: true
                        radius: Theme.radiusMedium
                        color: Theme.islandSurface
                        border.color: tile.centred ? Theme.accent : Theme.islandBorder
                        border.width: tile.centred ? 2 : 1

                        Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

                        // Only tiles near the middle load a picture: decoding
                        // every wallpaper on open leaves the visible ones
                        // black for over a second. Qt caches decoded images,
                        // so stepping back does not read them again.
                        Image {
                            anchors.fill: parent
                            source: Math.abs(tile.distance) <= root.loadReach
                                ? `file://${tile.modelData.path}` : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: 320
                            sourceSize.height: 200
                        }

                        AppliedMark { visible: tile.applied }
                    }
                }
            }

            Carousel {
                id: palettes

                width: pages.width
                height: pages.height
                y: root.onPalette ? 0 : pages.height
                opacity: root.onPalette ? 1 : 0
                current: root.activePalette
                model: ThemeService.availableThemes
                tileWidth: root.tileWidth
                tileHeight: root.tileHeight
                centreScale: root.centreScale
                gap: root.gap
                onActivated: root.apply()

                Behavior on y { NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing } }
                Behavior on opacity { NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing } }

                delegate: CarouselTile {
                    id: card

                    readonly property bool applied: card.modelData.id === ThemeService.activeId

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusMedium
                        color: card.hovered ? Theme.islandSurfaceHover : Theme.islandSurface
                        border.color: card.centred ? Theme.accent : Theme.islandBorder
                        border.width: card.centred ? 2 : 1

                        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                        Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

                        Column {
                            anchors.centerIn: parent
                            spacing: 10

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 6

                                Repeater {
                                    model: root.daubsOf(card.modelData)

                                    Rectangle {
                                        required property var modelData

                                        width: root.daub
                                        height: root.daub
                                        radius: width / 2
                                        color: modelData
                                        border.color: Theme.hairline
                                        border.width: 1

                                        Behavior on color { ColorAnimation { duration: Theme.paletteTransition } }
                                    }
                                }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: card.modelData.name
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: card.centred ? Font.DemiBold : Font.Normal
                                color: card.centred ? Theme.text : Theme.textMuted
                            }
                        }

                        AppliedMark { visible: card.applied }
                    }
                }
            }
        }

        // ── FOOTER ──────────────────────────────────────────────────────────

        RowLayout {
            Layout.fillWidth: true
            spacing: root.gap

            Text {
                Layout.fillWidth: true
                text: root.onPalette
                    ? (root.centredPalette?.badge ?? "")
                    : (root.centredWallpaper?.name ?? "")
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.textMuted
            }

            // Position in the strip; the tile's mark already shows what is
            // applied.
            Text {
                text: root.strip.count === 0
                    ? (WallpaperService.scanning ? "Scanning…" : "")
                    : `${root.strip.current + 1}/${root.strip.count}`
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.textMuted
            }

            // Switches strips with the pointer.
            Text {
                text: root.onPalette ? "󰅃" : "󰅀"
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeRegular
                color: door.containsMouse ? Theme.text : Theme.textMuted

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                MouseArea {
                    id: door

                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.turn(root.onPalette ? "wallpaper" : "palette")
                }
            }
        }
    }

    // The check on what is applied, distinct from the accent ring, which
    // marks the position in the strip.
    component AppliedMark: Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 6
        width: 18
        height: 18
        radius: width / 2
        color: Theme.accent

        Text {
            anchors.centerIn: parent
            text: "󰄬"
            font.family: Theme.fontMono
            font.pixelSize: 10
            color: Theme.accentText
        }
    }
}
