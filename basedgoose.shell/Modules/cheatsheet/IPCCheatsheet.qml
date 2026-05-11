import QtQuick 6.10
import QtQuick.Layouts 6.10
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../../Commons" as Commons
import "../../Widgets" as Widgets

Widgets.PopupWindow {
    id: popupWindow
    
    ipcTarget: "cheatsheet"
    initialScale: 0.94
    transformOriginX: 0.5
    transformOriginY: 0.5
    closeOnClickOutside: true
    
    function copyToClipboard(text) {
        var escapedText = text.replace(/'/g, "'\"'\"'")
        copyProcess.command = ["sh", "-c", "printf '%s' '" + escapedText + "' | wl-copy"]
        copyProcess.running = false
        copyProcess.running = true
    }
    
    readonly property color cSurface: Commons.Theme.background
    readonly property color cSurfaceContainer: Qt.lighter(Commons.Theme.background, 1.15)
    readonly property color cPrimary: Commons.Theme.primary
    readonly property color cText: Commons.Theme.foreground
    readonly property color cSubText: Qt.rgba(cText.r, cText.g, cText.b, 0.6)
    readonly property color cBorder: Qt.rgba(cText.r, cText.g, cText.b, 0.08)
    readonly property color cHover: Qt.rgba(cText.r, cText.g, cText.b, 0.06)
    
    anchors {
        top: true
        left: true
    }
    
    margins {
        top: Quickshell.screens[0] ? (Quickshell.screens[0].height - implicitHeight) / 2 : 100
        left: Quickshell.screens[0] ? (Quickshell.screens[0].width - implicitWidth) / 2 : 100
    }
    
    implicitWidth: 600
    implicitHeight: 500
    
    Rectangle {
        id: backgroundRect
        anchors.fill: parent
        color: Commons.Theme.background
        radius: Commons.Theme.radiusPanel
        border.color: cBorder
        border.width: 1
        
        Process {
            id: copyProcess
            running: false
        }
        
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.35)
            shadowBlur: 1.0
            shadowVerticalOffset: 6
        }
        
        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12
            
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                
                Rectangle {
                    width: 36
                    height: 36
                    radius: Commons.Theme.radius
                    color: Commons.Theme.primaryMuted
                    
                    Text {
                        anchors.centerIn: parent
                        text: "󰌌"
                        font.family: Commons.Theme.fontIcon
                        font.pixelSize: 18
                        color: cPrimary
                    }
                }
                
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    
                    Text {
                        text: "IPC Cheatsheet"
                        font.family: Commons.Theme.fontUI
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        color: cText
                    }
                    
                    Text {
                        text: "Available IPC commands"
                        font.family: Commons.Theme.fontUI
                        font.pixelSize: 11
                        color: cSubText
                    }
                }
            }
            
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Commons.Theme.radius
                color: cSurfaceContainer
                clip: true
                
                Flickable {
                    id: flickable
                    anchors.fill: parent
                    anchors.margins: 8
                    contentWidth: width
                    contentHeight: commandsColumn.height
                    boundsBehavior: Flickable.StopAtBounds
                    
                    ColumnLayout {
                        id: commandsColumn
                        width: flickable.width
                        spacing: 12
                        
                        Repeater {
                            model: [
                                { target: "wallpaper", command: "qs -c basedgoose.shell ipc call wallpaper toggle", description: "Toggle wallpaper selector" },
                                { target: "calendar", command: "qs -c basedgoose.shell ipc call calendar toggle", description: "Toggle calendar popup" },
                                { target: "launcher", command: "qs -c basedgoose.shell ipc call launcher toggle", description: "Toggle app launcher" },
                                { target: "power", command: "qs -c basedgoose.shell ipc call power toggle", description: "Toggle power menu" },
                                { target: "volume", command: "qs -c basedgoose.shell ipc call volume toggle", description: "Toggle volume popup" },
                                { target: "cheatsheet", command: "qs -c basedgoose.shell ipc call cheatsheet toggle", description: "Toggle IPC cheatsheet" },
                                { target: "shellmenu", command: "qs -c basedgoose.shell ipc call shellmenu toggle", description: "Toggle shell menu" },
                                { target: "notification center", command: "qs -c basedgoose.shell ipc call notificatios toggle", description: "Toggle notification center" },
                                { target: "display", command: "qs -c basedgoose.shell ipc call display toggle", description: "Toggle display manager" }
                            ]
                            
                            Rectangle {
                                id: commandItem
                                Layout.fillWidth: true
                                Layout.preferredHeight: commandRow.implicitHeight + 16
                                radius: Commons.Theme.radius
                                color: itemMouse.containsMouse ? cHover : "transparent"
                                border.width: 1
                                border.color: copyFeedback.running ? cPrimary : cBorder
                                
                                property bool copied: false
                                
                                RowLayout {
                                    id: commandRow
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 12
                                    
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4
                                        
                                        Text {
                                            text: modelData.command
                                            font.family: Commons.Theme.fontMono
                                            font.pixelSize: 11
                                            color: copyFeedback.running ? cPrimary : cPrimary
                                            Layout.fillWidth: true
                                        }
                                        
                                        Text {
                                            text: copyFeedback.running ? "Copied to clipboard!" : modelData.description
                                            font.family: Commons.Theme.fontUI
                                            font.pixelSize: 10
                                            color: copyFeedback.running ? cPrimary : cSubText
                                            Layout.fillWidth: true
                                        }
                                    }
                                }
                                
                                SequentialAnimation {
                                    id: copyFeedback
                                    running: false
                                    
                                    PropertyAnimation {
                                        target: commandItem
                                        property: "border.color"
                                        to: cPrimary
                                        duration: 0
                                    }
                                    
                                    PauseAnimation {
                                        duration: 800
                                    }
                                    
                                    PropertyAnimation {
                                        target: commandItem
                                        property: "border.color"
                                        to: cBorder
                                        duration: 200
                                    }
                                }
                                
                                MouseArea {
                                    id: itemMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        popupWindow.copyToClipboard(modelData.command)
                                        copyFeedback.running = true
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
