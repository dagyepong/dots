import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Edit Desktop's BAR tab (EditTray.qml). On the left, loose on the shelf with
// no box round them: the bar's STYLE (Float / Straight / Transparent / Capsule)
// and its POSITION (top / right / bottom / left), a row of four little screen
// drawings each (EditPickKey.qml, the same ScreenGlyph the Settings Panel uses). Click one and
// the bar changes at once; hovering one shows its name. They are the very same
// switches as Settings Panel -> Bar -> Style / Position (BarStyleService.qml and
// BarPositionService.qml), so the two always agree. To the right: arrange the bar's modules into its
// three zones, LEFT, CENTER and RIGHT (on a standing bar: top, middle and
// bottom), or take them off the bar. One lane per zone plus an OFF lane, one
// keycap per module (EditBarChip.qml):
//
//   drag a keycap     move it, within its lane or into another one; drop it
//                     in OFF to take it off the bar, or from OFF onto a zone
//                     to put it back
//   click a keycap    on the bar: send it to the next zone; in OFF: put it back
//   right click       take it off the bar
//   RESET             the default bar (its modules back on, in the default order)
//   CLEAR ALL         every module off the bar (they land in OFF; RESET brings the default back)
//
// "Off the bar" is the very same switch as Settings Panel -> Bar -> Modules
// (SettingsService "bar.<module>"), so the two always agree (with separate bars
// OFF is this monitor's own list: the Settings switch stays the master one). A module that is
// off remembers its zone; putting it back by click returns it there. The
// arrangement is BarLayoutService.qml's (saved; shared by every monitor's bar,
// unless Settings -> Bar -> "Separate bar per monitor" is on, then this shelf
// edits the bar of the monitor it is open on and no other); the bar in the card
// above follows it as soon as a keycap lands.
Item {
    id: root

    // The monitor this shelf is open on (the bar it edits when the bars are separate).
    readonly property string screenName: EditMode.screenName

    readonly property var zoneNames: ["left", "center", "right"]
    // The lanes, left to right: the three zones, then the modules that are off.
    readonly property var laneNames: ["left", "center", "right", "off"]
    readonly property var zoneTitles: ({ left: "LEFT", center: "CENTER", right: "RIGHT", off: "OFF" })
    readonly property real laneGap: 12
    readonly property real chipH: 32

    // ===== style and position =====
    // The strip of controls on the left, and the open space before the lanes
    // start. The lanes get what is left (lanesW).
    readonly property real ctlW: 244
    readonly property real ctlGap: 26
    readonly property real lanesW: Math.max(0, root.width - root.ctlW - root.ctlGap)

    // What the pointer is over ("" = nothing), so the heading can name it.
    property string styleHover: ""
    property string positionHover: ""

    // ===== keycap sizes =====
    readonly property real flowSpacing: 8
    // The keycaps start 34px down in a lane and keep 10px clear of its bottom edge.
    readonly property int maxRows: Math.max(1, Math.floor((root.height - 34 - 10 + root.flowSpacing) / (root.chipH + root.flowSpacing)))
    property var chipWidths: ({})
    property real iconW: 44

    function measure() {
        const o = {}
        let changed = false
        for (let i = 0; i < measurer.count; i++) {
            const c = measurer.itemAt(i)
            if (!c)
                continue
            o[c.moduleId] = c.fullWidth
            if (root.chipWidths[c.moduleId] !== c.fullWidth)
                changed = true
            if (root.iconW !== c.iconWidth)
                root.iconW = c.iconWidth
        }
        if (changed)
            root.chipWidths = o
    }

    Repeater {
        id: measurer
        model: BarLayoutService.modules

        EditBarChip {
            required property var modelData

            visible: false
            moduleId: modelData.id
            onFullWidthChanged: root.measure()
        }

        onItemAdded: root.measure()
    }

    function chipWidth(id, compact) {
        return compact ? root.iconW : (root.chipWidths[id] ?? 120)
    }

    // ===== lane sizes =====
    function weight(zone) {
        return Math.max(2, root.idsIn(zone).length + 0.5)
    }

    // How many rows `ids` take when they are wrapped at `w` pixels (the same
    // rule as the Flow the lanes use).
    function rowsFor(ids, w, compact) {
        let rows = 1
        let x = 0
        for (const id of ids) {
            const cw = root.chipWidth(id, compact)
            if (x > 0 && x + cw > w) {
                rows++
                x = 0
            }
            x += cw + root.flowSpacing
        }
        return rows
    }

    // The narrowest the lane can be while its keycaps still fit in maxRows.
    function laneMin(zone, compact) {
        const ids = root.idsIn(zone)
        if (ids.length === 0)
            return 120
        let lo = 0
        let hi = 0
        for (const id of ids) {
            lo = Math.max(lo, root.chipWidth(id, compact))
            hi += root.chipWidth(id, compact) + root.flowSpacing
        }
        while (lo < hi) {
            const mid = Math.floor((lo + hi) / 2)
            if (root.rowsFor(ids, mid, compact) <= root.maxRows)
                hi = mid
            else
                lo = mid + 1
        }
        return lo + 28
    }

    // When the keycaps with their names would not all fit (a small screen, or
    // a lane with many in it), every keycap shows only its icon instead: the
    // name is in the tooltip. Nothing ever has to scroll or leave its lane.
    readonly property bool compact: {
        let sum = 0
        for (const z of root.laneNames)
            sum += root.laneMin(z, false)
        return root.lanesW > 0 && sum > root.lanesW - 3 * root.laneGap
    }

    function laneWidth(zone) {
        const avail = root.lanesW - 3 * root.laneGap
        let sumMin = 0
        let sumWeight = 0
        for (const z of root.laneNames) {
            sumMin += root.laneMin(z, root.compact)
            sumWeight += root.weight(z)
        }
        const mine = root.laneMin(zone, root.compact)
        if (sumMin >= avail)
            return Math.max(60, avail * mine / sumMin)
        return mine + (avail - sumMin) * root.weight(zone) / sumWeight
    }

    // ===== the name of an icon-only keycap =====
    property string tipId: ""
    property real tipX: 0
    property real tipY: 0

    function showTip(id, item) {
        const p = item.mapToItem(root, item.width / 2, 0)
        root.tipId = id
        root.tipX = p.x
        root.tipY = p.y
    }

    function hideTip(id) {
        if (root.tipId === id)
            root.tipId = ""
    }

    // ===== what is where =====
    function isOn(id) {
        return BarLayoutService.isOn(id, root.screenName)
    }

    // The keycaps of a lane, in order: the modules that are on the bar and sit
    // in that zone, or (for "off") every module that has been taken off.
    function idsIn(zone) {
        if (zone === "off")
            return BarLayoutService.modules.map(m => m.id).filter(id => !root.isOn(id))
        return BarLayoutService.layoutFor(root.screenName)[zone].filter(id => root.isOn(id))
    }

    // Where in the zone's full list (which also holds the modules that are
    // off) the `before`-th visible keycap is: `track` counts only what you see.
    function fullIndex(zone, id, before) {
        const full = BarLayoutService.layoutFor(root.screenName)[zone].filter(x => x !== id)
        const vis = full.filter(x => root.isOn(x))
        if (before < vis.length)
            return full.indexOf(vis[before])
        return vis.length > 0 ? full.indexOf(vis[vis.length - 1]) + 1 : full.length
    }

    // ===== dragging =====
    property string dragId: ""
    // The pointer, and where on the keycap it took hold, in this item's pixels.
    property real dragX: 0
    property real dragY: 0
    property real grabX: 0
    property real grabY: 0
    // Where it would land right now ("" = nowhere, it would be dropped back).
    property string dropZone: ""
    property int dropIndex: 0
    property real markerX: 0
    property real markerY: 0

    function beginDrag(id, gx, gy) {
        root.tipId = ""
        root.dragId = id
        root.grabX = gx
        root.grabY = gy
        root.dropZone = ""
    }

    function laneAt(px) {
        let best = 0
        let bestDist = 1e9
        for (let i = 0; i < 4; i++) {
            const l = lanes.itemAt(i)
            if (!l)
                continue
            const lx = laneRow.x + l.x
            const d = px < lx ? lx - px : (px > lx + l.width ? px - (lx + l.width) : 0)
            if (d < bestDist) {
                bestDist = d
                best = i
            }
        }
        return best
    }

    // Works out where the dragged keycap would land: the lane under the
    // pointer, and its place among that lane's other keycaps (reading order:
    // a keycap is "before" the pointer when it is on a row above it, or on the
    // same row and left of it).
    function track(px, py) {
        root.dragX = px
        root.dragY = py
        // Far above or below the shelf: let go there and nothing happens.
        if (py < -90 || py > root.height + 50) {
            root.dropZone = ""
            return
        }
        const li = root.laneAt(px)
        const lane = lanes.itemAt(li)
        if (!lane)
            return
        const zone = root.laneNames[li]
        // OFF has no order: dropping anywhere in it is enough.
        if (zone === "off") {
            root.dropZone = "off"
            root.dropIndex = 0
            return
        }
        const ids = root.idsIn(zone)

        let before = 0
        let mx = laneRow.x + lane.x + 14
        let my = 34
        for (let i = 0; i < ids.length; i++) {
            if (ids[i] === root.dragId)
                continue
            const c = lane.chipAt(i)
            if (!c)
                continue
            const p = c.mapToItem(root, 0, 0)
            const belowRow = py > p.y + root.chipH
            const inRow = !belowRow && py >= p.y
            if (belowRow || (inRow && px > p.x + c.width / 2)) {
                before++
                mx = p.x + c.width + 5
                my = p.y
            } else {
                mx = p.x - 5
                my = p.y
                break
            }
        }
        root.dropZone = zone
        root.dropIndex = before
        root.markerX = mx
        root.markerY = my
    }

    function endDrag() {
        const id = root.dragId
        const zone = root.dropZone
        const index = root.dropIndex
        root.dragId = ""
        root.dropZone = ""
        if (id === "" || zone === "")
            return
        // (After this handler: the keycap that is being let go is rebuilt by the move.)
        Qt.callLater(() => {
            if (zone === "off") {
                BarLayoutService.setOff(id, true, root.screenName)
                return
            }
            // Dropped from OFF (or back on the bar): switch it on first.
            BarLayoutService.setOff(id, false, root.screenName)
            BarLayoutService.move(id, zone, root.fullIndex(zone, id, index), root.screenName)
        })
    }

    function cancelDrag() {
        root.dragId = ""
        root.dropZone = ""
    }

    // A click: on the bar, on to the next zone (at its end); in OFF, back on the
    // bar in the zone it had.
    function nudge(id) {
        if (!root.isOn(id)) {
            Qt.callLater(() => BarLayoutService.setOff(id, false, root.screenName))
            return
        }
        const next = root.zoneNames[(root.zoneNames.indexOf(BarLayoutService.zoneOf(id, root.screenName)) + 1) % 3]
        Qt.callLater(() => BarLayoutService.move(id, next, 9999, root.screenName))
    }

    // Right click: off the bar.
    function remove(id) {
        if (root.isOn(id))
            Qt.callLater(() => BarLayoutService.setOff(id, true, root.screenName))
    }

    // ===== style and position =====
    readonly property var styleOptions: [
        { id: "float", label: "Float", variant: "float" },
        { id: "straight", label: "Straight", variant: "straight" },
        { id: "transparent", label: "Transparent", variant: "transparent" },
        { id: "capsule", label: "Capsule", variant: "capsule" }
    ]

    readonly property var positionOptions: [
        { id: "top", label: "Top" },
        { id: "right", label: "Right" },
        { id: "bottom", label: "Bottom" },
        { id: "left", label: "Left" }
    ]

    function labelFor(options, id) {
        for (const o of options) {
            if (o.id === id)
                return o.label
        }
        return ""
    }

    Column {
        id: controls
        x: 6
        width: root.ctlW - 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: 26

        Column {
            spacing: 9

            EditPickHead {
                title: "STYLE"
                value: root.styleHover !== "" ? root.labelFor(root.styleOptions, root.styleHover)
                    : root.labelFor(root.styleOptions, BarStyleService.style)
            }

            Row {
                spacing: 8

                Repeater {
                    model: root.styleOptions

                    EditPickKey {
                        required property var modelData

                        // The drawing needs an edge; style is shown on the top one, as in Settings.
                        edge: "top"
                        variant: modelData.variant
                        on: BarStyleService.style === modelData.id
                        onPicked: BarStyleService.setStyle(modelData.id)
                        onHoveredChanged: {
                            if (hovered)
                                root.styleHover = modelData.id
                            else if (root.styleHover === modelData.id)
                                root.styleHover = ""
                        }
                    }
                }
            }
        }

        Column {
            spacing: 9

            EditPickHead {
                title: "POSITION"
                value: root.positionHover !== "" ? root.labelFor(root.positionOptions, root.positionHover)
                    : root.labelFor(root.positionOptions, BarPositionService.position)
            }

            Row {
                spacing: 8

                Repeater {
                    model: root.positionOptions

                    EditPickKey {
                        required property var modelData

                        edge: modelData.id
                        on: BarPositionService.position === modelData.id
                        onPicked: BarPositionService.setPosition(modelData.id)
                        onHoveredChanged: {
                            if (hovered)
                                root.positionHover = modelData.id
                            else if (root.positionHover === modelData.id)
                                root.positionHover = ""
                        }
                    }
                }
            }
        }
    }

    // ===== the lanes =====
    Row {
        id: laneRow
        x: root.ctlW + root.ctlGap
        spacing: root.laneGap

        Repeater {
            id: lanes
            model: root.laneNames

            Item {
                id: lane

                required property string modelData
                readonly property string zone: lane.modelData
                readonly property bool hot: root.dragId !== "" && root.dropZone === lane.zone

                width: root.laneWidth(lane.zone)
                height: root.height

                Behavior on width {
                    NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
                }

                function chipAt(i) {
                    return rep.itemAt(i)
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 16
                    color: lane.hot ? Qt.alpha(Theme.accentMint, 0.2) : Theme.pSurfaceHover
                    border.width: 2
                    border.color: lane.hot ? Theme.accentMint : Theme.pSurfaceDivider
                    antialiasing: true

                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }
                }

                Text {
                    x: 16
                    y: 9
                    text: root.zoneTitles[lane.zone]
                    color: Theme.pInk
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                    font.letterSpacing: 1.2
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.idsIn(lane.zone).length === 0 && root.dragId === ""
                    text: lane.zone === "off" ? "nothing removed" : "drop modules here"
                    color: Theme.pInkSub
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                Flow {
                    x: 14
                    y: 34
                    width: lane.width - 28
                    spacing: root.flowSpacing

                    Repeater {
                        id: rep
                        model: root.idsIn(lane.zone)

                        EditBarChip {
                            required property string modelData

                            moduleId: modelData
                            editor: root
                            iconOnly: root.compact
                            lifted: root.dragId === modelData
                            off: lane.zone === "off"
                        }
                    }
                }
            }
        }
    }

    // ===== RESET and CLEAR ALL =====
    Row {
        id: keyRow
        layoutDirection: Qt.RightToLeft
        spacing: 8
        x: root.width - keyRow.width - 12
        y: 6

        Item {
            id: resetKey
            visible: (BarLayoutService.customizedFor(root.screenName) || root.idsIn("off").some(id => BarLayoutService.onByDefault(id))) && root.dragId === ""
            width: 78
            height: 26

            Pill {
                anchors.fill: parent
                cornerRadius: 9
                ringWidth: 3
                shadowDy: 3
                pressed: resetArea.pressed
                fillColor: resetArea.containsMouse ? Theme.pSurfaceHover : Theme.pSurface

                Row {
                    anchors.centerIn: parent
                    spacing: 4

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "restart_alt"
                        size: 13
                        weight: 700
                        color: Theme.pInk
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "RESET"
                        color: Theme.pInk
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.ExtraBold
                        font.styleName: Theme.fontStyleBold
                        font.letterSpacing: 0.6
                    }
                }
            }

            MouseArea {
                id: resetArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor
                onClicked: BarLayoutService.resetAll(root.screenName)
            }
        }

        Item {
            id: clearKey
            visible: root.dragId === "" && root.zoneNames.some(z => root.idsIn(z).length > 0)
            width: 92
            height: 26

            Pill {
                anchors.fill: parent
                cornerRadius: 9
                ringWidth: 3
                shadowDy: 3
                pressed: clearArea.pressed
                fillColor: clearArea.containsMouse ? Theme.pSurfaceHover : Theme.pSurface

                Row {
                    anchors.centerIn: parent
                    spacing: 4

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "delete_sweep"
                        size: 13
                        weight: 700
                        color: Theme.pInk
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "CLEAR ALL"
                        color: Theme.pInk
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.ExtraBold
                        font.styleName: Theme.fontStyleBold
                        font.letterSpacing: 0.6
                    }
                }
            }

            MouseArea {
                id: clearArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor
                onClicked: BarLayoutService.clearAll(root.screenName)
            }
        }
    }

    // ===== where it would land =====
    Rectangle {
        visible: root.dragId !== "" && root.dropZone !== "" && root.dropZone !== "off"
        x: root.markerX - 2
        y: root.markerY - 2
        width: 4
        height: root.chipH + 4
        radius: 2
        color: Theme.accentMint
        border.width: 1
        border.color: Theme.pLine
        z: 20
    }

    // ===== the keycap in the hand =====
    EditBarChip {
        visible: root.dragId !== ""
        moduleId: root.dragId
        ghost: true
        iconOnly: root.compact
        x: root.dragX - root.grabX
        y: root.dragY - root.grabY
        z: 30
    }

    // ===== the tooltip of an icon-only keycap =====
    Pill {
        id: tip
        visible: root.tipId !== "" && root.dragId === ""
        width: tipText.implicitWidth + 24
        height: 26
        cornerRadius: 9
        ringWidth: 3
        shadowDy: 3
        fillColor: Theme.pSurface
        x: Math.max(0, Math.min(root.width - tip.width, root.tipX - tip.width / 2))
        y: root.tipY - tip.height - 8
        z: 40

        Text {
            id: tipText
            anchors.centerIn: parent
            text: BarLayoutService.labelOf(root.tipId)
            color: Theme.pInk
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
        }
    }
}
