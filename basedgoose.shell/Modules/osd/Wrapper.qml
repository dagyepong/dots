import Quickshell
import QtQuick

Scope {
    id: root
    
    property var volumePopup

    VolumeOSD {
        volumePopup: root.volumePopup
    }

}