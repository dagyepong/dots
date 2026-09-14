// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   D E T A I L   F A C E                                                  │
// │   a module's expanded view · its card or its menu                        │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../theme"
import "../../services"
import "../modules"
import "./controls"

// A module opened from the bar: its detail card or, where the control centre
// has a list for it (the network), that list at its own size
// (`ModuleService.openSize`). The island draws this for every detail without
// knowing which modules have a menu.
Item {
    id: root

    property string moduleId: ""

    signal closed()

    readonly property string menu: root.moduleId === "network"
        ? "wifi" : (root.moduleId === "bluetooth" ? "bluetooth" : "")

    // The calendar reuses the control centre's month rather than drawing a
    // second one.
    readonly property bool month: root.moduleId === "calendar"

    Loader {
        anchors.fill: parent
        // A menu is laid out for a panel's margins; a card brings its own.
        anchors.margins: root.menu !== "" ? Theme.panelPadding - 4 : 0
        sourceComponent: root.menu === "wifi" ? wifi
            : root.menu === "bluetooth" ? bluetooth
            : root.month ? calendar : card
    }

    Component {
        id: calendar

        // Bare: the island is the card.
        CalendarCard {
            bare: true
            padding: 12
            onPanelRequested: panel => ModuleService.requestPanel(panel)
        }
    }

    Component {
        id: wifi

        NetworkDetail {
            backable: false
            onBack: root.closed()
        }
    }

    Component {
        id: bluetooth

        BluetoothDetail {
            backable: false
            onBack: root.closed()
        }
    }

    Component {
        id: card

        Module {
            moduleId: root.moduleId
            compact: false
        }
    }
}
