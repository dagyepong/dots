pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  // TODO: improve this
  // assume it is not inhibited by default
  property bool idleInhibited: false

  function poweroff() {
    poweroff.running = true;
  }

  function reboot() {
    reboot.running = true;
  }

  function suspend() {
    suspend.running = true;
  }

  function toggleIdle() {
    if (root.idleInhibited) {
      thaw.running = true;
    } else {
      freeze.running = true;
    }
    root.idleInhibited = !root.idleInhibited;
  }

  Process {
    id: suspend

    command: ["loginctl", "suspend"]
  }

  Process {
    id: reboot

    command: ["loginctl", "reboot"]
  }

  Process {
    id: poweroff

    command: ["loginctl", "poweroff"]
  }

  Process {
    id: freeze

    command: ["systemctl", "--user", "freeze", "hypridle.service"]
  }

  Process {
    id: thaw

    command: ["systemctl", "--user", "thaw", "hypridle.service"]
  }
}
