import QtQuick
import "../../common/functions/WeatherMath.js" as WM
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// The card that drops down from WeatherIndicator.qml, redesigned as a sky
// poster. Same wiring as before (Bar.qml gives it `source`, the WeatherSource;
// opening it asks for a fresh reading when the last is a few minutes old); the
// frame, focus grab, pop-in and swallow come from SekaiPopup.qml.
//
//   The plate      (SekaiPlate, the header all four bar popups share) the
//                  temperature as a white sticker numeral, today's high and
//                  low and the conditions under it, and the weather as a
//                  tilted dark disc on the right. Poke the disc: it squashes
//                  and a puff of diamonds flies out. The place hangs off the
//                  plate's lower edge on a slanted tab, the refresh key
//                  beside it.
//   The gauges     humidity as a tank that fills, the wind as a dial whose
//                  arrow turns to where the wind is going, UV as a five-
//                  diamond meter. Feels like, pressure and visibility are
//                  one slim strip under them.
//   The forecast   one switch, two views (remembered, Settings -> General ->
//                  Weather view):
//                    Hourly  the next readings as a melody: a note on a curve
//                            that rises and falls with the temperature, a
//                            rain gauge under each note, the time at the foot.
//                    Days    a song list: one row per day with its weather,
//                            high and low, a range bar on a shared scale, and
//                            the chance of rain filling the row from the left.
//                  Point at a note or a row and the line at the foot tells you
//                  the details.
//   Nothing runs on its own: the pop-ins play when the card opens or the view
//   changes, the rest answers the pointer. (The refresh arrow spins while it
//   loads.)
SekaiPopup {
    id: root

    property var source: null          // WeatherSource

    readonly property bool hasData: root.source !== null && root.source.temperatureText !== ""
    readonly property bool hourlyView: SettingsService.get("weather.view") === "hourly"
        && root.hasData && root.source.hourly.length > 0
    readonly property bool canSwitch: root.hasData && root.source.hourly.length > 0
    readonly property bool night: root.source !== null && root.source.iconName.indexOf("night") >= 0

    readonly property int pad: 16
    readonly property int innerW: 304

    // The accent as INK (icons, curve, arrow): the peach is right on the dark
    // looks but washes out on Light's pale surfaces, so it is darkened there.
    readonly property color iconInk: Theme.dark ? Theme.accentMint : Qt.darker(Theme.accentMint, 1.5)

    contentWidth: root.innerW + 2 * root.pad
    contentHeight: stack.implicitHeight + 2 * root.pad - 2

    onOpenChanged: {
        if (open && root.source)
            root.source.refreshIfStale()
        if (open) {
            root.hoverHour = -1
            root.hoverDay = -1
            // Pressed again while the card was still going away: it turns round
            // instead of replaying the pop-ins.
            if (root.reveal < 0.35)
                waveAnim.restart()
        }
    }

    // ===== the pop-ins =====
    property real wave: 1
    readonly property real waveMs: 760

    NumberAnimation {
        id: waveAnim
        target: root
        property: "wave"
        from: 0
        to: 1
        duration: root.waveMs
    }

    onHourlyViewChanged: waveAnim.restart()
    onHasDataChanged: waveAnim.restart()

    // What the pointer is on.
    property int hoverHour: -1
    property int hoverDay: -1

    readonly property var temp: WM.splitTemp(root.hasData ? root.source.temperatureText : "")
    readonly property var today: root.hasData && root.source.forecast.length > 0 ? root.source.forecast[0] : null

    // The days' shared temperature scale, for the range bars.
    readonly property var span: {
        if (!root.hasData || root.source.forecast.length === 0)
            return { lo: 0, hi: 1 }
        let lo = 1e9
        let hi = -1e9
        for (const d of root.source.forecast) {
            lo = Math.min(lo, WM.firstNumber(d.low))
            hi = Math.max(hi, WM.firstNumber(d.high))
        }
        return { lo: lo, hi: Math.max(hi, lo + 1) }
    }

    readonly property var windP: WM.windParts(root.hasData ? root.source.windText : "")
    readonly property var windArrow: WM.windArrow(root.hasData ? root.source.windText : "")
    readonly property real windNum: WM.firstNumber(root.windP.speed)
    readonly property string windUnit: String(root.windP.speed).replace(/^[\d.\s-]+/, "")
    readonly property real uv: WM.firstNumber(root.hasData ? root.source.uvText : "")

    readonly property var strip: root.hasData ? [
        { icon: "thermostat", label: "Feels like", value: root.source.feelsLikeText },
        { icon: "speed", label: "Pressure", value: root.source.pressureText },
        { icon: "visibility", label: "Visibility", value: root.source.visibilityText }
    ] : []

    // The line at the foot.
    readonly property bool showingError: root.source !== null && root.source.failed
    readonly property string readoutText: {
        if (!root.hasData)
            return ""
        if (root.hourlyView && root.hoverHour >= 0 && root.hoverHour < root.source.hourly.length) {
            const h = root.source.hourly[root.hoverHour]
            return h.label + "  ·  " + h.condition + "  ·  feels " + h.feels
        }
        if (!root.hourlyView && root.hoverDay >= 0 && root.hoverDay < root.source.forecast.length) {
            const d = root.source.forecast[root.hoverDay]
            return d.label + "  ·  " + d.condition
        }
        if (root.showingError)
            return "Couldn't refresh  ·  " + root.source.updatedText
        return root.source.updatedText
    }

    Gradient {
        id: accentGradient
        GradientStop { position: 0.0; color: Theme.accentMint }
        GradientStop { position: 1.0; color: Theme.accentCyan }
    }

    // Water in a tank: a body that thins out towards the bottom (so the ink
    // resting on it stays readable) and a bright surface line on top, so the
    // level reads at a glance. Put it in the Pill it fills; `level` is 0..1
    // (already eased), `corner` is the Pill's inner radius.
    component Water: Rectangle {
        id: water
        property real level: 0
        property real corner: 10

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: parent.height * Math.max(0, Math.min(1, water.level))
        radius: water.corner
        antialiasing: true
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(Theme.accentCyan.r, Theme.accentCyan.g, Theme.accentCyan.b, 0.36) }
            GradientStop { position: 1.0; color: Qt.rgba(Theme.accentCyan.r, Theme.accentCyan.g, Theme.accentCyan.b, 0.12) }
        }

        Rectangle {
            visible: water.height > water.corner
            x: water.corner * 0.7
            y: 1
            width: Math.max(0, water.width - water.corner * 1.4)
            height: 2
            radius: 1
            color: Qt.rgba(Theme.accentCyan.r, Theme.accentCyan.g, Theme.accentCyan.b, 0.85)
        }
    }

    // The small caps label every gauge tile carries.
    component TileLabel: Text {
        color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.78)
        font.family: Theme.fontFamily
        font.pixelSize: 9
        font.weight: Font.ExtraBold
        font.styleName: Theme.fontStyleBold
        font.letterSpacing: 0.8
        elide: Text.ElideRight
    }

    Column {
        id: stack
        x: root.pad
        y: root.pad - 2
        width: root.innerW
        spacing: 12

        // ===== the plate =====
        Item {
            id: head
            width: root.innerW
            height: 134

            SekaiPlate {
                id: plate
                width: head.width
                height: 118

                TileLabel {
                    x: 16
                    y: 11
                    width: 170
                    text: condLabel.toUpperCase()
                    color: Qt.rgba(Theme.colBorder.r, Theme.colBorder.g, Theme.colBorder.b, 0.82)
                    font.pixelSize: 11
                    font.letterSpacing: 1.4

                    readonly property string condLabel: root.hasData ? root.source.conditionText
                        : (root.source && root.source.loading ? "Loading…"
                           : (root.source && root.source.failed ? root.source.problemText : "No weather data"))
                    // (the property above is read as `condLabel` by `text`)
                }

                StickerText {
                    id: tempNum
                    x: 6
                    y: 24
                    text: root.hasData ? root.temp.num : "--"
                    pixelSize: 56
                    fillColor: plate.numberFill
                    ringColor: plate.numberRing
                }

                StickerText {
                    id: tempUnit
                    x: tempNum.x + tempNum.width - 8
                    y: 30
                    text: root.hasData ? root.temp.unit : ""
                    pixelSize: 22
                    fillColor: plate.numberFill
                    ringColor: plate.numberRing
                }

                // Today's high and low, stacked beside the number.
                Column {
                    visible: root.today !== null
                    x: tempUnit.x + tempUnit.width + 2
                    y: 56
                    spacing: 1

                    Row {
                        spacing: 0
                        MaterialIcon { anchors.verticalCenter: parent.verticalCenter; name: "arrow_upward"; size: 14; weight: 700; color: Theme.colBorder; fill: 0 }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.today ? root.today.high : ""
                            color: Theme.colBorder
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.ExtraBold
                            font.styleName: Theme.fontStyleBold
                        }
                    }
                    Row {
                        spacing: 0
                        MaterialIcon { anchors.verticalCenter: parent.verticalCenter; name: "arrow_downward"; size: 14; weight: 700; color: Theme.colBorder; fill: 0 }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.today ? root.today.low : ""
                            color: Theme.colBorder
                            opacity: 0.8
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.ExtraBold
                            font.styleName: Theme.fontStyleBold
                        }
                    }
                }

                // The weather as a tilted dark disc: poke it.
                Pill {
                    id: disc
                    x: plate.width - width - 14
                    y: 14
                    width: 82
                    height: 84
                    cornerRadius: 41
                    ringWidth: 4
                    shadowDy: 4
                    rotation: 6
                    transformOrigin: Item.Center
                    pressed: discArea.pressed
                    fillColor: Theme.chipFill

                    property real sx: 1
                    property real sy: 1

                    transform: Scale {
                        origin.x: disc.width / 2
                        origin.y: disc.height / 2
                        xScale: disc.sx
                        yScale: disc.sy
                    }

                    WeatherGlyph {
                        anchors.centerIn: parent
                        name: root.source ? root.source.iconName : "cloud"
                        size: 52
                        color: Theme.dark ? (root.night ? Theme.accentCyan : Theme.accentMint) : Theme.colBorder
                        scale: 0.5 + 0.5 * Math.min(root.reveal, 1.15)
                    }
                }

                SequentialAnimation {
                    id: squish
                    ParallelAnimation {
                        NumberAnimation { target: disc; property: "sx"; to: 1.18; duration: 80; easing.type: Easing.OutQuad }
                        NumberAnimation { target: disc; property: "sy"; to: 0.82; duration: 80; easing.type: Easing.OutQuad }
                    }
                    ParallelAnimation {
                        NumberAnimation { target: disc; property: "sx"; to: 1; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 3 }
                        NumberAnimation { target: disc; property: "sy"; to: 1; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 3 }
                    }
                }

                MouseArea {
                    id: discArea
                    x: disc.x
                    y: disc.y
                    width: disc.width
                    height: disc.height
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        squish.restart()
                        puff.fire()
                    }
                }

                Burst {
                    id: puff
                    x: disc.x + disc.width / 2
                    y: disc.y + disc.height / 2
                    radius: 66
                    count: 8
                }
            }

            // The place, hanging off the plate's lower edge.
            Text {
                id: placeProbe
                visible: false
                text: placeTab.label
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
            }

            Slant {
                id: placeTab
                readonly property string label: root.hasData && root.source.areaText !== "" ? root.source.areaText : "Weather"
                x: 2
                y: 102
                width: Math.min(placeProbe.implicitWidth + 50 + height * skew, root.innerW - 52)
                height: 30
                skew: 0.2
                radius: 10
                color: Theme.chipFill
                borderColor: Theme.line
                borderWidth: 3
            }

            // Text goes NEXT to the Slant (a child would lean with it).
            Row {
                x: placeTab.x + placeTab.lean / 2 + 12
                y: placeTab.y
                height: placeTab.height
                spacing: 4

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "location_on"
                    fill: 0
                    size: 16
                    weight: 700
                    color: Theme.dark ? Theme.accentMint : Theme.colBorder
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, placeTab.width - placeTab.lean - 40)
                    elide: Text.ElideRight
                    text: placeTab.label
                    color: Theme.chipInk
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                }
            }

            // The refresh key.
            Item {
                x: root.innerW - 38
                y: 102
                width: 38
                height: 32

                Pill {
                    anchors.fill: parent
                    shadowDy: 3
                    cornerRadius: 12
                    ringWidth: 4
                    fillColor: Theme.chipFill
                    pressed: refreshArea.pressed

                    MaterialIcon {
                        id: refreshIcon
                        anchors.centerIn: parent
                        name: "refresh"
                        fill: 0
                        size: 20
                        weight: 600
                        color: Theme.chipInk

                        RotationAnimator on rotation {
                            from: 0
                            to: 360
                            duration: 900
                            loops: Animation.Infinite
                            running: root.open && root.source !== null && root.source.loading
                            onRunningChanged: {
                                if (!running)
                                    refreshIcon.rotation = 0
                            }
                        }
                    }
                }

                MouseArea {
                    id: refreshArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.source)
                            root.source.refresh()
                    }
                }
            }
        }

        // ===== the gauges =====
        Row {
            id: gauges
            visible: root.hasData
            spacing: 8

            // -- humidity: a tank --
            Item {
                id: humTile
                width: 82
                height: 68
                readonly property real t: WM.clamp01((root.wave * root.waveMs - 0) / 300)
                readonly property real value: WM.firstNumber(root.hasData ? root.source.humidityText : "")

                Item {
                    anchors.fill: parent
                    scale: (0.55 + 0.45 * WM.outBack(humTile.t, 2.2)) * (humArea.containsMouse ? 1.05 : 1)
                    opacity: Math.min(1, humTile.t * 2.5)
                    rotation: humArea.containsMouse ? 0 : -1.6
                    transformOrigin: Item.Center
                    Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 2 } }

                    Pill {
                        anchors.fill: parent
                        shadowDy: 4
                        cornerRadius: 14
                        ringWidth: 3
                        fillColor: Theme.surfaceHover
                        pressed: humArea.pressed

                        Water {
                            level: humTile.value / 100 * WM.outBack(humTile.t, 1.4)
                            corner: 11
                        }
                        TileLabel { x: 9; y: 10; width: parent.width - 12; text: "HUMIDITY" }
                        Text {
                            x: 8
                            y: 26
                            width: parent.width - 14
                            elide: Text.ElideRight
                            text: root.hasData ? root.source.humidityText : ""
                            color: Theme.ink
                            font.family: Theme.fontFamily
                            font.pixelSize: 22
                            font.weight: Font.ExtraBold
                            font.styleName: Theme.fontStyleBold
                        }
                    }
                }
                MouseArea { id: humArea; anchors.fill: parent; hoverEnabled: true }
            }

            // -- wind: a dial --
            Item {
                id: windTile
                width: 132
                height: 68
                readonly property real t: WM.clamp01((root.wave * root.waveMs - 55) / 300)

                Item {
                    anchors.fill: parent
                    scale: (0.55 + 0.45 * WM.outBack(windTile.t, 2.2)) * (windArea.containsMouse ? 1.05 : 1)
                    opacity: Math.min(1, windTile.t * 2.5)
                    rotation: windArea.containsMouse ? 0 : 1.2
                    transformOrigin: Item.Center
                    Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 2 } }

                    Pill {
                        anchors.fill: parent
                        shadowDy: 4
                        cornerRadius: 14
                        ringWidth: 3
                        fillColor: Theme.surfaceHover
                        pressed: windArea.pressed

                        TileLabel {
                            x: 9
                            y: 10
                            width: parent.width - 16
                            text: "WIND" + (root.windP.dir !== "" ? "  ·  " + root.windP.dir : "")
                        }

                        Row {
                            x: 9
                            y: 26
                            spacing: 3
                            Text {
                                id: windBig
                                text: root.hasData ? String(root.windNum) : ""
                                color: Theme.ink
                                font.family: Theme.fontFamily
                                font.pixelSize: 22
                                font.weight: Font.ExtraBold
                                font.styleName: Theme.fontStyleBold
                            }
                            Text {
                                anchors.baseline: windBig.baseline
                                text: root.windUnit
                                color: Theme.inkSub
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.Bold
                            }
                        }

                        // The dial: a ring with the arrow turning inside it, and a
                        // diamond at north.
                        Item {
                            x: parent.width - width - 9
                            y: 19
                            width: 34
                            height: 34

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: Qt.rgba(Theme.colBorder.r, Theme.colBorder.g, Theme.colBorder.b, 0.35)
                                border.width: 2
                                border.color: Theme.line
                                antialiasing: true
                            }
                            DiamondDot {
                                x: (parent.width - width) / 2
                                y: -3
                                size: 6
                                lit: true
                                litColor: Theme.accentMint
                                lineColor: Theme.line
                            }
                            MaterialIcon {
                                anchors.centerIn: parent
                                name: root.windArrow !== null ? "arrow_upward" : "air"
                                fill: 0
                                size: 20
                                weight: 700
                                color: root.iconInk
                                rotation: root.windArrow !== null ? root.windArrow * WM.outBack(windTile.t, 2.4) : 0
                            }
                        }
                    }
                }
                MouseArea { id: windArea; anchors.fill: parent; hoverEnabled: true }
            }

            // -- UV: a meter --
            Item {
                id: uvTile
                width: 74
                height: 68
                readonly property real t: WM.clamp01((root.wave * root.waveMs - 110) / 300)

                Item {
                    anchors.fill: parent
                    scale: (0.55 + 0.45 * WM.outBack(uvTile.t, 2.2)) * (uvArea.containsMouse ? 1.05 : 1)
                    opacity: Math.min(1, uvTile.t * 2.5)
                    rotation: uvArea.containsMouse ? 0 : -1.2
                    transformOrigin: Item.Center
                    Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 2 } }

                    Pill {
                        anchors.fill: parent
                        shadowDy: 4
                        cornerRadius: 14
                        ringWidth: 3
                        fillColor: Theme.surfaceHover
                        pressed: uvArea.pressed

                        TileLabel { x: 9; y: 10; width: parent.width - 14; text: "UV INDEX" }
                        Text {
                            x: 9
                            y: 24
                            text: root.hasData ? root.source.uvText : ""
                            color: Theme.ink
                            font.family: Theme.fontFamily
                            font.pixelSize: 22
                            font.weight: Font.ExtraBold
                            font.styleName: Theme.fontStyleBold
                        }
                        Row {
                            x: 10
                            y: 49
                            spacing: 5
                            Repeater {
                                model: 5
                                delegate: DiamondDot {
                                    required property int index
                                    size: 7
                                    offColor: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.2)
                                    lit: index < WM.uvLit(root.uv)
                                    litColor: index < 2 ? Theme.accentMint : (index < 4 ? "#FFE066" : "#ff6f78")
                                }
                            }
                        }
                    }
                }
                MouseArea { id: uvArea; anchors.fill: parent; hoverEnabled: true }
            }
        }

        // ===== feels like / pressure / visibility: one slim strip =====
        Rectangle {
            id: strip
            visible: root.hasData
            width: root.innerW
            height: 42
            radius: 14
            color: Theme.surfaceHover
            border.width: 2
            border.color: Theme.line
            antialiasing: true
            opacity: Math.min(1, WM.clamp01((root.wave * root.waveMs - 160) / 250) * 2)

            Repeater {
                model: root.strip

                delegate: Item {
                    required property var modelData
                    required property int index
                    x: 2 + index * (strip.width - 4) / 3
                    width: (strip.width - 4) / 3
                    height: strip.height

                    MaterialIcon {
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        name: parent.modelData.icon
                        fill: 0
                        size: 18
                        weight: 600
                        color: root.iconInk
                    }
                    Column {
                        x: 36
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 38
                        spacing: 0
                        TileLabel { width: parent.width; text: parent.parent.modelData.label.toUpperCase() }
                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: parent.parent.modelData.value
                            color: Theme.ink
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.ExtraBold
                            font.styleName: Theme.fontStyleBold
                        }
                    }

                    // The slanted divider between two sections.
                    Slant {
                        visible: parent.index > 0
                        x: -2
                        y: 9
                        width: 6
                        height: strip.height - 18
                        skew: 0.4
                        radius: 1
                        color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.22)
                    }
                }
            }
        }

        // ===== the forecast: heading and switch =====
        Item {
            id: switchRow
            visible: root.hasData
            width: root.innerW
            height: 28

            SectionTab {
                y: 2
                text: "Forecast"
            }

            SegmentSwitch {
                id: viewSwitch
                visible: root.canSwitch
                x: root.innerW - width
                width: 136
                height: 28
                options: [ { id: "hourly", label: "Hourly" }, { id: "days", label: "Days" } ]
                current: root.hourlyView ? "hourly" : "days"
                onPicked: id => SettingsService.set("weather.view", id)
            }
        }

        // ===== the forecast: hourly, a melody =====
        Item {
            id: hourly
            visible: root.hourlyView
            width: root.innerW
            height: root.hourlyView ? 128 : 0

            readonly property var readings: root.hasData ? root.source.hourly : []
            readonly property int n: hourly.readings.length
            readonly property var pts: WM.curvePoints(hourly.readings.map(h => WM.firstNumber(h.temp)),
                                                      24, root.innerW - 48, 50, 72)

            // The lane the notes run along.
            Rectangle {
                anchors.fill: parent
                radius: 14
                color: Qt.rgba(Theme.colBorder.r, Theme.colBorder.g, Theme.colBorder.b, 0.28)
                border.width: 2
                border.color: Theme.line
                antialiasing: true
            }

            // The curve through the notes: a navy line under a light one, like a sticker's edge.
            Canvas {
                id: curve
                anchors.fill: parent
                opacity: Math.min(1, root.wave * 2)
                property color edge: Theme.line
                property color core: root.iconInk
                property var pts: hourly.pts
                onEdgeChanged: requestPaint()
                onCoreChanged: requestPaint()
                onPtsChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const p = curve.pts
                    if (!p || p.length < 2)
                        return
                    function trace() {
                        ctx.beginPath()
                        ctx.moveTo(p[0].x, p[0].y)
                        for (let i = 1; i < p.length; i++) {
                            const mx = (p[i - 1].x + p[i].x) / 2
                            ctx.bezierCurveTo(mx, p[i - 1].y, mx, p[i].y, p[i].x, p[i].y)
                        }
                    }
                    ctx.lineJoin = "round"
                    ctx.lineCap = "round"
                    trace()
                    ctx.lineWidth = 7
                    ctx.strokeStyle = curve.edge
                    ctx.stroke()
                    trace()
                    ctx.lineWidth = 3
                    ctx.strokeStyle = curve.core
                    ctx.stroke()
                }
            }

            Repeater {
                model: hourly.readings

                delegate: Item {
                    id: note
                    required property var modelData
                    required property int index

                    readonly property var pt: hourly.pts[note.index] || { x: 0, y: 60 }
                    readonly property bool hovered: noteArea.containsMouse
                    readonly property real t: WM.clamp01((root.wave * root.waveMs - note.index * 60) / 300)
                    readonly property real pop: WM.outBack(note.t, 2.2)
                    readonly property real colW: hourly.n > 1 ? Math.min(40, (root.innerW - 48) / (hourly.n - 1)) : 40

                    x: note.pt.x - note.colW / 2
                    width: note.colW
                    height: hourly.height

                    // The column under the pointer.
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 3
                        radius: 11
                        color: Theme.surfaceHover
                        opacity: note.hovered ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation { duration: 120 }
                        }
                    }

                    WeatherGlyph {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 4
                        name: note.modelData.iconName
                        size: 24
                        color: root.iconInk
                        scale: 0.4 + 0.6 * note.pop
                        opacity: Math.min(1, note.t * 2.5)
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: note.pt.y - 25
                        text: note.modelData.temp
                        color: Theme.ink
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.ExtraBold
                        font.styleName: Theme.fontStyleBold
                        opacity: Math.min(1, note.t * 2.5)
                    }

                    // The note itself: a diamond on the curve. The first is "now".
                    Item {
                        x: (parent.width - width) / 2
                        y: note.pt.y - 7
                        width: 14
                        height: 14
                        scale: (note.hovered ? 1.45 : (note.index === 0 ? 1.2 : 1)) * (0.3 + 0.7 * note.pop)
                        Behavior on scale {
                            NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 2.6 }
                        }

                        DiamondDot {
                            anchors.centerIn: parent
                            size: 12
                            lit: true
                            litColor: note.index === 0 ? Theme.accentMint : Theme.surface
                            lineColor: Theme.line
                        }
                    }

                    // Rain gauge: a small tank under the note, full at 100 %.
                    Rectangle {
                        x: (parent.width - width) / 2
                        y: 90
                        width: 32
                        height: 15
                        radius: 7.5
                        color: Theme.surfaceHover
                        border.width: 2
                        border.color: Theme.line
                        opacity: Math.min(1, note.t * 2.5)

                        Rectangle {
                            x: 2
                            y: 2
                            height: parent.height - 4
                            width: (parent.width - 4) * Math.min(1, note.modelData.rain / 100)
                            radius: 5.5
                            color: Qt.rgba(Theme.accentCyan.r, Theme.accentCyan.g, Theme.accentCyan.b, 0.55)
                        }

                        Text {
                            anchors.centerIn: parent
                            text: note.modelData.rain + "%"
                            color: Theme.ink
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.ExtraBold
                            font.styleName: Theme.fontStyleBold
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 110
                        text: note.modelData.label
                        color: Theme.inkSub
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: noteArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: root.hoverHour = note.index
                        onExited: {
                            if (root.hoverHour === note.index)
                                root.hoverHour = -1
                        }
                    }
                }
            }
        }

        // ===== the forecast: days, a song list =====
        Column {
            id: days
            visible: root.hasData && !root.hourlyView && root.source.forecast.length > 0
            width: root.innerW
            spacing: 6

            Repeater {
                model: root.hasData ? root.source.forecast : []

                delegate: Item {
                    id: dayRow
                    required property var modelData
                    required property int index
                    width: root.innerW
                    height: 40

                    readonly property bool hovered: rowArea.containsMouse
                    readonly property bool isToday: dayRow.index === 0
                    readonly property real t: WM.clamp01((root.wave * root.waveMs - dayRow.index * 90) / 320)
                    readonly property real lo: WM.firstNumber(dayRow.modelData.low)
                    readonly property real hi: WM.firstNumber(dayRow.modelData.high)

                    Item {
                        anchors.fill: parent
                        opacity: Math.min(1, dayRow.t * 2.5)
                        x: (1 - WM.outBack(dayRow.t, 1.6)) * 26
                        scale: dayRow.hovered ? 1.015 : 1
                        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 2 } }

                        Rectangle {
                            id: rowBg
                            anchors.fill: parent
                            radius: 14
                            color: Theme.surfaceHover
                            border.width: 2
                            border.color: dayRow.hovered ? Theme.accentMint : Theme.line
                            antialiasing: true
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            // The chance of rain, filling the row from the left.
                            Rectangle {
                                x: 2
                                y: 2
                                height: parent.height - 4
                                width: Math.max(0, (parent.width - 4) * Math.min(1, dayRow.modelData.rain / 100) * WM.outBack(dayRow.t, 1.4))
                                radius: 12
                                color: Qt.rgba(Theme.accentCyan.r, Theme.accentCyan.g, Theme.accentCyan.b, 0.2)
                            }
                        }

                        // The day, on a slanted tab (today's is the gradient one).
                        Slant {
                            x: 6
                            y: 7
                            width: 64
                            height: 26
                            skew: 0.2
                            radius: 8
                            color: dayRow.isToday ? "transparent" : Theme.chipFill
                            gradient: dayRow.isToday ? accentGradient : null
                            borderColor: Theme.line
                            borderWidth: 2
                        }
                        Text {
                            x: 6
                            y: 7
                            width: 64
                            height: 26
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: dayRow.modelData.label + (!dayRow.isToday && dayRow.modelData.date ? " " + dayRow.modelData.date : "")
                            color: dayRow.isToday ? Theme.colBorder : Theme.chipInk
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.ExtraBold
                            font.styleName: Theme.fontStyleBold
                        }

                        WeatherGlyph {
                            x: 78
                            anchors.verticalCenter: parent.verticalCenter
                            name: dayRow.modelData.iconName
                            size: 30
                            color: root.iconInk
                        }

                        Row {
                            x: 114
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 5
                            Text {
                                text: dayRow.modelData.high
                                color: Theme.ink
                                font.family: Theme.fontFamily
                                font.pixelSize: 16
                                font.weight: Font.ExtraBold
                                font.styleName: Theme.fontStyleBold
                            }
                            Text {
                                anchors.baseline: parent.children[0].baseline
                                text: dayRow.modelData.low
                                color: Theme.inkSub
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }
                        }

                        // High and low on the three days' shared scale.
                        Rectangle {
                            id: track
                            x: 176
                            anchors.verticalCenter: parent.verticalCenter
                            width: 64
                            height: 6
                            radius: 3
                            color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.16)

                            Rectangle {
                                x: (dayRow.lo - root.span.lo) / (root.span.hi - root.span.lo) * (track.width - width)
                                width: Math.max(14, (dayRow.hi - dayRow.lo) / (root.span.hi - root.span.lo) * track.width)
                                height: parent.height
                                radius: 3
                                gradient: accentGradient
                                // (a gradient runs top to bottom, so a thin bar reads as a solid pill)
                            }
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            MaterialIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "water_drop"
                                fill: 0
                                size: 14
                                weight: 700
                                color: Theme.ink
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: dayRow.modelData.rain + "%"
                                color: Theme.ink
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.ExtraBold
                                font.styleName: Theme.fontStyleBold
                            }
                        }
                    }

                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: root.hoverDay = dayRow.index
                        onExited: {
                            if (root.hoverDay === dayRow.index)
                                root.hoverDay = -1
                        }
                    }
                }
            }
        }

        // ===== the line at the foot =====
        Text {
            visible: root.hasData
            width: root.innerW
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: root.readoutText
            color: root.showingError && root.hoverHour < 0 && root.hoverDay < 0 ? "#ff6f78" : Theme.inkSub
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }
    }
}
