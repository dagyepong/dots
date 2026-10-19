import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// The VIEWS tab of Edit Desktop's shelf (EditTray.qml): how the Quick Panel's phone is drawn,
// and the overview. The same little keys as the BAR and DOCK tabs (EditPickKey.qml), loose on
// the shelf with open space between them: no card, border or lane round any of it.
//
//   PHONE        2.5D / 2D                  SettingsService "quick.flat"
//   OVERVIEW     film strip / scroll        SettingsService "overview.style"
//   BOARD AT     left / center / right      SettingsService "overview.position"   (board only)
//   BOARD CARDS  how many cards, 1 - 10     SettingsService "overview.workspaces" (board only)
//   BAR PILLS    how many workspace pills   SettingsService "bar.workspaceCount"
//                the bar shows, 1 - 10
//
// They are the very same switches as Settings Panel -> Quick -> Phone and Settings Panel ->
// Hyprland -> Overview and Settings Panel -> Bar, so the two always agree. A click changes it at once; hovering a key
// shows its name in the heading. Like Settings, the board's own options hide while the
// Scroll overview is the one picked (the plugin draws its own strip).
Item {
    id: root

    readonly property var phoneOptions: [
        { id: "tilted", label: "2.5D", icon: "view_in_ar" },
        { id: "flat", label: "2D", icon: "crop_portrait" }
    ]

    readonly property var styleOptions: [
        { id: "board", label: "Film strip", icon: "dashboard" },
        { id: "scroll", label: "Scroll (niri)", icon: "view_column" }
    ]

    readonly property var positionOptions: [
        { id: "left", label: "Left", icon: "align_horizontal_left" },
        { id: "center", label: "Center", icon: "align_horizontal_center" },
        { id: "right", label: "Right", icon: "align_horizontal_right" }
    ]

    readonly property bool scroll: SettingsService.get("overview.style") === "scroll"
    readonly property string phoneNow: SettingsService.flag("quick.flat") ? "flat" : "tilted"
    readonly property int count: Math.max(1, Math.min(10, Math.round(Number(SettingsService.get("overview.workspaces")) || 5)))

    property string phoneHover: ""
    property string styleHover: ""
    property string positionHover: ""

    function labelFor(options, id) {
        for (const o of options) {
            if (o.id === id)
                return o.label
        }
        return ""
    }

    function setCount(n) {
        SettingsService.set("overview.workspaces", Math.max(1, Math.min(10, n)))
    }

    // The bar's workspace pills: the same setting and the same 1 - 10 as Settings -> Bar.
    readonly property int barCount: Math.max(1, Math.min(10, Math.round(Number(SettingsService.get("bar.workspaceCount")) || 5)))

    function setBarCount(n) {
        SettingsService.set("bar.workspaceCount", Math.max(1, Math.min(10, n)))
    }

    // The groups side by side while they fit; when the shelf is too narrow the last
    // one(s) drop to a second line instead of being cut off.
    Flow {
        id: groups
        x: 6
        width: root.width - 12
        y: Math.max(0, Math.round((root.height - groups.height) / 2))
        spacing: 32

        Column {
            spacing: 9

            EditPickHead {
                title: "PHONE"
                value: root.phoneHover === "" && GameModeService.enabled ? "Flat in Game Mode"
                    : root.labelFor(root.phoneOptions, root.phoneHover !== "" ? root.phoneHover : root.phoneNow)
            }

            Row {
                spacing: 8

                Repeater {
                    model: root.phoneOptions

                    EditPickKey {
                        required property var modelData

                        icon: modelData.icon
                        on: root.phoneNow === modelData.id
                        onPicked: SettingsService.set("quick.flat", modelData.id === "flat")
                        onHoveredChanged: {
                            if (hovered)
                                root.phoneHover = modelData.id
                            else if (root.phoneHover === modelData.id)
                                root.phoneHover = ""
                        }
                    }
                }
            }
        }

        Column {
            spacing: 9

            EditPickHead {
                title: "OVERVIEW"
                value: root.styleHover === "" && root.scroll && !ScrollOverviewService.available
                    ? "Scroll \u00b7 plugin not loaded, opens the board"
                    : root.labelFor(root.styleOptions,
                        root.styleHover !== "" ? root.styleHover : SettingsService.get("overview.style"))
            }

            Row {
                spacing: 8

                Repeater {
                    model: root.styleOptions

                    EditPickKey {
                        required property var modelData

                        icon: modelData.icon
                        on: SettingsService.get("overview.style") === modelData.id
                        onPicked: SettingsService.set("overview.style", modelData.id)
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
            visible: !root.scroll
            spacing: 9

            EditPickHead {
                title: "BOARD AT"
                value: root.labelFor(root.positionOptions,
                    root.positionHover !== "" ? root.positionHover : SettingsService.get("overview.position"))
            }

            Row {
                spacing: 8

                Repeater {
                    model: root.positionOptions

                    EditPickKey {
                        required property var modelData

                        icon: modelData.icon
                        on: SettingsService.get("overview.position") === modelData.id
                        onPicked: SettingsService.set("overview.position", modelData.id)
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
            visible: !root.scroll
            spacing: 9

            EditPickHead {
                title: "BOARD CARDS"
                value: String(root.count)
            }

            Row {
                spacing: 8

                EditPickKey {
                    icon: "remove"
                    onPicked: root.setCount(root.count - 1)
                }

                EditPickKey {
                    icon: "add"
                    onPicked: root.setCount(root.count + 1)
                }
            }
        }

        Column {
            spacing: 9

            EditPickHead {
                title: "BAR PILLS"
                value: String(root.barCount)
            }

            Row {
                spacing: 8

                EditPickKey {
                    icon: "remove"
                    onPicked: root.setBarCount(root.barCount - 1)
                }

                EditPickKey {
                    icon: "add"
                    onPicked: root.setBarCount(root.barCount + 1)
                }
            }
        }
    }
}
