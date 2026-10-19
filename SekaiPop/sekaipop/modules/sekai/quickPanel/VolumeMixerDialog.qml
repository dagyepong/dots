import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sekai.phone

// What used to be a big flat device list (AudioDeviceDialog.qml) is now
// two things sharing one card, dropped over the phone's screen by
// right-clicking the Microphone or Speaker slider:
//
//  - a compact "Output: <name> ▾" row at the top that expands into a
//    short dropdown of the other sinks/sources right below it — the
//    device picker, just no longer taking up the whole card
//  - the rest of the card, which now belongs to a per-app volume
//    mixer: one slider per playing/recording app (Spotify, a browser
//    tab, a game), reading and writing that app's own stream volume
//
// One shared component for both sliders, same reasoning as before:
// a sink list and a source list want the exact same dialog around
// them, just fed different data — `kind`/`title`/`deviceCaption` pick
// which, all set by QuickPanelFace based on which slider was
// right-clicked.
Item {
    id: root

    property bool open: false
    property string kind: "speaker"        // "speaker" or "microphone"
    property string title: "Speaker"
    property string deviceCaption: "Output" // "Output" or "Input"
    property var devices: []               // [{id, name, active}]
    property var streams: []               // [{id, name, volume, muted, corked}]
    property bool scanning: false
    // See NetworkDialog.qml's manualScanning: this dialog already had
    // a live background poll (audioMixerRefresh, every 2s) before the
    // other two dialogs gained theirs, and it had the exact same
    // symptom — the button was bound straight to `scanning`, so it
    // flashed "Refreshing…" on its own every 2 seconds. Button visuals
    // now read this instead; `scanning` still covers the initial
    // fetch on open (see the empty-state Text below).
    property bool manualScanning: false
    property string selectingDeviceId: ""  // which device row is mid-switch
    property string errorText: ""

    signal closeRequested()
    signal scanRequested()
    signal deviceSelected(string id)
    signal streamVolumeChanged(string id, real value)
    signal streamMuteToggled(string id, bool muted)
    // Fired around the drag itself (press → release/cancel), separate
    // from streamVolumeChanged's continuous stream of values while
    // moving. QuickSource uses this pair to hold off touching the
    // streams array mid-drag — see setStreamVolume's comment there for
    // why that reassignment is what breaks holding-and-sliding.
    signal streamDragStarted(string id)
    signal streamDragEnded(string id)

    anchors.fill: parent
    visible: opacity > 0
    opacity: root.open ? 1 : 0
    Behavior on opacity {
        NumberAnimation {
            duration: root.open ? 140 : 220
        }
    }

    readonly property var activeDevice: {
        for (const d of devices) {
            if (d.active)
                return d
        }
        return null
    }
    readonly property var otherDevices: devices.filter(d => !d.active)

    property bool deviceListExpanded: false
    onOpenChanged: if (!open) deviceListExpanded = false
    // If the active device disappears from under it (unplugged) or the
    // whole list goes empty, don't leave the dropdown looking stuck open
    // on nothing.
    onDevicesChanged: if (otherDevices.length === 0) deviceListExpanded = false

    Rectangle {
        anchors.fill: parent
        anchors.margins: Theme.phoneScreenInset
        radius: Theme.phoneCornerRadius - Theme.phoneScreenInset
        color: Theme.scrim
        opacity: root.open ? 0.55 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 220
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeRequested()
        }
        antialiasing: true
    }

    Rectangle {
        x: 40 + (Theme.quickFlat ? 0 : 5)
        y: 200 + 4
        width: 575
        height: 940
        radius: 41
        color: Theme.pLineShadow
        antialiasing: true
    }

    Rectangle {
        id: card
        x: 40
        y: 200
        width: 575
        height: 940
        radius: 41
        color: Theme.pSurface
        border.width: 3
        border.color: Theme.pLine
        clip: true

        MouseArea { anchors.fill: parent }

        Text {
            x: 28
            y: 26
            text: root.title
            color: Theme.pInk
            font.family: Theme.fontFamily
            font.pixelSize: 26
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
        }

        Rectangle {
            id: scanButton
            x: card.width - 28 - width
            y: 22
            width: scanLabel.implicitWidth + 28
            height: 34
            radius: 17
            color: scanArea.containsMouse ? Theme.pSurfaceHover : "transparent"
            border.width: 2
            border.color: Theme.pLine
            opacity: root.manualScanning ? 0.5 : 1

            Text {
                id: scanLabel
                anchors.centerIn: parent
                text: root.manualScanning ? "Refreshing…" : "Refresh"
                color: Theme.pInk
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

            MouseArea {
                id: scanArea
                anchors.fill: parent
                enabled: !root.manualScanning
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.scanRequested()
            }
            antialiasing: true
        }

        Text {
            id: errorLabel
            visible: root.errorText !== ""
            x: 28
            y: 62
            width: card.width - 56
            text: root.errorText
            wrapMode: Text.Wrap
            color: "#c0392b"
            font.family: Theme.fontFamily
            font.pixelSize: 14
        }

        // ===== device dropdown =====
        Item {
            id: deviceSection
            x: 14
            y: errorLabel.visible ? 92 : 66
            width: card.width - 28
            height: 62 + (root.deviceListExpanded ? dropdownList.contentHeight + 8 : 0)
            clip: true
            Behavior on height {
                NumberAnimation {
                    duration: 140
                }
            }

            Rectangle {
                width: parent.width
                height: 58
                radius: 20
                color: Theme.pSurfaceHover

                Text {
                    x: 18
                    y: 8
                    width: parent.width - 18 - 52
                    elide: Text.ElideRight
                    text: root.deviceCaption
                    color: Theme.pInkSub
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                Text {
                    x: 18
                    y: 26
                    width: parent.width - 18 - 40
                    elide: Text.ElideRight
                    text: root.activeDevice ? root.activeDevice.name : "No device"
                    color: Theme.pInk
                    font.family: Theme.fontFamily
                    font.pixelSize: 17
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                }

                MaterialIcon {
                    anchors.right: parent.right
                    anchors.rightMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.otherDevices.length > 0
                    size: 24
                    name: root.deviceListExpanded ? "keyboard_arrow_up" : "keyboard_arrow_down"
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.otherDevices.length > 0
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.deviceListExpanded = !root.deviceListExpanded
                }
                antialiasing: true
            }

            WheelScroll { scroller: dropdownList }
            ListView {
                id: dropdownList
                x: 0
                y: 62
                width: parent.width
                height: parent.height - 62
                clip: true
                interactive: false
                spacing: 2
                model: root.otherDevices

                delegate: Item {
                    id: deviceRow
                    required property var modelData
                    readonly property bool busy: root.selectingDeviceId === modelData.id
                    width: dropdownList.width
                    height: 46

                    Rectangle {
                        width: parent.width
                        height: 42
                        radius: 16
                        color: deviceRowArea.containsMouse ? Theme.pSurfaceHover : "transparent"
                        antialiasing: true
                    }

                    Text {
                        x: 18
                        width: parent.width - 18 - 90
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: deviceRow.modelData.name
                        color: Theme.pInk
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                    }

                    Text {
                        visible: deviceRow.busy
                        anchors.right: parent.right
                        anchors.rightMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Switching…"
                        color: Theme.pInkSub
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: deviceRowArea
                        width: parent.width
                        height: 42
                        hoverEnabled: true
                        enabled: !deviceRow.busy
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.deviceListExpanded = false
                            root.deviceSelected(deviceRow.modelData.id)
                        }
                    }
                }
            }
        }

        // ===== per-app mixer =====
        Text {
            id: mixerLabel
            x: 28
            y: deviceSection.y + deviceSection.height + 14
            text: "App volumes"
            color: Theme.pInkSub
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }

        WheelScroll { scroller: mixerList }
        ListView {
            id: mixerList
            x: 14
            y: mixerLabel.y + 26
            width: card.width - 28
            height: card.height - y - 14
            clip: true
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            model: root.streams
            // A flick/scroll here changes contentY directly, the same
            // way a slider drag changes width directly -- no Behavior
            // to hang a touch() off, so it needs its own.
            onContentYChanged: PanelActivity.touch()

            delegate: Item {
                id: streamRow

                required property var modelData

                property bool dragging: false
                property real dragValue: 0
                readonly property real shownValue: dragging ? dragValue : streamRow.modelData.volume

                width: mixerList.width
                height: 70

                Text {
                    x: 20
                    y: 6
                    width: parent.width - 40 - 36
                    elide: Text.ElideRight
                    text: streamRow.modelData.name + (streamRow.modelData.corked ? "  ·  paused" : "")
                    color: Theme.pInk
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                }

                Rectangle {
                    id: track
                    x: 20
                    y: 34
                    width: parent.width - 20 - 20 - 44
                    height: 14
                    radius: 7
                    color: Theme.pSurfaceDivider

                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, streamRow.shownValue / 100))
                        height: parent.height
                        radius: 7
                        color: streamRow.modelData.muted ? Theme.pInkSub : Theme.pInk
                        opacity: streamRow.modelData.muted ? 0.5 : 1
                        Behavior on width {
                            enabled: !streamRow.dragging
                            NumberAnimation {
                                duration: 120
                            }
                        }
                        antialiasing: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        // Track sits inside mixerList (a ListView, i.e. a
                        // Flickable) — without this, dragging past a few
                        // pixels gets read as "the user wants to scroll
                        // the list" and the Flickable steals the mouse
                        // grab mid-drag: the initial press still sets a
                        // value (that's onPressed firing once), but every
                        // onPositionChanged after that goes to the list
                        // instead of here, so it feels like the slider
                        // only supports clicking, never holding and
                        // sliding.
                        preventStealing: true

                        function setFromX(mx) {
                            const p = Math.max(0, Math.min(1, mx / track.width))
                            streamRow.dragValue = p * 100
                            root.streamVolumeChanged(streamRow.modelData.id, streamRow.dragValue)
                            // No Behavior runs while dragging (see
                            // above) -- keep the phone off full quality
                            // for the whole drag the same way the main
                            // sliders do, see VolumeSlider.qml.
                            PanelActivity.touch()
                        }

                        onPressed: mouse => {
                            streamRow.dragging = true
                            root.streamDragStarted(streamRow.modelData.id)
                            setFromX(mouse.x)
                        }
                        onPositionChanged: mouse => {
                            if (pressed)
                                setFromX(mouse.x)
                        }
                        onReleased: {
                            streamRow.dragging = false
                            root.streamDragEnded(streamRow.modelData.id)
                        }
                        onCanceled: {
                            streamRow.dragging = false
                            root.streamDragEnded(streamRow.modelData.id)
                        }
                    }
                    antialiasing: true
                }

                Rectangle {
                    id: muteButton
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: track.verticalCenter
                    width: 36
                    height: 36
                    radius: 18
                    color: muteArea.containsMouse ? Theme.pSurfaceHover : "transparent"

                    MaterialIcon {
                        anchors.centerIn: parent
                        size: 20
                        name: streamRow.modelData.muted
                            ? (root.kind === "microphone" ? "mic_off" : "volume_off")
                            : (root.kind === "microphone" ? "mic" : "volume_up")
                    }

                    MouseArea {
                        id: muteArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.streamMuteToggled(streamRow.modelData.id, !streamRow.modelData.muted)
                    }
                    antialiasing: true
                }
            }

            SekaiScrollBar {}
        }

        Text {
            visible: root.streams.length === 0 && !root.scanning
            anchors.centerIn: mixerList
            text: root.kind === "microphone" ? "Nothing's recording right now" : "Nothing's playing right now"
            color: Theme.pInkSub
            font.family: Theme.fontFamily
            font.pixelSize: 16
        }
        antialiasing: true
    }
}
