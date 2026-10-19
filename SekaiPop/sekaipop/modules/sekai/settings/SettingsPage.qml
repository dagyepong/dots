import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sekai.phone

// The frame every Settings page is built on: a scrolling column of
// SectionCards (mouse wheel or drag), with a slim scroll bar on its right
// edge and soft fades where the cards slide under the top and bottom of the
// area. A page is just
//
//   SettingsPage {
//       SectionCard { title: "..."; ... }
//       SectionCard { title: "..."; ... }
//   }
//
// When a page has two or more titled cards, a slim row of jump chips sits
// above them (one per card, in the card's own colour; the card in view is lit;
// click to scroll there; the row scrolls sideways if there are many).
//
// `tileWidth` is the width of one toggle tile / stepper so that three fit
// across a card; pages read it instead of working it out themselves.
Item {
    id: page

    // The Face the page lives in (its sources and requests); set by the Face.
    property var host: null

    default property alias content: column.data

    // Card width less its padding and shadow, split three ways with 16 between.
    readonly property real cardWidth: width - 14
    readonly property real tileWidth: Math.floor((cardWidth - 5 - 52 - 16 * 2) / 3) - 6

    // Two across, and the whole width, inside a card (sliders, notes).
    readonly property real halfWidth: Math.floor((cardWidth - 5 - 52 - 16) / 2)
    readonly property real fullWidth: cardWidth - 5 - 52

    // What the cards sit on, for the fades.
    readonly property color fadeColor: host && host.backdropColor !== undefined ? host.backdropColor : Theme.pSurface

    // Scrolled back to the top (the Face does this when the panel is opened).
    function scrollToTop() {
        scrollAnim.stop()
        page.pinned = -1
        flick.contentY = 0
    }

    // The column the cards are in, for the Settings search.
    readonly property Item cards: column

    function scrollToItem(it) {
        const max = Math.max(0, flick.contentHeight - flick.height)
        const to = Math.max(0, Math.min(max, column.y + it.mapToItem(column, 0, 0).y - 90))
        scrollAnim.stop()
        page.pinned = -1
        scrollAnim.from = flick.contentY
        scrollAnim.to = to
        scrollAnim.start()
    }

    // ----- the jump chips -----
    // The titled cards that are showing, in order. Re-read when the column's
    // height or its children change (a card switched on or off).
    // Only replaced when something in it really changed, so the chips are not
    // rebuilt every time a card's height wobbles.
    property var sections: []
    property string sectionSig: ""

    function refreshSections() {
        // A page that is not showing (built in the background, or the menu is
        // up) counts all its cards as hidden, so there is nothing to read yet;
        // onVisibleChanged below reads again the moment it shows.
        if (!page.visible)
            return
        const out = []
        const kids = column.children
        for (let i = 0; i < kids.length; i++) {
            const c = kids[i]
            if (c.isSectionCard === true && c.visible && c.height > 0 && c.title !== "")
                out.push({ title: String(c.title), y: Math.round(c.y), accent: String(c.accent) })
        }
        const sig = JSON.stringify(out)
        if (sig === page.sectionSig)
            return
        page.sectionSig = sig
        page.sections = out
        console.log("settings chips:", out.length, out.map(x => x.title).join(" | "))
    }

    onVisibleChanged: {
        if (visible)
            Qt.callLater(page.refreshSections)
    }
    readonly property bool showChips: sections.length > 1
    // Room the row takes above the cards (12 is what the page always had).
    readonly property real topGap: showChips ? 60 : 12

    // A chip you clicked stays lit until you scroll by hand: the last cards of
    // a page are short, so the page can't always bring the one you picked to
    // the top, and "at the bottom" used to light the last chip instead.
    property int pinned: -1
    property real pinnedY: 0

    // The last card whose top has passed the top of the view.
    readonly property int activeIdx: {
        if (page.pinned >= 0 && page.pinned < sections.length)
            return page.pinned
        let a = 0
        const y = flick.contentY + 40
        for (let i = 0; i < sections.length; i++) {
            if (column.y + sections[i].y - 22 <= y)
                a = i
        }
        // at the very bottom the last card counts, even if it is short
        if (flick.contentHeight - flick.height > 1 && flick.contentY >= flick.contentHeight - flick.height - 2)
            a = Math.max(0, sections.length - 1)
        return a
    }

    function scrollToSection(i) {
        if (i < 0 || i >= sections.length)
            return
        const max = Math.max(0, flick.contentHeight - flick.height)
        const to = Math.max(0, Math.min(max, column.y + sections[i].y - 30))
        scrollAnim.stop()
        page.pinned = i
        page.pinnedY = to
        scrollAnim.from = flick.contentY
        scrollAnim.to = to
        scrollAnim.start()
    }

    onActiveIdxChanged: {
        const it = chipRep.itemAt(activeIdx)
        if (!it)
            return
        const w = chipStrip.width
        if (it.x < chipStrip.contentX + 6)
            chipStrip.contentX = Math.max(0, it.x - 6)
        else if (it.x + it.width > chipStrip.contentX + w - 6)
            chipStrip.contentX = Math.max(0, Math.min(chipStrip.contentWidth - w, it.x + it.width - w + 6))
    }

    Connections {
        target: column
        // Later, once the column has laid the cards out (their y is current).
        function onImplicitHeightChanged() { Qt.callLater(page.refreshSections) }
        function onChildrenChanged() { Qt.callLater(page.refreshSections) }
    }

    Component.onCompleted: Qt.callLater(page.refreshSections)

    NumberAnimation {
        id: scrollAnim
        target: flick
        property: "contentY"
        duration: 300
        easing.type: Easing.OutCubic
    }

    WheelScroll { scroller: flick }
    Flickable {
        id: flick
        y: page.topGap
        width: parent.width
        height: parent.height - page.topGap
        contentWidth: width
        contentHeight: column.y + column.implicitHeight + 34
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        onContentYChanged: {
            PanelActivity.touch()
            // moved by hand (not by a chip's glide): let the view decide again
            if (page.pinned >= 0 && !scrollAnim.running && Math.abs(flick.contentY - page.pinnedY) > 3)
                page.pinned = -1
        }
        onMovementStarted: scrollAnim.stop()

        Column {
            id: column
            x: 2
            y: 30
            width: page.cardWidth
            spacing: 44
        }
    }

    // The jump chips: a row of the same bouncy keycaps as the rest of the
    // Settings pages (SettingChip), above the cards, only when there is more
    // than one titled card. They press in and spring back when clicked, and the
    // one for the card in view is lit and pulses as it takes over.
    Flickable {
        id: chipStrip

        visible: page.showChips
        x: 0
        y: 3
        width: page.width
        height: 50
        contentWidth: chipRow.width + 14
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                const d = Theme.wheelPx(event, true)
                chipStrip.contentX = Math.max(0, Math.min(chipStrip.contentWidth - chipStrip.width, chipStrip.contentX - d))
            }
        }

        Row {
            id: chipRow
            x: 6
            y: 2
            spacing: 10

            Repeater {
                id: chipRep
                model: page.sections

                delegate: SettingChip {
                    id: chip

                    required property var modelData
                    required property int index

                    capH: 42
                    label: chip.modelData.title
                    selected: chip.index === page.activeIdx
                    onClicked: page.scrollToSection(chip.index)
                }
            }
        }
    }

    // soft fades over the cards at the top and the bottom
    Rectangle {
        y: page.topGap
        width: parent.width
        height: 18
        opacity: flick.contentY > 2 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
        gradient: Gradient {
            GradientStop { position: 0.0; color: page.fadeColor }
            GradientStop { position: 1.0; color: Qt.rgba(page.fadeColor.r, page.fadeColor.g, page.fadeColor.b, 0) }
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 26
        opacity: flick.contentY < flick.contentHeight - flick.height - 2 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(page.fadeColor.r, page.fadeColor.g, page.fadeColor.b, 0) }
            GradientStop { position: 1.0; color: page.fadeColor }
        }
    }

    // The scroll bar: the same slim round bar as the Quick Panel's notification
    // list (6 wide, the panel's ring gray), only there when there is more than
    // fits. It follows the scrolling area (below the jump chips), not the whole
    // page, and sits just right of the cards.
    Rectangle {
        readonly property real track: flick.height - 16
        visible: flick.visibleArea.heightRatio < 1
        x: page.width - 8
        y: flick.y + 8 + flick.visibleArea.yPosition * track
        width: 6
        height: Math.max(30, flick.visibleArea.heightRatio * track)
        radius: 3
        color: Theme.pSurfaceRing
        antialiasing: true
    }
}
