import QtQuick 6.10
import QtQuick.Controls 6.10
import QtQuick.Layouts 6.10
import Quickshell
import Quickshell.Wayland
import "../../Commons" as Commons
import "../../Widgets" as Widgets
import "." as Wallpaper

PanelWindow {
    id: root

    property string imageSource: ""
    property string tooltipText: ""
    property bool shouldShow: false

    property string filePath: ""
    property string fileName: ""
    property bool isFromDownloaded: false
    property string wallhavenId: ""
    property string wallhavenFullUrl: ""

    signal previewClosed()
    signal setRequested()
    signal saveRequested()
    signal deleteRequested()

    screen: Quickshell.screens[0]
    visible: shouldShow
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: shouldShow ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    readonly property int previewWidth: Quickshell.screens[0]
        ? Math.min(1400, Quickshell.screens[0].width - 80)
        : 1200
    readonly property int previewHeight: Quickshell.screens[0]
        ? Math.min(900, Quickshell.screens[0].height - 80)
        : 800

    anchors.left: true
    anchors.right: true
    anchors.top: true
    anchors.bottom: true

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.5)
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            root.shouldShow = false
            root.previewClosed()
        }
    }

    FocusScope {
        anchors.centerIn: parent
        width: root.previewWidth
        height: root.previewHeight
        focus: root.shouldShow

        Keys.onEscapePressed: {
            root.shouldShow = false
            root.previewClosed()
        }

        Rectangle {
            anchors.fill: parent
            color: Wallpaper.WallpaperColors.surface
            radius: Commons.Theme.radiusPanel
            border.color: Wallpaper.WallpaperColors.border
            border.width: 1

            MouseArea {
                anchors.fill: parent
                onClicked: mouse.accepted = true
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Commons.Theme.radius
                    color: Wallpaper.WallpaperColors.surfaceContainer
                    clip: true

                    Image {
                        id: previewImage
                        anchors.fill: parent
                        source: {
                            if (!root.imageSource) return ""
                            if (root.imageSource.startsWith("file://")) return root.imageSource
                            if (root.imageSource.startsWith("/")) return "file://" + root.imageSource
                            return root.imageSource
                        }
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        smooth: true
                        cache: true
                    }

                    Text {
                        anchors.centerIn: parent
                        text: !root.imageSource ? "" : (previewImage.status === Image.Loading ? "Loading..." : (previewImage.status === Image.Error ? "Failed to load" : ""))
                        font.family: Commons.Theme.fontUI
                        font.pixelSize: 14
                        color: Wallpaper.WallpaperColors.subText
                        visible: text.length > 0
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: root.tooltipText
                        font.family: Commons.Theme.fontUI
                        font.pixelSize: 11
                        color: Wallpaper.WallpaperColors.subText
                        elide: Text.ElideMiddle
                        visible: root.tooltipText.length > 0
                    }
                    RowLayout {
                        Layout.alignment: Qt.AlignRight
                        spacing: 8
                        Widgets.TextButton {
                            text: "Set"
                            textColor: Wallpaper.WallpaperColors.primary
                            visible: root.filePath.length > 0 || (root.wallhavenId.length > 0 && root.wallhavenFullUrl.length > 0)
                            onClicked: {
                                root.setRequested()
                                root.shouldShow = false
                                root.previewClosed()
                            }
                        }
                        Widgets.TextButton {
                            text: "Save"
                            textColor: Wallpaper.WallpaperColors.primary
                            visible: (root.filePath.length > 0 && root.isFromDownloaded) || (root.wallhavenId.length > 0 && root.wallhavenFullUrl.length > 0)
                            onClicked: {
                                root.saveRequested()
                                root.shouldShow = false
                                root.previewClosed()
                            }
                        }
                        Widgets.TextButton {
                            text: "Delete"
                            textColor: Wallpaper.WallpaperColors.primary
                            visible: root.filePath.length > 0
                            onClicked: {
                                root.deleteRequested()
                                root.shouldShow = false
                                root.previewClosed()
                            }
                        }
                        Widgets.TextButton {
                            text: "Close"
                            textColor: Wallpaper.WallpaperColors.primary
                            onClicked: {
                                root.shouldShow = false
                                root.previewClosed()
                            }
                        }
                    }
                }
            }
        }
    }
}
