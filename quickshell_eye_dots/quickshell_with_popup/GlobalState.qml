// ┌──────────────────────────────────────────────────────────────────────┐
// │█▀▀▀▀▀▀▀▀█░░░█▀▀░█░░░█▀█░█▀▄░█▀█░█░░░░░█▀▀░▀█▀░█▀█░▀█▀░█▀▀░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀█░░░█░█░█░░░█░█░█▀▄░█▀█░█░░░░░▀▀█░░█░░█▀█░░█░░█▀▀░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀█░░░▀▀▀░▀▀▀░▀▀▀░▀▀░░▀░▀░▀▀▀░░░▀▀▀░░▀░░▀░▀░░▀░░▀▀▀░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀▀──────────────────────────────────────────────────▀▀▀▀▀▀▀▀▀█│
// ├┤ Author  : Daniel Berg <mail@roosta.sh>                              ├┤
// ││ Repo    : https://github.com/roosta/dotfiles                        ││
// ││ Site    : https://www.roosta.sh                                     ││
// ├┤ License : GNU General Public License v3                            ├┤
// ┆└────────────────────────────────────────────────────────────────────┘┆

pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import qs.config

Singleton {
  id: root
  property bool launcherOpen: false
  property string launcherMonitorId: ""
  property string trayMonitorId: ""
  property string launcherMode: Config.defaultMode
  property bool overlayOpen: root.launcherOpen || root.trayMenuOpen || root.batteryPopupOpen
  property QsMenuHandle activeMenu: null
  property bool trayMenuOpen: false
  property int menuDirection: Qt.LeftToRight
  property int menuIndex: 0

  // Battery popup tracking states
  property bool batteryPopupOpen: false
  property string batteryMonitorId: ""

  Timer {
    id: timer
    interval: Appearance.durations.small
    onTriggered: {
      root.launcherMonitorId = ""
      root.launcherMode = Config.defaultMode
      root.menuDirection = Qt.LeftToRight
      root.menuIndex = 0
    }
  }

  // Handles state swapping for the multi-monitor system power tray cards
  function toggleBatteryPopup(id) {
    if (batteryPopupOpen && batteryMonitorId === id) {
      batteryPopupOpen = false;
      batteryMonitorId = "";
    } else {
      batteryPopupOpen = true;
      batteryMonitorId = id;
    }
  }

  function openTrayMenu(menu, id = Config.primaryDisplay) {
    if (!menu) {
      console.error("No provided menu, cant open menu")
      return
    }
    root.activeMenu = menu
    trayMenuOpen = true
    trayMonitorId = id
  }

  function closeTrayMenu() {
    root.activeMenu = null
    trayMenuOpen = false
  }

  function openLauncher({
    id = Config.primaryDisplay,
    mode = null,
    direction = Qt.LeftToRight,
    index = 0
  }) {
    launcherMonitorId = id
    if (index >= 0) {
      root.menuIndex = index
    }
    if (direction !== Qt.LeftToRight) {
      root.menuDirection = direction
    }
    if (mode) {
      root.launcherMode = mode
    }
    launcherOpen = true
  }

  function closeLauncher() {
    launcherOpen = false
    timer.restart()
  }

  function toggleLauncher({ id, mode = null, direction = Qt.LeftToRight, index = 0 }) {
    if (launcherOpen) {
      closeLauncher()
    } else {
      openLauncher({ id, mode, direction, index })
    }
  }
}
