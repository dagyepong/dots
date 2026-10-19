import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Tells you what happened when the shell reloaded — Quickshell reloads on
// its own whenever a file in this folder is saved, and the Quick Panel's
// Refresh button does a hard reload — instead of leaving you guessing
// whether the last edit took.
//
//   Reloaded   a small "Shell reloaded" chip that fades out on its own.
//              (It's shown by the NEW copy of the shell, once it's up —
//              the old one is gone by then.)
//   Failed     a card with the error Quickshell reported (QML syntax
//              errors, a missing import, a bad property...). The previous
//              copy of the shell keeps running while a reload fails, which
//              is why this can still show. It stays until you dismiss it
//              (X / Dismiss) or a later reload succeeds; "Copy error" puts
//              the text on the clipboard (needs wl-copy from wl-clipboard).
//
// It replaces Quickshell's own reload popup (Quickshell.inhibitReloadPopup(),
// called on builds that have it) so you don't get two. Shown on whichever
// monitor was focused when the reload finished — same one-persistent-
// window-per-screen setup as OSDPopup.qml, so the fade-out actually plays.
Scope {
    id: root

    property bool open: false
    property bool failed: false
    property string errorText: ""
    property string targetMonitorName: ""
    property int okHideDelay: 2200
    property bool copied: false

    readonly property int gap: 14

    function focusedMonitorName() {
        return Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    }

    function showOk() {
        root.failed = false
        root.errorText = ""
        root.copied = false
        root.targetMonitorName = root.focusedMonitorName()
        root.open = true
        hideTimer.restart()
    }

    function showError(message) {
        // Quickshell colours its error text for terminals; strip that.
        const clean = String(message).replace(/\x1b\[[0-9;]*m/g, "").trim()
        console.warn("Reload failed:\n" + clean)
        root.failed = true
        root.errorText = clean !== "" ? clean : "Reload failed (no details reported)."
        root.copied = false
        root.targetMonitorName = root.focusedMonitorName()
        hideTimer.stop()
        root.open = true
    }

    function dismiss() {
        hideTimer.stop()
        root.open = false
    }

    function copyError() {
        Quickshell.execDetached(["sh", "-c", "printf '%s\\n' \"$1\" | wl-copy", "sh", root.errorText])
        root.copied = true
        copiedTimer.restart()
    }

    Timer {
        id: hideTimer
        interval: root.okHideDelay
        onTriggered: root.open = false
    }

    Timer {
        id: copiedTimer
        interval: 1600
        onTriggered: root.copied = false
    }

    Connections {
        target: Quickshell

        function onReloadCompleted() {
            // Older Quickshell builds have no built-in popup to silence.
            if (typeof Quickshell.inhibitReloadPopup === "function")
                Quickshell.inhibitReloadPopup()
            root.showOk()
        }

        function onReloadFailed(errorString) {
            if (typeof Quickshell.inhibitReloadPopup === "function")
                Quickshell.inhibitReloadPopup()
            root.showError(errorString)
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property var modelData
            screen: modelData

            readonly property bool isTarget: modelData.name === root.targetMonitorName
            readonly property bool wantsShow: win.isTarget && root.open

            // 0 fully hidden .. 1 fully shown (see OSDPopup.qml).
            property real revealed: 0

            onWantsShowChanged: {
                showAnim.stop()
                hideAnim.stop()
                if (wantsShow)
                    showAnim.restart()
                else
                    hideAnim.restart()
            }

            NumberAnimation {
                id: showAnim
                target: win
                property: "revealed"
                to: 1
                duration: 180
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                id: hideAnim
                target: win
                property: "revealed"
                to: 0
                duration: 240
                easing.type: Easing.InCubic
            }

            visible: revealed > 0.001
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "sekaipop-reload"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            readonly property real uiScale: ShellScale.forScreen(win.screen)

            // Top-right, clear of the bar. A top bar pushes it down, a
            // right bar pushes it left; a bottom bar moves it to the
            // bottom-right corner instead, above the bar (the bar's
            // edge: services/BarPositionService.qml). A left bar leaves
            // the top-right corner alone.
            readonly property string barPosition: BarPositionService.position
            readonly property real barOffset: Math.round((BarPositionService.thickness + root.gap) * win.uiScale)
            readonly property real edgeGap: Math.round(16 * win.uiScale)
            anchors {
                top: win.barPosition !== "bottom"
                bottom: win.barPosition === "bottom"
                right: true
            }
            margins {
                top: win.barPosition === "top" ? win.barOffset : win.edgeGap
                bottom: win.barPosition === "bottom" ? win.barOffset : 0
                right: win.barPosition === "right" ? win.barOffset : win.edgeGap
            }

            implicitWidth: Math.ceil(card.width * win.uiScale)
            implicitHeight: Math.ceil(card.height * win.uiScale)

            ScaleHost {
                anchors.fill: parent
                factor: win.uiScale

                Pill {
                    id: card

                    readonly property color errorRed: "#e5484d"

                    width: root.failed ? 440 : 250
                    implicitHeight: body.implicitHeight + 26 + ringWidth * 2 + shadowDy
                    cornerRadius: 22
                    ringWidth: 6
                    fillColor: Theme.surface
                    borderWidth: Theme.borderWidth
                    shadowDx: 4
                    shadowDy: 4

                    opacity: win.revealed
                    scale: 0.94 + 0.06 * win.revealed
                    transformOrigin: win.barPosition === "bottom" ? Item.BottomRight : Item.TopRight

                    Behavior on width {
                        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                    }

                    Column {
                        id: body
                        x: 14
                        y: 13
                        width: parent.width - 28
                        spacing: 12

                        // ===== header =====
                        Item {
                            width: parent.width
                            height: 36

                            Rectangle {
                                id: badge
                                width: 36
                                height: 36
                                radius: 18
                                color: root.failed ? card.errorRed : Theme.accentMint
                                border.width: Theme.borderWidth
                                border.color: Theme.line
                                antialiasing: true

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    size: 20
                                    name: root.failed ? "error" : "check"
                                    color: root.failed ? "#ffffff" : Theme.colBorder
                                }
                            }

                            Text {
                                anchors.left: badge.right
                                anchors.leftMargin: 10
                                anchors.right: closeButton.left
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                text: root.failed ? "Reload failed" : "Shell reloaded"
                                color: Theme.ink
                                font.family: Theme.fontFamily
                                font.pixelSize: 15
                                font.weight: Font.ExtraBold
                                font.styleName: Theme.fontStyleBold
                            }

                            Rectangle {
                                id: closeButton
                                visible: root.failed
                                width: 30
                                height: 30
                                radius: 15
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                color: closeArea.containsMouse ? Theme.surfaceHover : "transparent"
                                border.width: 2
                                border.color: Theme.line
                                antialiasing: true

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    name: "close"
                                    size: 18
                                    color: Theme.ink
                                }

                                MouseArea {
                                    id: closeArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.dismiss()
                                }
                            }
                        }

                        // ===== the error =====
                        Rectangle {
                            id: errorBox
                            visible: root.failed
                            width: parent.width
                            height: Math.min(errorFlick.contentHeight, 220) + 20
                            radius: 12
                            color: Theme.surfaceDivider
                            clip: true

                            WheelScroll { scroller: errorFlick }
                            Flickable {
                                id: errorFlick
                                anchors.fill: parent
                                anchors.margins: 10
                                contentWidth: width
                                contentHeight: errorLabel.implicitHeight
                                boundsBehavior: Flickable.StopAtBounds
                                clip: true

                                Text {
                                    id: errorLabel
                                    width: errorFlick.width
                                    wrapMode: Text.WrapAnywhere
                                    text: root.errorText
                                    color: Theme.ink
                                    font.family: "monospace"
                                    font.pixelSize: 12
                                }
                            }
                        }

                        // ===== buttons =====
                        Row {
                            visible: root.failed
                            spacing: 10
                            layoutDirection: Qt.RightToLeft
                            width: parent.width

                            Rectangle {
                                width: dismissLabel.implicitWidth + 28
                                height: 34
                                radius: 17
                                color: dismissArea.containsMouse ? Theme.surfaceHover : "transparent"
                                border.width: 2
                                border.color: Theme.line
                                antialiasing: true

                                Text {
                                    id: dismissLabel
                                    anchors.centerIn: parent
                                    text: "Dismiss"
                                    color: Theme.ink
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                }

                                MouseArea {
                                    id: dismissArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.dismiss()
                                }
                            }

                            Rectangle {
                                width: copyLabel.implicitWidth + 28
                                height: 34
                                radius: 17
                                color: root.copied ? Theme.accentMint
                                    : (copyArea.containsMouse ? Theme.surfaceHover : "transparent")
                                border.width: 2
                                border.color: Theme.line
                                antialiasing: true

                                Text {
                                    id: copyLabel
                                    anchors.centerIn: parent
                                    text: root.copied ? "Copied" : "Copy error"
                                    color: root.copied ? Theme.colBorder : Theme.ink
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                }

                                MouseArea {
                                    id: copyArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.copyError()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
