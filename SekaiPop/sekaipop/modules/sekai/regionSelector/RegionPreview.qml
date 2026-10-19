import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// The preview card after a screenshot: what the region picker just took, in a
// small card that slides in at the bottom-right corner of the monitor it was
// taken on (state and actions: services/RegionService.qml).
//
//   click the picture   open it in swappy to annotate (like a right-drag does)
//   Annotate / Copy / Save   the same, from the buttons
//   X, or right click   put it away
//
// It goes away by itself after Settings -> "Preview stays" seconds, and waits
// while the pointer is on it. Starting another region pick takes it down first,
// so it never ends up in the frozen picture.
//
// One PanelWindow per screen, kept for the life of the shell, so the slide out
// can play (a Loader would destroy the window the moment the card is told to
// go). `revealed` is each window's own 0..1 amount; only the window on the
// screen the picture was taken on ever shows.
Variants {
    id: root

    // Design pixels (before the per-monitor scale).
    readonly property int cardW: 296
    readonly property int cardH: 248        // the card, with its hard shadow
    readonly property int gap: 18           // from the screen's edges
    readonly property int pad: 24           // room left of the card, so the slide's overshoot isn't clipped

    model: Quickshell.screens

    // A button of the card: the same keycap look as the picker's toolbar.
    component PreviewButton: Item {
        id: btn

        property string icon: ""
        property string label: ""
        property bool lit: false
        // Done: shown in mint and no longer clickable (a saved picture's Save).
        property bool done: false
        signal clicked

        width: 34 + (btn.label !== "" ? labelText.implicitWidth + 12 : 0)
        height: 34

        Pill {
            anchors.fill: parent
            anchors.bottomMargin: -Theme.shadowOffset
            cornerRadius: 12
            ringWidth: 4
            fillColor: (btn.lit || btn.done) ? Theme.accentMint
                       : (area.containsMouse ? Theme.surfaceHover : Theme.surface)
            pressed: area.pressed && !btn.done

            Row {
                anchors.centerIn: parent
                spacing: 6

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: btn.icon
                    size: 18
                    fill: (btn.lit || btn.done) ? 1 : 0
                    color: (btn.lit || btn.done) ? Theme.colBorder : Theme.ink
                }

                Text {
                    id: labelText
                    visible: btn.label !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    text: btn.label
                    color: (btn.lit || btn.done) ? Theme.colBorder : Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                }
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            enabled: !btn.done
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    PanelWindow {
        id: win

        required property var modelData
        screen: modelData

        readonly property bool wantsShow: RegionService.previewShown
            && win.modelData.name === RegionService.previewScreen

        // 0 hidden .. 1 shown (the slide overshoots a little, on purpose), and
        // the card's opacity, which has its own timing so the card doesn't sit
        // there at full strength while it is already leaving.
        property real revealed: 0
        property real fade: 0

        onWantsShowChanged: {
            showAnim.stop()
            hideAnim.stop()
            if (wantsShow)
                showAnim.restart()
            else if (RegionService.previewInstant) {
                win.revealed = 0
                win.fade = 0
            } else
                hideAnim.restart()
        }

        // Told to vanish with no animation (a new region pick is starting).
        Connections {
            target: RegionService
            function onPreviewInstantChanged() {
                if (!RegionService.previewInstant)
                    return
                showAnim.stop()
                hideAnim.stop()
                win.revealed = 0
                win.fade = 0
            }
        }

        // In: slides all the way in from the screen's edge and settles with a
        // small overshoot; it fades up quickly at the start.
        ParallelAnimation {
            id: showAnim
            NumberAnimation {
                target: win
                property: "revealed"
                to: 1
                duration: 360
                easing.type: Easing.OutBack
                easing.overshoot: 0.9
            }
            NumberAnimation {
                target: win
                property: "fade"
                to: 1
                duration: 160
                easing.type: Easing.OutQuad
            }
        }

        // Out: the same road backwards, all the way off the screen, moving from
        // the first frame (no ease-in pause) and reaching the edge just as it
        // has faded out, so nothing is cut off at the end.
        ParallelAnimation {
            id: hideAnim
            NumberAnimation {
                target: win
                property: "revealed"
                to: 0
                duration: 300
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                target: win
                property: "fade"
                to: 0
                duration: 300
                easing.type: Easing.InQuad
            }
        }

        visible: revealed > 0.001 || fade > 0.001
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "sekaipop-region-preview"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        readonly property real uiScale: ShellScale.forScreen(win.screen)
        readonly property string barPosition: BarPositionService.position
        // The bar's own edge is kept clear (the window sits beside it).
        readonly property real barOffset: Math.round(BarPositionService.thickness * win.uiScale)

        anchors {
            bottom: true
            right: true
        }
        margins {
            bottom: win.barPosition === "bottom" ? win.barOffset : 0
            right: win.barPosition === "right" ? win.barOffset : 0
        }

        implicitWidth: Math.ceil((root.pad + root.cardW + root.gap) * win.uiScale)
        implicitHeight: Math.ceil((root.cardH + root.gap) * win.uiScale)

        // Only the card takes clicks; the gap around it falls through.
        mask: Region {
            item: hit
        }

        Item {
            id: hit
            x: Math.round(root.pad * win.uiScale)
            y: 0
            width: Math.ceil(root.cardW * win.uiScale)
            height: Math.ceil(root.cardH * win.uiScale)
        }

        // Away by itself, but not while the pointer is on the card.
        Timer {
            interval: Math.max(2, Number(SettingsService.get("region.previewSeconds")) || 6) * 1000
            running: win.wantsShow && !hov.hovered
            onTriggered: RegionService.hidePreview(false)
        }

        ScaleHost {
            anchors.fill: parent
            factor: win.uiScale

            Item {
                id: card
                // Slides in from, and out past, the screen's right edge (the
                // window ends there, so the card is cut off by the screen itself).
                x: root.pad + (1 - win.revealed) * (root.cardW + root.gap)
                y: 0
                width: root.cardW
                height: root.cardH
                opacity: win.fade

                HoverHandler {
                    id: hov
                }

                Pill {
                    anchors.fill: parent
                    cornerRadius: 18
                    ringWidth: 6

                    // ===== the picture =====
                    Rectangle {
                        id: frame
                        x: 8
                        y: 8
                        width: parent.width - 16
                        height: 150
                        radius: 10
                        color: Theme.paper
                        border.width: 2
                        border.color: Theme.line
                        antialiasing: true

                        Image {
                            id: shot
                            anchors.fill: parent
                            anchors.margins: 5
                            source: RegionService.previewFile !== "" ? ("file://" + RegionService.previewFile) : ""
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: false
                            smooth: true
                            mipmap: true
                        }

                        // On hover: what a click does.
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Qt.rgba(0, 0, 0, 0.34)
                            opacity: pictureArea.containsMouse ? 1 : 0
                            Behavior on opacity {
                                NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
                            }

                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                MaterialIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: "draw"
                                    size: 20
                                    fill: 1
                                    color: Theme.textWhite
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Click to annotate"
                                    color: Theme.textWhite
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.weight: Font.ExtraBold
                                    font.styleName: Theme.fontStyleBold
                                }
                            }
                        }

                        MouseArea {
                            id: pictureArea
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: m => {
                                if (m.button === Qt.RightButton)
                                    RegionService.hidePreview(false)
                                else
                                    RegionService.previewAct("swappy")
                            }
                        }
                    }

                    // ===== what it is =====
                    Item {
                        x: 8
                        y: 166
                        width: parent.width - 16
                        height: 16

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - sizeLabel.implicitWidth - 8
                            elide: Text.ElideRight
                            text: RegionService.previewSaved ? "Saved and copied" : "Copied to the clipboard"
                            color: Theme.ink
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.ExtraBold
                            font.styleName: Theme.fontStyleBold
                        }

                        Text {
                            id: sizeLabel
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: shot.status === Image.Ready ? (shot.implicitWidth + " × " + shot.implicitHeight) : ""
                            color: Theme.inkSub
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }
                    }

                    // ===== the buttons =====
                    Item {
                        x: 8
                        y: 190
                        width: parent.width - 16
                        height: 34

                        Row {
                            spacing: 6

                            PreviewButton {
                                icon: "draw"
                                label: "Annotate"
                                lit: true
                                onClicked: RegionService.previewAct("swappy")
                            }

                            PreviewButton {
                                icon: "content_copy"
                                onClicked: RegionService.previewAct("copy")
                            }

                            PreviewButton {
                                icon: RegionService.previewSaved ? "check" : "save"
                                done: RegionService.previewSaved
                                onClicked: RegionService.previewAct("save")
                            }
                        }

                        PreviewButton {
                            anchors.right: parent.right
                            icon: "close"
                            onClicked: RegionService.hidePreview(false)
                        }
                    }
                }
            }
        }
    }
}
