import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property var greeterRoot: parent ? parent.greeterRoot : null

    readonly property real headerIconContainerSize: Math.round(Theme.iconSize * 2)
    readonly property real sectionIconSize: Theme.iconSizeSmall + 2
    readonly property real keybindRowHeight: Math.round(Theme.fontSizeMedium * 2)
    readonly property real keyBadgeHeight: Math.round(Theme.fontSizeSmall * 1.83)

    readonly property var featureNames: ({
            "spotlight": "App Launcher",
            "clipboard": "Clipboard",
            "processlist": "Task Manager",
            "settings": "Settings",
            "notifications": "Notifications",
            "notepad": "Notepad",
            "hotkeys": "Keybinds",
            "lock": "Lock Screen",
            "hypedash": "Dashboard"
        })

    function getFeatureDesc(action) {
        const match = action.match(/hype\s+ipc\s+call\s+(\w+)/);
        if (match && featureNames[match[1]])
            return featureNames[match[1]];
        return null;
    }

    readonly property var hypeKeybinds: {
        if (!greeterRoot || !greeterRoot.cheatsheetLoaded || !greeterRoot.cheatsheetData || !greeterRoot.cheatsheetData.binds)
            return [];
        const seen = new Set();
        const binds = [];
        const allBinds = greeterRoot.cheatsheetData.binds;
        for (const category in allBinds) {
            const categoryBinds = allBinds[category];
            for (let i = 0; i < categoryBinds.length; i++) {
                const bind = categoryBinds[i];
                if (!bind.key || !bind.action)
                    continue;
                if (!bind.action.includes("hype"))
                    continue;
                if (!(bind.action.includes("spawn") || bind.action.includes("exec")))
                    continue;
                const feature = getFeatureDesc(bind.action);
                if (!feature)
                    continue;
                if (seen.has(feature))
                    continue;
                seen.add(feature);
                binds.push({
                    key: bind.key,
                    desc: feature
                });
            }
        }
        return binds;
    }

    readonly property bool hasKeybinds: hypeKeybinds.length > 0

    HypeFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: mainColumn.height + Theme.spacingL * 2
        contentWidth: width

        Column {
            id: mainColumn
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(640, parent.width - Theme.spacingXL * 2)
            topPadding: Theme.spacingL
            spacing: Theme.spacingL

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.spacingM

                Rectangle {
                    width: root.headerIconContainerSize
                    height: root.headerIconContainerSize
                    radius: Math.round(root.headerIconContainerSize * 0.29)
                    color: Theme.withAlpha(Theme.success, 0.15)
                    anchors.verticalCenter: parent.verticalCenter

                    HypeIcon {
                        anchors.centerIn: parent
                        name: "check_circle"
                        size: Theme.iconSize + 4
                        color: Theme.success
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    StyledText {
                        text: I18n.tr("You're All Set!", "greeter completion page title")
                        font.pixelSize: Theme.fontSizeXLarge
                        font.weight: Font.Bold
                        color: Theme.surfaceText
                    }

                    StyledText {
                        text: I18n.tr("HypeShell is ready to use", "greeter completion page subtitle")
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceVariantText
                    }
                }
            }

            Column {
                width: parent.width
                spacing: Theme.spacingS
                visible: root.hasKeybinds

                Row {
                    width: parent.width
                    spacing: Theme.spacingS

                    HypeIcon {
                        name: "keyboard"
                        size: root.sectionIconSize
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: I18n.tr("HypeShell Shortcuts", "greeter keybinds section header")
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Rectangle {
                    id: keybindsRect
                    width: parent.width
                    height: keybindsGrid.height + Theme.spacingM * 2
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHigh

                    readonly property bool useTwoColumns: width > 500
                    readonly property int columnCount: useTwoColumns ? 2 : 1
                    readonly property real itemWidth: useTwoColumns ? (width - Theme.spacingM * 3) / 2 : width - Theme.spacingM * 2
                    property real maxKeyWidth: 0

                    Grid {
                        id: keybindsGrid
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.spacingM
                        columns: keybindsRect.columnCount
                        rowSpacing: Theme.spacingS
                        columnSpacing: Theme.spacingM

                        Repeater {
                            model: root.hypeKeybinds

                            Row {
                                width: keybindsRect.itemWidth
                                height: root.keybindRowHeight
                                spacing: Theme.spacingS

                                Item {
                                    width: keybindsRect.maxKeyWidth
                                    height: parent.height

                                    Row {
                                        id: keysRow
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: Theme.spacingXS

                                        property real naturalWidth: {
                                            let w = 0;
                                            for (let i = 0; i < children.length; i++) {
                                                if (children[i].visible)
                                                    w += children[i].width + (i > 0 ? Theme.spacingXS : 0);
                                            }
                                            return w;
                                        }

                                        Component.onCompleted: {
                                            Qt.callLater(() => {
                                                if (naturalWidth > keybindsRect.maxKeyWidth)
                                                    keybindsRect.maxKeyWidth = naturalWidth;
                                            });
                                        }

                                        Repeater {
                                            model: (modelData.key || "").split("+")

                                            Rectangle {
                                                width: singleKeyText.implicitWidth + Theme.spacingM
                                                height: root.keyBadgeHeight
                                                radius: Theme.spacingXS
                                                color: Theme.surfaceContainerHighest
                                                border.width: 1
                                                border.color: Theme.outline

                                                StyledText {
                                                    id: singleKeyText
                                                    anchors.centerIn: parent
                                                    color: Theme.secondary
                                                    text: modelData
                                                    font.pixelSize: Theme.fontSizeSmall - 1
                                                    font.weight: Font.Medium
                                                    isMonospace: true
                                                }
                                            }
                                        }
                                    }
                                }

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - keybindsRect.maxKeyWidth - Theme.spacingS
                                    text: modelData.desc || ""
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceText
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: noKeybindsColumn.height + Theme.spacingM * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                visible: !root.hasKeybinds

                Column {
                    id: noKeybindsColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacingM
                    spacing: Theme.spacingS

                    Row {
                        spacing: Theme.spacingS

                        HypeIcon {
                            name: "keyboard"
                            size: root.sectionIconSize
                            color: Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("No HypeShell shortcuts configured", "greeter no keybinds message")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: Math.round(Theme.fontSizeMedium * 2.85)
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHighest

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Theme.primary
                            opacity: noKeybindsLinkMouse.containsMouse ? 0.12 : 0
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: Theme.spacingS

                            HypeIcon {
                                name: "menu_book"
                                size: root.sectionIconSize
                                color: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: I18n.tr("Configure Keybinds", "greeter configure keybinds link")
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            HypeIcon {
                                name: "open_in_new"
                                size: Theme.iconSizeSmall - 2
                                color: Theme.surfaceVariantText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: noKeybindsLinkMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                let url = "https://github.com/acarlton5/HypeShell";
                                if (CompositorService.isNiri)
                                    url = "https://github.com/acarlton5/HypeShell";
                                else if (CompositorService.isHyprland)
                                    url = "https://github.com/acarlton5/HypeShell";
                                else if (CompositorService.isDwl)
                                    url = "https://github.com/acarlton5/HypeShell";
                                Qt.openUrlExternally(url);
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.outlineMedium
                opacity: 0.3
                visible: root.hasKeybinds
            }

            Column {
                width: parent.width
                spacing: Theme.spacingS

                Row {
                    width: parent.width
                    spacing: Theme.spacingS

                    HypeIcon {
                        name: "settings"
                        size: root.sectionIconSize
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: I18n.tr("Configure", "greeter settings section header")
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Grid {
                    width: parent.width
                    columns: 2
                    rowSpacing: Theme.spacingS
                    columnSpacing: Theme.spacingS

                    GreeterSettingsCard {
                        width: (parent.width - Theme.spacingS) / 2
                        iconName: "display_settings"
                        title: I18n.tr("Displays", "greeter settings link")
                        description: I18n.tr("Resolution, position, scale", "greeter displays description")
                        onClicked: PopoutService.openSettingsWithTab("display_config")
                    }

                    GreeterSettingsCard {
                        width: (parent.width - Theme.spacingS) / 2
                        iconName: "wallpaper"
                        title: I18n.tr("Wallpaper", "greeter settings link")
                        description: I18n.tr("Background image", "greeter wallpaper description")
                        onClicked: PopoutService.openSettingsWithTab("wallpaper")
                    }

                    GreeterSettingsCard {
                        width: (parent.width - Theme.spacingS) / 2
                        iconName: "format_paint"
                        title: I18n.tr("Theme & Colors", "greeter settings link")
                        description: I18n.tr("Dynamic colors, presets", "greeter theme description")
                        onClicked: PopoutService.openSettingsWithTab("theme")
                    }

                    GreeterSettingsCard {
                        width: (parent.width - Theme.spacingS) / 2
                        iconName: "notifications"
                        title: I18n.tr("Notifications", "greeter settings link")
                        description: I18n.tr("Popup behavior, position", "greeter notifications description")
                        onClicked: PopoutService.openSettingsWithTab("notifications")
                    }

                    GreeterSettingsCard {
                        width: (parent.width - Theme.spacingS) / 2
                        iconName: "toolbar"
                        title: I18n.tr("Hype Bar", "greeter settings link")
                        description: I18n.tr("Widgets, layout, style", "greeter hypebar description")
                        onClicked: PopoutService.openSettingsWithTab("hypebar_settings")
                    }

                    GreeterSettingsCard {
                        width: (parent.width - Theme.spacingS) / 2
                        iconName: "keyboard"
                        title: I18n.tr("Keybinds", "greeter settings link")
                        description: I18n.tr("niri shortcuts config", "greeter keybinds niri description")
                        visible: KeybindsService.available
                        onClicked: PopoutService.openSettingsWithTab("keybinds")
                    }

                    GreeterSettingsCard {
                        width: (parent.width - Theme.spacingS) / 2
                        iconName: "dock_to_bottom"
                        title: I18n.tr("Dock", "greeter settings link")
                        description: I18n.tr("Position, pinned apps", "greeter dock description")
                        visible: !KeybindsService.available
                        onClicked: PopoutService.openSettingsWithTab("dock")
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.outlineMedium
                opacity: 0.3
            }

            Column {
                width: parent.width
                spacing: Theme.spacingS

                Row {
                    width: parent.width
                    spacing: Theme.spacingS

                    HypeIcon {
                        name: "explore"
                        size: root.sectionIconSize
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: I18n.tr("Explore", "greeter explore section header")
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingS

                    GreeterQuickLink {
                        width: (parent.width - Theme.spacingS * 2) / 3
                        iconName: "menu_book"
                        title: I18n.tr("Docs", "greeter documentation link")
                        isExternal: true
                        onClicked: Qt.openUrlExternally("https://github.com/acarlton5/HypeShell")
                    }

                    GreeterQuickLink {
                        width: (parent.width - Theme.spacingS * 2) / 3
                        iconName: "extension"
                        title: I18n.tr("Plugins", "greeter plugins link")
                        isExternal: true
                        onClicked: Qt.openUrlExternally("https://github.com/acarlton5/HypeRegistry/tree/master/plugins")
                    }

                    GreeterQuickLink {
                        width: (parent.width - Theme.spacingS * 2) / 3
                        iconName: "palette"
                        title: I18n.tr("Themes", "greeter themes link")
                        isExternal: true
                        onClicked: Qt.openUrlExternally("https://github.com/acarlton5/HypeRegistry/tree/master/themes")
                    }
                }
            }
        }
    }
}
