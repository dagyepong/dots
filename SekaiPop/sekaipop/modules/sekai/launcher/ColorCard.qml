import QtQuick
import "../../common/functions/Extras.js" as X
import qs.modules.common
import qs.modules.common.widgets

// The colour card: type a colour after "color " (or just type one in the
// launcher -- #ff8800, rgb(255, 136, 0), hsl(32 100% 50%), a name like
// "coral") and it shows the actual colour, big, with HEX / RGB / HSL to
// copy, a strip of lighter and darker shades to try, and an eyedropper for
// picking a colour off the screen.
//
// Pure UI: it parses `arg` with Extras.js and reports what to copy / which
// shade was tapped / that the eyedropper was pressed.
ExtraFrame {
    id: root

    property string arg: ""

    // Nothing typed yet: show a friendly starter colour so the card is never
    // an empty box, but say it isn't a real answer.
    readonly property var parsed: X.parseColor(root.arg, true)
    readonly property bool valid: parsed !== null
    readonly property var c: valid ? parsed : { r: 0, g: 254, b: 238, a: 1 }
    readonly property string hex: X.toHex(c)
    readonly property string ink: X.inkFor(c.a < 0.5 ? { r: 255, g: 255, b: 255, a: 1 } : c)

    signal copyRequested(string text)     // a format row was clicked
    signal activated(string hex)          // Enter: copy the hex and close
    signal shadePicked(string hex)
    signal pickRequested()

    width: 540
    height: 356

    // Enter copies the hex and closes.
    function activate() {
        if (valid)
            activated(hex)
    }

    // ===== the swatch =====
    Rectangle {
        id: swatchFrame
        x: 16
        y: 18
        width: parent.width - 32
        height: 128
        radius: 20
        color: "#ffffff"
        border.width: 3
        border.color: Theme.line
        clip: true

        // checkerboard, so a translucent colour reads as translucent
        Canvas {
            anchors.fill: parent
            anchors.margins: 3
            // only needed behind a translucent (or not-yet-typed) colour; drawn
            // for an opaque one it pokes out of the rounded corners
            visible: !root.valid || root.c.a < 1
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const s = 12
                for (let y = 0; y * s < height; y++) {
                    for (let x = 0; x * s < width; x++) {
                        ctx.fillStyle = (x + y) % 2 === 0 ? "#ffffff" : "#e4e4ec"
                        ctx.fillRect(x * s, y * s, s, s)
                    }
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 3
            radius: 17
            color: root.valid ? Qt.rgba(root.c.r / 255, root.c.g / 255, root.c.b / 255, root.c.a) : "transparent"
            Behavior on color { ColorAnimation { duration: 140 } }

            Text {
                anchors.centerIn: parent
                width: parent.width - 32
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: root.valid ? root.hex.toUpperCase()
                    : "Type a colour \u2014 #ff8800, rgb(255, 136, 0), hsl(32 100% 50%) or a name like coral"
                color: root.valid ? root.ink : ScrapbookTheme.inkSoft
                font.family: Theme.fontFamily
                font.pixelSize: root.valid ? 30 : 14
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
            }
        }
    }

    // ===== shades =====
    Row {
        id: shades
        x: 16
        y: swatchFrame.y + swatchFrame.height + 12
        spacing: 6
        opacity: root.valid ? 1 : 0.35

        Repeater {
            model: [92, 82, 72, 62, 52, 42, 32, 22, 12]
            delegate: Rectangle {
                required property int modelData
                readonly property var col: X.withLightness(root.c, modelData)
                width: (swatchFrame.width - 8 * 6) / 9
                height: 30
                radius: 9
                color: Qt.rgba(col.r / 255, col.g / 255, col.b / 255, 1)
                border.width: shadeArea.containsMouse ? 3 : 2
                border.color: Theme.line

                MouseArea {
                    id: shadeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: root.valid
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.shadePicked(X.toHex(parent.col))
                }
            }
        }
    }

    // ===== formats to copy =====
    Column {
        id: formats
        x: 16
        y: shades.y + shades.height + 14
        width: parent.width - 32
        spacing: 8
        opacity: root.valid ? 1 : 0.35

        Repeater {
            model: [
                { label: "HEX", text: root.hex },
                { label: "RGB", text: X.toRgb(root.c) },
                { label: "HSL", text: X.toHslString(root.c) }
            ]
            delegate: Item {
                id: fmt
                required property var modelData
                property bool flashed: false

                width: formats.width
                height: 38

                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: fmt.flashed ? Qt.rgba(0, 1, 0.8, 0.35) : (fmtArea.containsMouse ? "#ece6d4" : "#f5f1e6")
                    Behavior on color { ColorAnimation { duration: 100 } }
                }

                Rectangle {
                    id: tag
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 46
                    height: 24
                    radius: 12
                    color: Theme.colBorder

                    Text {
                        anchors.centerIn: parent
                        text: fmt.modelData.label
                        color: "#ffffff"
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.ExtraBold
                        font.styleName: Theme.fontStyleBold
                    }
                }

                Text {
                    anchors.left: tag.right
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.rightMargin: 44
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: fmt.modelData.text
                    color: Theme.colBorder
                    font.family: "monospace"
                    font.pixelSize: 14
                }

                MaterialIcon {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    name: fmt.flashed ? "check" : "content_copy"
                    size: 18
                    weight: 600
                    color: fmt.flashed ? Qt.darker(Theme.accentMint, 1.6) : ScrapbookTheme.inkSoft
                }

                Timer {
                    id: unflash
                    interval: 900
                    onTriggered: fmt.flashed = false
                }

                MouseArea {
                    id: fmtArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: root.valid
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        fmt.flashed = true
                        unflash.restart()
                        root.copyRequested(fmt.modelData.text)
                    }
                }
            }
        }
    }

    // ===== eyedropper =====
    ExtraKey {
        id: dropper
        x: swatchFrame.x + swatchFrame.width - width - 12
        y: swatchFrame.y + 12
        width: 46
        height: 38
        icon: "colorize"
        iconSize: 22
        fill: Theme.accentMint
        onClicked: root.pickRequested()
    }

    Rectangle {
        visible: dropper.hovered
        anchors.right: dropper.left
        anchors.rightMargin: 8
        anchors.verticalCenter: dropper.verticalCenter
        width: tipText.implicitWidth + 20
        height: 26
        radius: 13
        color: Theme.colBorder

        Text {
            id: tipText
            anchors.centerIn: parent
            text: "Pick from screen"
            color: "#ffffff"
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }
    }
}
