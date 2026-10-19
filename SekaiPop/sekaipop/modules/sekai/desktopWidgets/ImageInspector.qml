import QtQuick
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import "../../common/functions/ImageMath.js" as IM

// The panel that opens beside a Custom Image while it is selected in Edit Desktop
// (ImageWidget.qml places it and keeps it on screen). Everything in it is a change
// to that picture's entry in services/ImageService.qml, saved as you go:
//
//   header   make a copy, delete it (to change the picture, drop another one on the frame)
//   mode     FIT / FILL / CROP (see ImageWidget.qml)
//   ROUND    how round the corners are, 0 (square) to 100 (as round as the shape allows)
//   OPACITY  5 to 100%
//   PIN ON TOP   in front of windows and fullscreen games, clicks pass through (the same as
//                a right-click on the picture on the desktop; this is where you undo it)
//   BORDER   on / off, its width and colour
//   SHADOW   on / off, soft or hard, how far it reaches
//   LOCK RATIO / ORIGINAL RATIO   resizing keeps the aspect ratio; the button gives the
//                                 frame the picture's own ratio back
//
// It is drawn in design pixels like everything else (ImageWidget scales it by the
// monitor's scale), in the same housing as the user card.
Item {
    id: root

    property string imageId: ""
    property real uiScale: 1

    // The frame's ratio goes back to the picture's own (the widget knows where the
    // frame is and how much room there is).
    signal originalRatioRequested()

    // Keeps the classic (white) look in the first dark mode; see Theme.classicFor.
    readonly property bool classicPanel: true

    readonly property var rec: ImageService.byId[root.imageId] ?? null
    readonly property int inset: Theme.borderWidth + Theme.outerRingWidth + 12

    function set(patch) {
        ImageService.update(root.imageId, patch)
    }

    function swatch(id) {
        return id === "navy" ? Theme.colBorder
            : id === "mint" ? Theme.accentMint
            : id === "cyan" ? Theme.accentCyan
            : id === "pink" ? Theme.irisColorPink
            : id === "black" ? "#000000"
            : "#ffffff"
    }

    readonly property color trackColor: Qt.rgba(Theme.pInk.r, Theme.pInk.g, Theme.pInk.b, 0.14)

    width: 304
    height: body.implicitHeight + root.inset * 2 + Theme.shadowOffset

    // ===== parts =====
    component Cap: Text {
        color: Theme.pInkSub
        font.family: Theme.fontFamily
        font.pixelSize: 11
        font.weight: Font.ExtraBold
        font.styleName: Theme.fontStyleBold
        font.letterSpacing: 1
    }

    // A small keycap with an icon (and a label, when it has room).
    component KeyBtn: Item {
        id: kb

        property string icon: ""
        property string label: ""
        property bool danger: false
        signal clicked()

        implicitWidth: kb.label !== "" ? kbRow.width + 22 : 38
        implicitHeight: 33
        width: implicitWidth
        height: implicitHeight

        Pill {
            anchors.fill: parent
            cornerRadius: 10
            ringWidth: 3
            shadowDx: 2
            shadowDy: 3
            pressed: kbArea.pressed
            fillColor: kbArea.containsMouse ? (kb.danger ? "#ff7a8c" : Theme.accentMint) : Theme.chipFill

            Row {
                id: kbRow
                anchors.centerIn: parent
                spacing: 5

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: kb.icon
                    size: 17
                    weight: 700
                    color: kbArea.containsMouse ? Theme.colBorder : Theme.chipInk
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: kb.label !== ""
                    text: kb.label
                    color: kbArea.containsMouse ? Theme.colBorder : Theme.chipInk
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                    font.letterSpacing: 0.8
                }
            }
        }

        MouseArea {
            id: kbArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: kb.clicked()
        }
    }

    // label . track . value. `display` turns the stored number into the shown one.
    component Slide: Item {
        id: sl

        property string label: ""
        property real value: 0
        property real from: 0
        property real to: 1
        property real step: 0.01
        property real display: 100
        property string suffix: "%"
        signal moved(real v)

        readonly property real ratio: sl.to > sl.from ? Math.max(0, Math.min(1, (sl.value - sl.from) / (sl.to - sl.from))) : 0

        width: parent ? parent.width : 0
        height: 28

        Cap {
            anchors.verticalCenter: parent.verticalCenter
            width: 70
            text: sl.label
        }

        Item {
            id: track
            x: 72
            width: sl.width - 72 - 46
            height: sl.height

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: track.width
                height: 9
                radius: 4.5
                color: root.trackColor
                border.width: 2
                border.color: Theme.pLine
                antialiasing: true
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(9, sl.ratio * track.width)
                height: 9
                radius: 4.5
                color: Theme.accentMint
                border.width: 2
                border.color: Theme.pLine
                antialiasing: true
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: sl.ratio * (track.width - width)
                width: sliderArea.pressed ? 22 : 19
                height: width
                radius: width / 2
                color: "#ffffff"
                border.width: 3
                border.color: Theme.pLine
                antialiasing: true

                Behavior on width {
                    NumberAnimation { duration: 120; easing.type: Easing.OutBack; easing.overshoot: 2 }
                }
            }

            MouseArea {
                id: sliderArea
                anchors.fill: parent
                hoverEnabled: true
                preventStealing: true
                cursorShape: Qt.PointingHandCursor

                function at(mx) {
                    const r = Math.max(0, Math.min(1, mx / Math.max(1, track.width)))
                    const raw = sl.from + r * (sl.to - sl.from)
                    const snapped = Math.round((raw - sl.from) / sl.step) * sl.step + sl.from
                    sl.moved(Math.max(sl.from, Math.min(sl.to, Number(snapped.toFixed(6)))))
                }

                onPressed: mouse => at(mouse.x)
                onPositionChanged: mouse => {
                    if (pressed)
                        at(mouse.x)
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            x: sl.width - width
            text: Math.round(sl.value * sl.display) + sl.suffix
            color: Theme.pInk
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
        }
    }

    component ToggleRow: Item {
        id: sw

        property string label: ""
        property bool checked: false
        signal toggled()

        width: parent ? parent.width : 0
        height: 28

        Cap {
            anchors.verticalCenter: parent.verticalCenter
            text: sw.label
            color: Theme.pInk
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: sw.width - width
            width: 44
            height: 24
            radius: 12
            color: sw.checked ? Theme.accentMint : root.trackColor
            border.width: 3
            border.color: Theme.pLine
            antialiasing: true

            Behavior on color { ColorAnimation { duration: 140 } }

            Rectangle {
                y: 3
                x: sw.checked ? parent.width - width - 3 : 3
                width: 14
                height: 14
                radius: 7
                color: sw.checked ? Theme.colBorder : Theme.pInkSub
                antialiasing: true

                Behavior on x {
                    NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.8 }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: sw.toggled()
        }
    }

    component Rule: Rectangle {
        width: parent ? parent.width : 0
        height: 2
        radius: 1
        color: root.trackColor
    }

    // ===== the housing =====
    Pill {
        anchors.fill: parent
        cornerRadius: Theme.radiusOuter
        ringWidth: Theme.borderWidth + Theme.outerRingWidth
        ringColorTop: Theme.pSurfaceRing
        ringColorBottom: ringColorTop
        fillColor: Theme.pSurface
    }

    Column {
        id: body
        x: root.inset
        y: root.inset
        width: root.width - root.inset * 2
        spacing: 9

        // header
        Item {
            width: parent.width
            height: 34

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "image"
                    size: 18
                    weight: 700
                    color: Theme.pInk
                }

                Cap {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "IMAGE"
                    color: Theme.pInk
                    font.pixelSize: 12
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                KeyBtn {
                    icon: "content_copy"
                    onClicked: ImageService.duplicate(root.imageId)
                }

                KeyBtn {
                    icon: "delete"
                    danger: true
                    onClicked: ImageService.remove(root.imageId)
                }
            }
        }

        SegmentSwitch {
            width: parent.width
            height: 30
            options: [
                { id: "fit", label: "FIT" },
                { id: "fill", label: "FILL" },
                { id: "crop", label: "CROP" }
            ]
            current: root.rec ? root.rec.mode : "fit"
            onPicked: id => root.set({ mode: id })
        }

        Cap {
            width: parent.width
            visible: root.rec !== null && root.rec.mode === "crop"
            text: "DRAG TO PAN  -  SCROLL TO ZOOM"
            horizontalAlignment: Text.AlignHCenter
        }

        Slide {
            label: "ROUND"
            value: root.rec ? root.rec.roundness : 0
            onMoved: v => root.set({ roundness: v })
        }

        Slide {
            label: "OPACITY"
            from: 0.05
            to: 1
            value: root.rec ? root.rec.opacity : 1
            onMoved: v => root.set({ opacity: v })
        }

        Rule {}

        // pin
        ToggleRow {
            label: "PIN ON TOP"
            checked: root.rec !== null && root.rec.pinned
            onToggled: ImageService.setPinned(root.imageId, !(root.rec && root.rec.pinned))
        }

        Cap {
            width: parent.width
            text: "IN FRONT OF WINDOWS AND GAMES. CLICKS PASS THROUGH IT. SHOWN NORMALLY WHILE YOU EDIT"
            wrapMode: Text.WordWrap
            font.pixelSize: 9
            opacity: 0.8
        }

        Rule {}

        // border
        ToggleRow {
            label: "BORDER"
            checked: root.rec !== null && root.rec.borderOn
            onToggled: root.set({ borderOn: !(root.rec && root.rec.borderOn) })
        }

        Slide {
            visible: root.rec !== null && root.rec.borderOn
            label: "WIDTH"
            from: 1
            to: 24
            step: 1
            display: 1
            suffix: " px"
            value: root.rec ? root.rec.borderWidth : 4
            onMoved: v => root.set({ borderWidth: v })
        }

        Row {
            visible: root.rec !== null && root.rec.borderOn
            width: parent.width
            height: 28
            spacing: 10

            Cap {
                anchors.verticalCenter: parent.verticalCenter
                width: 62
                text: "COLOUR"
            }

            Repeater {
                model: ["navy", "white", "mint", "cyan", "pink", "black"]

                Item {
                    id: sw1

                    required property string modelData
                    readonly property bool on: root.rec !== null && root.rec.borderColor === sw1.modelData

                    anchors.verticalCenter: parent.verticalCenter
                    width: 26
                    height: 26

                    Rectangle {
                        anchors.fill: parent
                        radius: 13
                        color: root.swatch(sw1.modelData)
                        border.width: sw1.on ? 4 : 2
                        border.color: sw1.on ? Theme.accentCyan : Theme.pLine
                        antialiasing: true
                        scale: swArea.containsMouse || sw1.on ? 1.12 : 1

                        Behavior on scale {
                            NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 2 }
                        }
                    }

                    MouseArea {
                        id: swArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.set({ borderColor: sw1.modelData })
                    }
                }
            }
        }

        Rule {}

        // shadow
        ToggleRow {
            label: "SHADOW"
            checked: root.rec !== null && root.rec.shadowOn
            onToggled: root.set({ shadowOn: !(root.rec && root.rec.shadowOn) })
        }

        SegmentSwitch {
            visible: root.rec !== null && root.rec.shadowOn
            width: parent.width
            height: 28
            options: [
                { id: "soft", label: "SOFT" },
                { id: "hard", label: "HARD" }
            ]
            current: root.rec ? root.rec.shadowKind : "soft"
            onPicked: id => root.set({ shadowKind: id })
        }

        Slide {
            visible: root.rec !== null && root.rec.shadowOn
            label: "REACH"
            value: root.rec ? root.rec.shadowDepth : 0.5
            onMoved: v => root.set({ shadowDepth: v })
        }

        Rule {}

        // aspect ratio
        ToggleRow {
            label: "LOCK RATIO"
            checked: root.rec === null || root.rec.lockAspect
            onToggled: root.set({ lockAspect: !(root.rec === null || root.rec.lockAspect) })
        }

        Item {
            width: parent.width
            height: 33

            KeyBtn {
                anchors.left: parent.left
                icon: "aspect_ratio"
                label: "ORIGINAL RATIO"
                onClicked: root.originalRatioRequested()
            }
        }

        Cap {
            width: parent.width
            text: "SHIFT WHILE DRAGGING A CORNER FLIPS THE LOCK"
            wrapMode: Text.WordWrap
            font.pixelSize: 9
            opacity: 0.8
        }
    }
}
