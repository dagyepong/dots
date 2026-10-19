import QtQuick
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// The DOCK tab of Edit Desktop's shelf (EditTray.qml): how the dock is drawn,
// which edge it sits on, when it hides, and whether it stays above windows. The same little keys as
// the BAR tab's Style / Position (EditPickKey.qml), laid out loose on the shelf
// with open space between them: no card, border or lane round any of it.
//
//   STYLE          float / transparent / capsule    SettingsService "dock.style"
//   POSITION       bottom / top / left / right      SettingsService "dock.position"
//   HIDING         always shown / auto-hide / smart SettingsService "dock.hideMode"
//   ABOVE WINDOWS  keep it pinned above windows     PinnedAppsService.dockPinned
//   TOOLS          Search / Files / Clipboard /     PinnedAppsService.hasTool / toggleTool
//                  Shelf / Timer on or off the dock
//   APPS           one key per pinned app: lit = on PinnedAppsService.isHidden / toggleHidden
//                  the dock, dark = switched off (still pinned, no key; it comes back with a click)
//
// (The style is drawn by Dock.qml: Float is the pill it always was, Transparent has no
// background, only the keys, Capsule is a fully rounded body in a thin rim.)
// They are the very same switches as Settings Panel -> Desktop -> Dock, so the
// two always agree. A click changes the dock at once; hovering a key shows its
// name in the heading.
Item {
    id: root

    readonly property var styleOptions: [
        { id: "float", label: "Float" },
        { id: "transparent", label: "Transparent" },
        { id: "capsule", label: "Capsule" }
    ]

    readonly property var positionOptions: [
        { id: "bottom", label: "Bottom" },
        { id: "top", label: "Top" },
        { id: "left", label: "Left" },
        { id: "right", label: "Right" }
    ]

    readonly property var hideOptions: [
        { id: "off", label: "Always shown", icon: "visibility" },
        { id: "auto", label: "Auto-hide", icon: "vertical_align_bottom" },
        { id: "smart", label: "Smart hide", icon: "auto_awesome" }
    ]

    // The hide mode in force (the old autoHide switch still counts as "auto"),
    // the same rule Settings uses.
    readonly property string hideNow: SettingsService.get("dock.hideMode") !== "off"
        ? SettingsService.get("dock.hideMode")
        : (SettingsService.flag("dock.autoHide") ? "auto" : "off")

    // The dock's built-in tools (the same five as PinnedAppsService.toolIds and
    // Dock.qml's toolMeta). A lit key = that tool is on the dock.
    readonly property var toolOptions: [
        { id: "search", label: "Search", icon: "search" },
        { id: "files", label: "Files", icon: "folder" },
        { id: "clipboard", label: "Clipboard", icon: "content_paste" },
        { id: "shelf", label: "Shelf", icon: "inventory_2" },
        { id: "timer", label: "Timer", icon: "timer" }
    ]

    readonly property int toolsOn: root.toolOptions.filter(o => PinnedAppsService.hasTool(o.id)).length

    // Every pinned app (the ones inside folders too), in the order they stand in the dock.
    readonly property var pinnedApps: PinnedAppsService.allApps()
    readonly property int appsOn: root.pinnedApps.filter(a => a.hidden !== true).length
    property string appHover: ""

    function appName(cls) {
        let entry = null
        try {
            entry = DesktopEntries.heuristicLookup(cls)
        } catch (e) {}
        return (entry && entry.name) || cls
    }

    property string toolHover: ""
    property string styleHover: ""
    property string positionHover: ""
    property string hideHover: ""
    property bool pinHover: false

    function labelFor(options, id) {
        for (const o of options) {
            if (o.id === id)
                return o.label
        }
        return ""
    }

    // The five groups side by side while they fit. When the shelf is too narrow the
    // last group(s) drop to a second line (the shelf has the height for two) instead of
    // being cut off at the edge.
    Flow {
        id: groups
        x: 6
        width: root.width - 12
        y: Math.max(0, Math.round((root.height - groups.height) / 2))
        spacing: 24

        Column {
            spacing: 9

            EditPickHead {
                title: "STYLE"
                value: root.labelFor(root.styleOptions,
                    root.styleHover !== "" ? root.styleHover : SettingsService.get("dock.style"))
            }

            Row {
                spacing: 8

                Repeater {
                    model: root.styleOptions

                    EditPickKey {
                        required property var modelData

                        // Drawn on the edge the dock is on now, so the picture matches the dock.
                        edge: SettingsService.get("dock.position")
                        variant: modelData.id
                        on: SettingsService.get("dock.style") === modelData.id
                        onPicked: SettingsService.set("dock.style", modelData.id)
                        onHoveredChanged: {
                            if (hovered)
                                root.styleHover = modelData.id
                            else if (root.styleHover === modelData.id)
                                root.styleHover = ""
                        }
                    }
                }
            }
        }

        Column {
            spacing: 9

            EditPickHead {
                title: "POSITION"
                value: root.labelFor(root.positionOptions,
                    root.positionHover !== "" ? root.positionHover : SettingsService.get("dock.position"))
            }

            Row {
                spacing: 8

                Repeater {
                    model: root.positionOptions

                    EditPickKey {
                        required property var modelData

                        edge: modelData.id
                        on: SettingsService.get("dock.position") === modelData.id
                        onPicked: SettingsService.set("dock.position", modelData.id)
                        onHoveredChanged: {
                            if (hovered)
                                root.positionHover = modelData.id
                            else if (root.positionHover === modelData.id)
                                root.positionHover = ""
                        }
                    }
                }
            }
        }

        Column {
            spacing: 9

            EditPickHead {
                title: "HIDING"
                value: PinnedAppsService.dockPinned && root.hideHover === "" ? "Off while pinned"
                    : root.labelFor(root.hideOptions, root.hideHover !== "" ? root.hideHover : root.hideNow)
            }

            Row {
                spacing: 8

                Repeater {
                    model: root.hideOptions

                    EditPickKey {
                        required property var modelData

                        icon: modelData.icon
                        on: root.hideNow === modelData.id
                        onPicked: {
                            SettingsService.set("dock.hideMode", modelData.id)
                            SettingsService.set("dock.autoHide", false)
                        }
                        onHoveredChanged: {
                            if (hovered)
                                root.hideHover = modelData.id
                            else if (root.hideHover === modelData.id)
                                root.hideHover = ""
                        }
                    }
                }
            }
        }

        Column {
            spacing: 9

            EditPickHead {
                title: "ABOVE WINDOWS"
                value: PinnedAppsService.dockPinned ? "Pinned" : "Under windows"
            }

            Row {
                spacing: 8

                EditPickKey {
                    icon: "push_pin"
                    on: PinnedAppsService.dockPinned
                    onPicked: PinnedAppsService.toggleDockPinned()
                }
            }
        }

        Column {
            spacing: 9

            EditPickHead {
                title: "TOOLS"
                value: root.toolHover !== ""
                    ? root.labelFor(root.toolOptions, root.toolHover)
                        + (PinnedAppsService.hasTool(root.toolHover) ? " · on" : " · off")
                    : root.toolsOn + " of " + root.toolOptions.length + " on"
            }

            Row {
                spacing: 8

                Repeater {
                    model: root.toolOptions

                    EditPickKey {
                        required property var modelData

                        icon: modelData.icon
                        on: PinnedAppsService.hasTool(modelData.id)
                        onPicked: PinnedAppsService.toggleTool(modelData.id)
                        onHoveredChanged: {
                            if (hovered)
                                root.toolHover = modelData.id
                            else if (root.toolHover === modelData.id)
                                root.toolHover = ""
                        }
                    }
                }
            }
        }

        Column {
            spacing: 9
            visible: root.pinnedApps.length > 0

            EditPickHead {
                title: "APPS"
                value: root.appHover !== ""
                    ? root.appName(root.appHover) + (PinnedAppsService.isHidden(root.appHover) ? " · off" : " · on")
                    : root.appsOn + " of " + root.pinnedApps.length + " on"
            }

            // Wraps inside the group when there are more apps than the shelf is wide.
            Flow {
                spacing: 6
                width: Math.min(root.pinnedApps.length * 46 - 6, Math.max(46, groups.width))

                Repeater {
                    model: root.pinnedApps

                    EditAppKey {
                        required property var modelData

                        iconName: modelData.iconName
                        on: modelData.hidden !== true
                        onPicked: PinnedAppsService.toggleHidden(modelData.class)
                        onHoveredChanged: {
                            if (hovered)
                                root.appHover = modelData.class
                            else if (root.appHover === modelData.class)
                                root.appHover = ""
                        }
                    }
                }
            }
        }
    }
}
