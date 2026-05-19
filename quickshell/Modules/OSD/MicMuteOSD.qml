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

    Connections {
        target: AudioService
        function onMicMuteChanged() {
            if (SettingsData.osdMicMuteEnabled) {
                root.show()
            }
        }
    }

    content: HypeIcon {
        anchors.centerIn: parent
        name: AudioService.source && AudioService.source.audio && AudioService.source.audio.muted ? "mic_off" : "mic"
        size: Theme.iconSize
        color: AudioService.source && AudioService.source.audio && AudioService.source.audio.muted ? Theme.error : Theme.primary
    }
}
