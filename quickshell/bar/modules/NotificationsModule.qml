// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   N O T I F I C A T I O N S   M O D U L E                                │
// │   notifications · unread count, history when open                        │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../theme"
import "../../services"
import "../island/controls"

// A bell (crossed out in Do Not Disturb) with the pending count. The detail
// reuses the control centre's notification list.
Item {
    id: root

    implicitWidth: holder.implicitWidth
    implicitHeight: holder.implicitHeight

    Loader {
        id: holder
        anchors.fill: parent
        sourceComponent: detail
    }

    Component {
        id: detail

        // No card: the island is the background.
        NotificationList {
            bare: true
        }
    }
}
