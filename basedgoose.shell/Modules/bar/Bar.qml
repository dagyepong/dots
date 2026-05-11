//@ pragma ComponentBehavior: Bound
import QtQuick 6.10
import QtQuick.Layouts 6.10
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import "../../Services" as Services
import "../../Commons" as Commons
import "../../Modules/applauncher" as AppLauncher
import "../../Modules/shellmenu" as ShellMenu
import "../../Modules/clock" as Clock
import "../../Modules/notifications" as Notifications
import "../../Modules/power" as Power
import "../../Modules/systemstats" as SystemStats
import "../../Modules/systemtray" as SystemTray
import "../../Modules/workspaces" as Workspaces
import "../../Modules/bluetooth" as Bluetooth
import "../../Modules/network" as Network
import "../../Modules/mediaplayer" as MediaPlayer
import "../../Modules/volume" as Volume

PanelWindow {
    id: bar

    signal showPowerMenu()

    property var bluetoothPopup
    property var networkPopup
    property var calendarPopup
    property var mediaPopup
    property var volumePopup
    property var notificationPopups
    property var notificationCenter
    property var shellMenuPopup
    property var powerMenuPopup

    readonly property string barPosition: Commons.Config.barPosition
    readonly property bool isHorizontal: barPosition === "top" || barPosition === "bottom"
    readonly property bool isVertical: barPosition === "left" || barPosition === "right"

    Services.CpuMonitor { id: cpuMonitor }
    Services.MemoryMonitor { id: memoryMonitor }

    anchors.top: barPosition === "top" || barPosition === "left" || barPosition === "right"
    anchors.bottom: barPosition === "bottom" || barPosition === "left" || barPosition === "right"
    anchors.left: barPosition === "left" || barPosition === "top" || barPosition === "bottom"
    anchors.right: barPosition === "right" || barPosition === "top" || barPosition === "bottom"
    
    margins {
        top: (barPosition === "top" || barPosition === "left" || barPosition === "right") ? Commons.Config.barMargin : 0
        bottom: (barPosition === "bottom" || barPosition === "left" || barPosition === "right") ? Commons.Config.barMargin : 0
        left: (barPosition === "left" || barPosition === "top" || barPosition === "bottom") ? Commons.Config.barMargin : 0
        right: (barPosition === "right" || barPosition === "top" || barPosition === "bottom") ? Commons.Config.barMargin : 0
    }
    
    implicitWidth: isVertical ? Commons.Config.barWidth : undefined
    implicitHeight: isHorizontal ? Commons.Config.barHeight : undefined
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        color: Commons.Theme.background
        opacity: 0.92
        radius: Commons.Theme.radiusPanel
        border.color: Commons.Theme.border
        border.width: 1
    }

    Bluetooth.BluetoothPopup {
        id: btPopup
    }

    Network.NetworkPopup {
        id: netPopup
    }

    Volume.VolumePopup {
        id: volPopup
    }

    Clock.CalendarPopup {
        id: calPopup
    }

    Component.onCompleted: {
        bar.bluetoothPopup = btPopup
        bar.networkPopup = netPopup
        bar.volumePopup = volPopup
        bar.calendarPopup = calPopup
        
        console.log("[Bar] Position:", barPosition, "isVertical:", isVertical)
    }

    Component {
        id: shellMenuComponent
        ShellMenu.ShellMenuButton {
            id: shellMenuBtn
            barWindow: bar
            isVertical: bar.isVertical
            onClicked: {
                if (bar.shellMenuPopup) {
                    if (!bar.shellMenuPopup.shouldShow) {
                        bar.shellMenuPopup.positionNear(shellMenuBtn, bar)
                    }
                    bar.shellMenuPopup.toggle()
                }
            }
        }
    }

    Component {
        id: workspacesComponent
        Workspaces.Workspaces {
            barWindow: bar
            isVertical: bar.isVertical
        }
    }

    Component {
        id: mediaPlayerComponent
        MediaPlayer.MediaPlayer {
            barWindow: bar
            mediaPopup: bar.mediaPopup
            isVertical: bar.isVertical
        }
    }

    Component {
        id: systemStatsComponent
        SystemStats.SystemStats {
            cpuUsage: cpuMonitor.cpuUsage
            memUsed: memoryMonitor.memUsed
            memTotal: memoryMonitor.memTotal
            barWindow: bar
            isVertical: bar.isVertical
        }
    }

    Component {
        id: clockComponent
        Clock.Clock {
            barWindow: bar
            calendarPopup: bar.calendarPopup
            isVertical: bar.isVertical
        }
    }

    Component {
        id: systemTrayComponent
        SystemTray.SystemTrayComponent {
            barWindow: bar
            isVertical: bar.isVertical
        }
    }

    Component {
        id: volumeComponent
        Volume.Volume {
            barWindow: bar
            volumePopup: bar.volumePopup
            isVertical: bar.isVertical
        }
    }

    Component {
        id: bluetoothComponent
        Bluetooth.Bluetooth {
            barWindow: bar
            bluetoothPopup: bar.bluetoothPopup
            isVertical: bar.isVertical
        }
    }

    Component {
        id: networkComponent
        Network.Network {
            barWindow: bar
            networkPopup: bar.networkPopup
            isVertical: bar.isVertical
        }
    }

    Component {
        id: notificationsComponent
        Notifications.NotificationButton {
            notificationCenter: bar.notificationCenter
            barWindow: bar
            isVertical: bar.isVertical
        }
    }

    Component {
        id: powerComponent
        Power.PowerButton {
            barWindow: bar
            powerMenuPopup: bar.powerMenuPopup
            isVertical: bar.isVertical
            onClicked: bar.showPowerMenu()
        }
    }

    function getModuleComponent(moduleName) {
        switch (moduleName) {
            case "shellmenu": return shellMenuComponent
            case "workspaces": return workspacesComponent
            case "mediaplayer": return mediaPlayerComponent
            case "systemstats": return systemStatsComponent
            case "clock": return clockComponent
            case "systemtray": return systemTrayComponent
            case "volume": return volumeComponent
            case "bluetooth": return bluetoothComponent
            case "network": return networkComponent
            case "notifications": return notificationsComponent
            case "power": return powerComponent
            default: return null
        }
    }

    Item {
        anchors.fill: parent
        visible: isHorizontal

        // Start section
        RowLayout {
            id: leftRowH
            anchors.left: parent.left
            anchors.leftMargin: Commons.Config.barPadding
            anchors.verticalCenter: parent.verticalCenter
            spacing: Commons.Config.barSpacing

            Repeater {
                model: Commons.Config.barModules.left || []
                delegate: Loader {
                    required property string modelData
                    sourceComponent: bar.getModuleComponent(modelData)
                    Layout.preferredHeight: Commons.Config.componentHeight
                }
            }
        }

        // Center section
        RowLayout {
            id: centerRowH
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            spacing: Commons.Config.barSpacing

            Repeater {
                model: Commons.Config.barModules.center || []
                delegate: Loader {
                    required property string modelData
                    sourceComponent: bar.getModuleComponent(modelData)
                    Layout.preferredHeight: Commons.Config.componentHeight
                }
            }
        }

        // End section
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: Commons.Config.barPadding
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: rightRowH.implicitWidth + Commons.Theme.spacingXl
            implicitHeight: Commons.Config.componentHeight
            color: Commons.Theme.surfaceBase
            radius: Math.round(implicitHeight / 2)

            RowLayout {
                id: rightRowH
                anchors.centerIn: parent
                spacing: 10

                Repeater {
                    model: Commons.Config.barModules.right || []
                    delegate: Loader {
                        required property string modelData
                        sourceComponent: bar.getModuleComponent(modelData)
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredHeight: Commons.Config.componentHeight
                    }
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: isVertical

        // Start section
        ColumnLayout {
            id: leftColV
            anchors.top: parent.top
            anchors.topMargin: Commons.Config.barPadding
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Commons.Config.barSpacing

            Repeater {
                model: Commons.Config.barModules.left || []
                delegate: Loader {
                    required property string modelData
                    sourceComponent: bar.getModuleComponent(modelData)
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }

        // Center section
        ColumnLayout {
            id: centerColV
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Commons.Config.barSpacing

            Repeater {
                model: Commons.Config.barModules.center || []
                delegate: Loader {
                    required property string modelData
                    sourceComponent: bar.getModuleComponent(modelData)
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }

        // End section
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Commons.Config.barPadding
            anchors.horizontalCenter: parent.horizontalCenter
            implicitWidth: Commons.Config.barWidth - Commons.Config.barPadding * 2
            implicitHeight: rightColV.implicitHeight + 16
            color: Commons.Theme.surfaceBase
            radius: Commons.Theme.radiusPanel

            ColumnLayout {
                id: rightColV
                anchors.centerIn: parent
                spacing: 8

                Repeater {
                    model: Commons.Config.barModules.right || []
                    delegate: Loader {
                        required property string modelData
                        sourceComponent: bar.getModuleComponent(modelData)
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }
    }
}
