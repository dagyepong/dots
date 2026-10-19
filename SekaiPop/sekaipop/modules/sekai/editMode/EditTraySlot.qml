import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// One widget on Edit Desktop's shelf (EditTray.qml): a little framed "screen"
// showing the widget exactly as it looks (the picture its own window takes of
// its card, see EditPreview.qml), a name tag on the bottom edge and a round
// badge on the corner.
//
//   left click    not on the desktop yet  -> add it (a burst of diamonds, the
//                                            card pops in, its outline flares)
//                 already on the desktop  -> edit it (select it; click again to
//                                            let go) and flare it on the card
//   right click   already on the desktop  -> remove it
//
// The badge says which it is: a mint "+" (add me), a mint check (on the
// desktop), a cyan pencil (being edited). The picture is dimmed while the
// widget is on the desktop, so the shelf reads as "what is still in the box".
//
// A tall card (a long To-Do list) is cut off at the bottom of the screen
// instead of being shrunk to nothing.
Item {
    id: root

    property string widgetId: ""
    property string title: ""
    property string icon: ""
    // Position on the shelf: odd and even slots lean opposite ways.
    property int slotIndex: 0

    // ===== what the shelf knows =====
    readonly property bool placed: EditMode.widgetOn(root.widgetId)
    readonly property bool editing: root.placed && EditMode.editTarget === root.widgetId
    readonly property string previewUrl: EditMode.previewUrls[root.widgetId] ?? ""
    readonly property var previewSize: EditMode.previewSizes[root.widgetId] ?? ({ w: 0, h: 0 })

    // ===== the picture's size =====
    readonly property real boxW: 176
    readonly property real boxH: 100
    readonly property real pw: root.previewSize.w
    readonly property real ph: root.previewSize.h
    readonly property bool hasPreview: root.previewUrl !== "" && root.pw > 1 && root.ph > 1
    readonly property real fit: root.hasPreview
        ? Math.max(0.3, Math.min(root.boxW / root.pw, root.boxH / root.ph, 0.62)) : 1
    readonly property real shownW: root.hasPreview ? Math.min(root.pw * root.fit, root.boxW) : 84
    readonly property real shownH: root.hasPreview ? Math.min(root.ph * root.fit, root.boxH) : 84

    readonly property real mountH: 130          // the framed screen, hard shadow included

    width: Math.max(124, Math.round(root.shownW) + 28)
    height: root.mountH + 14

    Behavior on width {
        NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
    }

    // ===== motion =====
    property real lift: area.containsMouse ? 1 : 0

    Behavior on lift {
        NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 2.4 }
    }

    // A squash-and-spring for clicks.
    property real hop: 1

    SequentialAnimation {
        id: hopAnim
        NumberAnimation { target: root; property: "hop"; to: 0.9; duration: 80; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "hop"; to: 1; duration: 380; easing.type: Easing.OutBack; easing.overshoot: 3.2 }
    }

    // Eight diamonds fly out of the slot when a widget is added.
    property real burstT: 0

    NumberAnimation {
        id: burstAnim
        target: root
        property: "burstT"
        from: 0
        to: 1
        duration: 580
        easing.type: Easing.OutCubic
    }

    // The card's outline flares once the widget has popped in.
    Timer {
        id: pingLater
        interval: 300
        onTriggered: EditMode.ping(root.widgetId)
    }

    // ===== the slot itself =====
    Item {
        id: holder
        width: root.width
        height: root.height
        y: -7 * root.lift
        rotation: (root.slotIndex % 2 === 0 ? -2.2 : 2.2) * (1 - Math.min(1, root.lift))
        scale: root.hop * (area.pressed ? 0.97 : 1 + 0.035 * root.lift)
        transformOrigin: Item.Center

        // The frame: outline, ring (mint while it is being edited), hard shadow.
        Pill {
            id: mount
            width: holder.width
            height: root.mountH
            cornerRadius: 16
            ringWidth: 4
            shadowDx: 0
            shadowDy: 4
            pressed: area.pressed
            fillColor: Theme.pSurface
            ringColorTop: root.editing ? Theme.accentMint : Theme.pSurfaceRing
            ringColorBottom: ringColorTop

            // The little screen the widget is shown on: the same deep navy the
            // stage behind the card is.
            Rectangle {
                id: screen
                anchors.fill: parent
                anchors.margins: 5
                radius: 10
                antialiasing: true
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.darker(Theme.colBorder, 2.1) }
                    GradientStop { position: 1.0; color: Qt.darker(Theme.colBorder, 2.9) }
                }

                // The widget's own picture, cut off at the box if it is taller.
                Item {
                    id: frame
                    width: root.shownW
                    height: root.shownH
                    x: (screen.width - width) / 2
                    y: Math.max(4, (screen.height - 14 - height) / 2 + 2)
                    clip: true
                    visible: root.hasPreview
                    opacity: root.hasPreview ? (root.placed && !root.editing ? 0.5 : 1) : 0

                    Behavior on opacity {
                        NumberAnimation { duration: 220 }
                    }

                    Image {
                        source: root.previewUrl
                        width: root.pw * root.fit
                        height: root.ph * root.fit
                        smooth: true
                        mipmap: true
                        cache: false
                        asynchronous: false
                        fillMode: Image.Stretch
                    }
                }

                // Until the first picture arrives (or if one never does): the
                // widget's icon.
                MaterialIcon {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -6
                    visible: !root.hasPreview
                    name: root.icon
                    size: 44
                    weight: 600
                    color: Theme.accentMint
                    opacity: 0.8
                }
            }
        }

        // The name tag on the bottom edge. While the pointer is over the slot it
        // says what a click will do.
        Pill {
            id: tag
            readonly property string verb: root.editing ? "STOP EDITING" : (root.placed ? "EDIT" : "ADD")

            width: tagText.implicitWidth + 28
            height: 26
            x: (holder.width - width) / 2
            y: root.mountH - 9
            cornerRadius: 9
            ringWidth: 3
            fillColor: root.lift > 0.5 ? Theme.accentMint : Theme.chipFill
            rotation: root.slotIndex % 2 === 0 ? 2 : -2
            transformOrigin: Item.Center

            Behavior on width {
                NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.8 }
            }

            Text {
                id: tagText
                anchors.centerIn: parent
                text: root.lift > 0.5 ? tag.verb : root.title.toUpperCase()
                color: root.lift > 0.5 ? Theme.colBorder : Theme.chipInk
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
                font.letterSpacing: 0.8
            }
        }

        // The corner badge.
        Item {
            id: badge
            width: 30
            height: 32
            x: holder.width - 24
            y: -11
            transformOrigin: Item.Center
            scale: root.placed ? 1 : 0.9 + 0.2 * Math.min(1, root.lift)

            Behavior on scale {
                NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 3 }
            }

            Rectangle {
                x: 2
                y: 4
                width: 28
                height: 28
                radius: 14
                color: Theme.pLineShadow
                antialiasing: true
            }

            Rectangle {
                width: 28
                height: 28
                radius: 14
                color: root.editing ? Theme.accentCyan : Theme.accentMint
                border.width: Theme.borderWidth
                border.color: Theme.pLine
                antialiasing: true

                MaterialIcon {
                    anchors.centerIn: parent
                    name: root.editing ? "edit" : (root.placed ? "check" : "add")
                    size: 18
                    weight: 700
                    color: Theme.colBorder
                }
            }
        }
    }

    // ===== the burst =====
    Repeater {
        model: 8

        Rectangle {
            required property int index

            readonly property real ang: index * Math.PI / 4 + 0.3

            z: 30
            width: 11
            height: 11
            radius: 3
            rotation: 45
            visible: root.burstT > 0.001 && root.burstT < 0.999
            opacity: 1 - root.burstT
            scale: 1.25 - 0.6 * root.burstT
            color: index % 2 === 0 ? Theme.accentMint : Theme.accentCyan
            border.width: 2
            border.color: Theme.colBorder
            antialiasing: true
            x: root.width / 2 + Math.cos(ang) * 64 * root.burstT - width / 2
            y: root.mountH / 2 + Math.sin(ang) * 50 * root.burstT - height / 2
        }
    }

    // ===== clicks =====
    MouseArea {
        id: area
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                if (root.placed) {
                    hopAnim.restart()
                    EditMode.removeWidget(root.widgetId)
                }
                return
            }

            if (root.placed) {
                // Edit it (or, if it already is being edited, let go of it).
                if (root.editing) {
                    EditMode.select("")
                } else {
                    EditMode.select(root.widgetId)
                    EditMode.ping(root.widgetId)
                }
                hopAnim.restart()
            } else {
                hopAnim.restart()
                burstAnim.restart()
                EditMode.addWidget(root.widgetId)
                pingLater.restart()
            }
        }
    }
}
