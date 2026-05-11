//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import QtQuick 6.10
import "./Modules/bar" as BarModule
import "./Modules/power" as Power
import "./Modules/applauncher" as AppLauncher
import "./Modules/bluetooth" as Bluetooth
import "./Modules/mediaplayer" as MediaPlayer
import "./Modules/volume" as Volume
import "./Modules/notifications" as Notifications
import "./Modules/osd" as Osd
import "./Modules/wallpaper" as Wallpaper
import "./Modules/cheatsheet" as Cheatsheet
import "./Modules/shellmenu" as ShellMenu
import "./Modules/display" as DisplayModule
import "./Modules/settings" as SettingsModule
import "./Services" as Services

Scope {
    Component.onCompleted: {
        if (Services.Notifications && Services.Notifications.server) {
            console.log("[Shell] Notification server initialized")
        } else {
            console.error("[Shell] Failed to initialize notification server")
        }
    }
    
    BarModule.Bar {
        id: bar
    }
    
    Power.PowerMenuPopup {
        id: powerMenu
        barPosition: bar.barPosition
    }
    
    AppLauncher.AppLauncher {
        id: appLauncher
    }

    Osd.Wrapper {
        id: osdWrapper
    }

    MediaPlayer.MediaPlayerPopup {
        id: mediaPopup
        barPosition: bar.barPosition
    }

    Notifications.NotificationPopups {
        id: notificationPopups
    }
    
    Notifications.NotificationCenter {
        id: notificationCenter
    }
    
    Wallpaper.WallpaperPreviewOverlay {
        id: wallpaperPreviewOverlay
    }

    Wallpaper.WallpaperSelector {
        id: wallpaperSelector
        previewOverlay: wallpaperPreviewOverlay
    }
    
    Cheatsheet.IPCCheatsheet {
        id: ipcCheatsheet
    }
    
    ShellMenu.ShellMenuPopup {
        id: shellMenuPopup
        cheatsheetPopup: ipcCheatsheet
        wallpaperSelector: wallpaperSelector
        displayManager: displayManagement
        settingsWindow: settingsWin
    }
    
    DisplayModule.DisplayManagerWindow {
        id: displayManagement
    }
    
    SettingsModule.SettingsWindow {
        id: settingsWin
    }
    
    Process {
        id: awwwDaemon
        running: false
        command: ["awww-daemon"]
        onStarted: console.log("[Shell] awww-daemon started")
    }

    Process {
        id: awwwKillProcess
        running: false
        command: ["awww", "kill"]
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: {
            startTimer.restart()
        }
    }

    Timer {
        id: startTimer
        interval: 100
        repeat: false
        running: true
        onTriggered: {
            awwwDaemon.running = true
        }
    }

    Component.onDestruction: {
        console.log("[Shell] Cleaning up awww-daemon")
        awwwDaemon.running = false
        awwwKillProcess.running = true
    }

    QtObject {
        id: wiring
        Component.onCompleted: {
            if (mediaPopup) bar.mediaPopup = mediaPopup
            if (notificationPopups) bar.notificationPopups = notificationPopups
            if (notificationCenter) bar.notificationCenter = notificationCenter
            if (shellMenuPopup) bar.shellMenuPopup = shellMenuPopup
            if (powerMenu) bar.powerMenuPopup = powerMenu
        }
    }
    Connections {
        target: bar
        function onVolumePopupChanged() {
            if (bar.volumePopup) osdWrapper.volumePopup = bar.volumePopup
        }
    }
}
