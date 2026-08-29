// ┌────────────────────────────────────────────────────────┐
// │█▀▀▀▀▀▀▀▀█░░░█░█░█▀▀░█░█░█▀▄░█▀█░█▀█░█▀▄░█▀▄░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀█░░░█▀▄░█▀▀░░█░░█▀▄░█░█░█▀█░█▀▄░█░█░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀█░░░▀░▀░▀▀▀░░▀░░▀▀░░▀▀▀░▀░▀░▀░▀░▀▀░░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀▀────────────────────────────────────▀▀▀▀▀▀▀▀▀█│
// ├┤ Author  : Daniel Berg <mail@roosta.sh>                ├┤
// ││ Repo    : https://github.com/roosta/dotfiles          ││
// ││ Site    : https://www.roosta.sh                       ││
// ├┤ License : GNU General Public License v3               ├┤
// ┆└──────────────────────────────────────────────────────┘┆

import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import qs.config

Singleton {
  id: root
  property var layout: {
    return Config.keyboardLayouts.find(l => l.default)
  }
  property bool capsLock: false

  // Hyprland device query process (Disabled under Niri)
  Process {
    id: devicesProc
    running: false
    command: ["hyprctl", "-j", "devices"]

    stdout: StdioCollector {
      id: devicesCollector
      onStreamFinished: {
        try {
          const parsed = JSON.parse(devicesCollector.text);
          const main = parsed["keyboards"]?.find(kb => kb.main);
          const keymap = main?.["active_keymap"];
          root.capsLock = main?.capsLock ?? false
          root.layout = Config.keyboardLayouts.find(l => l.label === keymap)
        } catch (e) {
          console.log("[Keyboard] Failed to parse hyprctl devices: " + e)
        }
      }
    }
  }

  // GlobalShortcut disabled under Niri
  /*
  GlobalShortcut {
    name: "shiftlock"
    description: "Handles capslock state"
    onPressed: {
      root.capsLock = !root.capsLock
    }
  }
  */

  // Hyprland layout switch process (Disabled under Niri)
  Process {
    id: switchProc
    running: false
    command: ["hyprctl", "switchxkblayout", "current", "next"]
  }

  function nextLayout() {
    // switchProc.running = true
  }

  /* Disabled Hyprland event listener
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name === "activelayout") {
        devicesProc.running = true
      }
    }
  }
  */
}
