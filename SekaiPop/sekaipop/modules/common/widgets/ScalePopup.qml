import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common

// The card that used to drop down from the bar's scale button (removed; the
// size is set in Settings Panel -> Bar -> Size now, and nothing opens this): make THIS monitor's
// shell bigger or smaller. − / + step it by 5%, the chips jump to a
// common size, and Reset drops this monitor's own setting (it then
// follows whatever scale.json's resolution / default entry says).
// Changes apply live and are written to scale.json (see
// services/ShellScale.qml), so they stick.
//
// Same shape as BatteryPopup.qml: a HyprlandFocusGrab dismisses it on a
// click anywhere else (the bar's own window excepted).
Scope {
    id: root

    property var parentWindow: null    // the bar's PanelWindow
    property Item anchorItem: null     // the button to center under
    property bool open: false

    // Which monitor this changes, and how to label it.
    property string screenName: ""
    property string screenLabel: ""

    // This monitor's scale, read off the bar's window. The popup window
    // is design size * this, and its card is drawn inside a ScaleHost so
    // it matches the bar (and grows / shrinks with every click).
    readonly property real uiScale: root.parentWindow && root.parentWindow.uiScale ? root.parentWindow.uiScale : 1

    readonly property real step: 0.05
    readonly property var presets: [0.8, 1.0, 1.25, 1.5]

    // Does this monitor have a setting of its own in scale.json?
    readonly property bool overridden: ShellScale.monitors[root.screenName] !== undefined

    function nudge(delta) {
        ShellScale.setScale(root.screenName, root.uiScale + delta)
    }

    signal closeRequested()

    // The bar re-lays-out when the scale changes (and when the window
    // title changes the Active Window pill's width), which moves the
    // button; `tick` makes the popup notice and follow it.
    property int tick: 0
    Timer {
        running: root.open
        interval: 250
        repeat: true
        onTriggered: root.tick++
    }

    readonly property real anchorCenterX: {
        void root.open
        void root.uiScale
        void root.tick
        return anchorItem ? anchorItem.mapToItem(null, anchorItem.width / 2, 0).x : 0
    }

    readonly property real anchorCenterY: {
        void root.open
        void root.uiScale
        void root.tick
        return anchorItem ? anchorItem.mapToItem(null, 0, anchorItem.height / 2).y : 0
    }

    readonly property bool grabWanted: open
    onGrabWantedChanged: {
        if (grabWanted)
            grabDelay.restart()
        else {
            grabDelay.stop()
            grab.active = false
        }
    }

    Timer {
        id: grabDelay
        interval: 80
        onTriggered: grab.active = root.grabWanted
    }

    HyprlandFocusGrab {
        id: grab
        windows: [popup, root.parentWindow]
        onCleared: root.closeRequested()
    }

    // A round-cornered − / + key, like the calendar's arrows.
    component StepKey: Item {
        id: key

        property string icon: ""
        property bool canPress: true

        signal clicked()

        implicitWidth: 46
        implicitHeight: 36
        opacity: key.canPress ? 1 : 0.4
        Behavior on opacity { NumberAnimation { duration: 120 } }

        Pill {
            anchors.fill: parent
            shadowDy: 3
            ringWidth: 5
            cornerRadius: 15
            fillColor: Theme.chipFill
            pressed: keyArea.pressed && key.canPress

            MaterialIcon {
                anchors.centerIn: parent
                name: key.icon
                size: 20
                color: Theme.chipInk
                weight: 600
            }
        }

        MouseArea {
            id: keyArea
            anchors.fill: parent
            enabled: key.canPress
            cursorShape: key.canPress ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: key.clicked()
        }
    }

    // A small text chip: a preset size, or Reset. `lit` = gradient.
    component Chip: Item {
        id: chip

        property string text: ""
        property bool lit: false

        signal clicked()

        implicitWidth: chipPill.implicitWidth
        implicitHeight: 33

        Pill {
            id: chipPill
            anchors.fill: parent
            shadowDy: 3
            ringWidth: 5
            cornerRadius: 15
            pressed: chipArea.pressed
            fillColor: Theme.surfaceHover
            fillGradient: chip.lit ? litGradient : null
            implicitWidth: chipLabel.implicitWidth + 30

            Gradient {
                id: litGradient
                GradientStop { position: 0.0; color: Theme.accentMint }
                GradientStop { position: 1.0; color: Theme.accentCyan }
            }

            Text {
                id: chipLabel
                anchors.centerIn: parent
                text: chip.text
                color: chip.lit ? Theme.colBorder : Theme.ink
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
            }
        }

        MouseArea {
            id: chipArea
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }

    PopupWindow {
        id: popup
        visible: root.open && root.parentWindow !== null

        anchor.window: root.parentWindow
        // Where the popup sits is decided by the bar (Bar.qml popupX /
        // popupY / popupGravity), so it follows the bar to any edge.
        anchor.rect.x: root.parentWindow ? root.parentWindow.popupX(root.anchorCenterX, root.anchorCenterY, implicitWidth, implicitHeight) : 0
        anchor.rect.y: root.parentWindow ? root.parentWindow.popupY(root.anchorCenterX, root.anchorCenterY, implicitWidth, implicitHeight) : 0
        anchor.gravity: root.parentWindow ? root.parentWindow.popupGravity : (Edges.Bottom | Edges.Right)

        implicitWidth: Math.ceil(card.width * root.uiScale)
        implicitHeight: Math.ceil((card.height + 6) * root.uiScale)
        color: "transparent"

        ScaleHost {
            anchors.fill: parent
            factor: root.uiScale

            Pill {
                id: card
                y: 6
                anchors.horizontalCenter: parent.horizontalCenter
                cornerRadius: Theme.radiusOuter
                ringWidth: Theme.borderWidth
                innerRing: Theme.cardRing
                fillColor: Theme.surface
                implicitWidth: Math.max(230, col.implicitWidth + 34)
                implicitHeight: col.implicitHeight + 24 + Theme.shadowOffset

                ColumnLayout {
                    id: col
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -Theme.shadowOffset / 2
                    spacing: 10

                    ColumnLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 0

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Shell scale"
                            color: Theme.ink
                            font.family: Theme.fontFamily
                            font.pixelSize: 16
                            font.weight: Font.ExtraBold
                            font.styleName: Theme.fontStyleBold
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.maximumWidth: 260
                            elide: Text.ElideRight
                            text: root.screenLabel
                            color: Theme.inkSub
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 6

                        StepKey {
                            icon: "remove"
                            canPress: root.uiScale > ShellScale.minScale + 0.001
                            onClicked: root.nudge(-root.step)
                        }

                        Text {
                            Layout.preferredWidth: 78
                            horizontalAlignment: Text.AlignHCenter
                            text: Math.round(root.uiScale * 100) + "%"
                            color: Theme.ink
                            font.family: Theme.fontFamily
                            font.pixelSize: 26
                            font.weight: Font.ExtraBold
                            font.styleName: Theme.fontStyleBold
                        }

                        StepKey {
                            icon: "add"
                            canPress: root.uiScale < ShellScale.maxScale - 0.001
                            onClicked: root.nudge(root.step)
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 6

                        Repeater {
                            model: root.presets

                            delegate: Chip {
                                required property real modelData

                                text: Math.round(modelData * 100) + "%"
                                lit: Math.abs(root.uiScale - modelData) < 0.005
                                onClicked: ShellScale.setScale(root.screenName, modelData)
                            }
                        }
                    }

                    // Only there when this monitor has a setting of its own
                    // to drop.
                    Chip {
                        Layout.alignment: Qt.AlignHCenter
                        visible: root.overridden
                        text: "Reset"
                        onClicked: ShellScale.resetScale(root.screenName)
                    }
                }
            }
        }
    }
}
