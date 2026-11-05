pragma Singleton

import Quickshell

Singleton {
    property bool controlOpen: false

    property bool launcherOpen: false
    property string launcherScreen: ""
    property string launcherInitial: ""     // text already typed when the launcher opens by itself

    property bool wallpaperOpen: false
    property string wallpaperScreen: ""

    property bool powerOpen: false
    property string powerScreen: ""

    property bool captureOpen: false
    property string captureScreen: ""

    // Recording menu (right-click on the pill)
    property bool recMenuOpen: false
    property string recMenuScreen: ""

    // Lockscreen
    property bool locked: false
    property bool lockTest: false
    property int lockTestLeft: 0
}
