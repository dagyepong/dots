import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

HypeOSD {
    id: root

    osdWidth: Theme.iconSize + Theme.spacingS * 2
    osdHeight: Theme.iconSize + Theme.spacingS * 2
    autoHideInterval: 2000
    enableMouseInteraction: false

    property bool lastCapsLockState: false

    Connections {
        target: HYPEService

        function onCapsLockStateChanged() {
            if (lastCapsLockState !== HYPEService.capsLockState && SettingsData.osdCapsLockEnabled) {
                root.show()
            }
            lastCapsLockState = HYPEService.capsLockState
        }
    }

    Component.onCompleted: {
        lastCapsLockState = HYPEService.capsLockState
    }

    content: HypeIcon {
        anchors.centerIn: parent
        name: HYPEService.capsLockState ? "shift_lock" : "shift_lock_off"
        size: Theme.iconSize
        color: Theme.primary
    }
}
