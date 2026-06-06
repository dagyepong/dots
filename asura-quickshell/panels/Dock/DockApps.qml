import QtQuick
import Quickshell
import Quickshell.Widgets
import "../../core"
import "../../core/functions" as Functions
import "../../services"
import "../../widgets"

Item {
    id: root

    property real buttonPadding: 5 * Appearance.effectiveScale
    property real spacing: 7 * Appearance.effectiveScale
    property int backgroundStyle: 1
    property int orientation: ListView.Vertical
    property real availableHeight: 620 * Appearance.effectiveScale

    property Item lastHoveredButton
    property var lastHoveredAppData
    property bool buttonHovered: false

    readonly property bool searchActive: false
    readonly property real u: Appearance.effectiveScale
    readonly property real iconButtonSize: 38 * u
    readonly property real pillWidth: 52 * u
    readonly property real desiredHeight: 24 * u + iconButtonSize + Math.max(0, dockItems.length) * (iconButtonSize + spacing)
    readonly property var dockItems: {
        TaskbarApps.apps;
        return TaskbarApps.apps.slice(0, 48);
    }

    signal requestContextMenu(var appData, real x, real y)
    signal buttonHoverChanged(Item button, var appData, bool hovered)

    implicitWidth: pillWidth + 8 * u
    implicitHeight: Math.min(Math.max(74 * u, desiredHeight), Math.max(180 * u, availableHeight))

    function desktopEntry(appId) {
        return TaskbarApps.getDesktopEntry(appId) || DesktopEntries.byId(appId) || DesktopEntries.heuristicLookup(appId);
    }

    function iconName(appData) {
        const entry = appData ? desktopEntry(appData.appId) : null;
        return (entry && entry.icon) ? entry.icon : AppSearch.guessIcon(appData ? appData.appId : "");
    }

    function activateApp(appData) {
        if (!appData) return;

        if (appData.toplevels && appData.toplevels.length > 0) {
            let target = null;
            for (const top of appData.toplevels) {
                if (top && !top.activated) {
                    target = top;
                    break;
                }
            }
            if (!target) target = appData.toplevels[appData.toplevels.length - 1];
            if (target && target.activate) target.activate();
            return;
        }

        const entry = desktopEntry(appData.appId);
        if (entry && entry.execute) entry.execute();
    }

    function launchNew(appData) {
        if (!appData) return;
        const entry = desktopEntry(appData.appId);
        if (entry && entry.execute) entry.execute();
    }

    Rectangle {
        id: dockPill
        anchors.centerIn: parent
        width: root.pillWidth
        height: parent.implicitHeight
        radius: width / 2
        color: Functions.ColorUtils.applyAlpha("#080d10", 0.94)
        border.width: Math.max(1, 1.2 * root.u)
        border.color: Functions.ColorUtils.applyAlpha("#8dfcff", 0.52)
        antialiasing: true

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1 * root.u
            radius: parent.radius - 1 * root.u
            color: Functions.ColorUtils.applyAlpha("#ffffff", 0.035)
            antialiasing: true
        }

        Column {
            anchors.fill: parent
            anchors.margins: 7 * root.u
            spacing: root.spacing

            Item {
                id: launcherButton
                width: root.iconButtonSize
                height: root.iconButtonSize
                visible: Config.ready && Config.options.dock
                    ? (Config.options.dock.showLauncher !== undefined ? Config.options.dock.showLauncher : true)
                    : true
                scale: launcherMouse.pressed ? 0.96 : 1

                Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: GlobalStates.launcherOpen
                        ? Functions.ColorUtils.applyAlpha("#44f0f3", 0.28)
                        : Functions.ColorUtils.applyAlpha("#ffffff", launcherMouse.containsMouse ? 0.13 : 0.06)
                    border.width: Math.max(1, 1.2 * root.u)
                    border.color: Functions.ColorUtils.applyAlpha(GlobalStates.launcherOpen ? "#44f0f3" : "#ff79cf", GlobalStates.launcherOpen ? 0.92 : 0.42)
                    antialiasing: true
                }

                StyledText {
                    anchors.centerIn: parent
                    text: ":3"
                    color: "#f8fbff"
                    font.pixelSize: 13 * root.u
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    id: launcherMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onEntered: {
                        root.lastHoveredButton = launcherButton;
                        root.buttonHovered = true;
                    }
                    onExited: {
                        if (root.lastHoveredButton === launcherButton) root.buttonHovered = false;
                    }
                    onClicked: event => {
                        if (event.button === Qt.RightButton) {
                            const pos = launcherButton.mapToItem(null, event.x, event.y);
                            root.requestContextMenu(null, pos.x, pos.y);
                        } else {
                            GlobalStates.launcherOpen = !GlobalStates.launcherOpen;
                        }
                    }
                }
            }

            ListView {
                id: appList
                width: root.iconButtonSize
                height: Math.max(0, dockPill.height - launcherButton.height - parent.spacing - 14 * root.u)
                model: root.dockItems
                spacing: root.spacing
                clip: true
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick

                delegate: Item {
                    id: appButton
                    required property var modelData
                    required property int index

                    readonly property bool isActive: modelData && modelData.toplevels ? modelData.toplevels.some(t => t.activated) : false
                    readonly property bool isRunning: modelData && modelData.toplevels && modelData.toplevels.length > 0
                    readonly property int notifCount: modelData ? Notifications.getCountForApp(modelData.appId) : 0

                    width: root.iconButtonSize
                    height: root.iconButtonSize
                    scale: iconMouse.pressed ? 0.96 : 1

                    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: appButton.isActive
                            ? Functions.ColorUtils.applyAlpha("#44f0f3", 0.26)
                            : Functions.ColorUtils.applyAlpha("#ffffff", iconMouse.containsMouse ? 0.13 : 0.055)
                        border.width: Math.max(1, 1.1 * root.u)
                        border.color: appButton.isActive
                            ? Functions.ColorUtils.applyAlpha("#44f0f3", 0.92)
                            : Functions.ColorUtils.applyAlpha("#ffffff", iconMouse.containsMouse ? 0.24 : 0.12)
                        antialiasing: true
                    }

                    IconImage {
                        anchors.centerIn: parent
                        width: 22 * root.u
                        height: 22 * root.u
                        source: Quickshell.iconPath(root.iconName(modelData) || "application-x-executable", "application-x-executable")
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: -1 * root.u
                        spacing: 2 * root.u
                        visible: appButton.isRunning

                        Repeater {
                            model: appButton.modelData && appButton.modelData.toplevels ? Math.min(appButton.modelData.toplevels.length, 3) : 0
                            delegate: Rectangle {
                                width: appButton.modelData.toplevels.length === 1 ? 10 * root.u : 4 * root.u
                                height: 3 * root.u
                                radius: height / 2
                                color: appButton.isActive ? "#44f0f3" : Functions.ColorUtils.applyAlpha("#f8fbff", 0.72)
                            }
                        }
                    }

                    Rectangle {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: -3 * root.u
                        anchors.rightMargin: -3 * root.u
                        width: 13 * root.u
                        height: width
                        radius: width / 2
                        color: "#ff6f91"
                        visible: appButton.notifCount > 0

                        StyledText {
                            anchors.centerIn: parent
                            text: appButton.notifCount > 9 ? "!" : appButton.notifCount
                            color: "white"
                            font.pixelSize: 8 * root.u
                            font.weight: Font.DemiBold
                        }
                    }

                    MouseArea {
                        id: iconMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onEntered: {
                            root.lastHoveredButton = appButton;
                            root.lastHoveredAppData = modelData;
                            root.buttonHovered = true;
                            root.buttonHoverChanged(appButton, modelData, true);
                        }
                        onExited: {
                            if (root.lastHoveredButton === appButton) {
                                root.buttonHovered = false;
                            }
                            root.buttonHoverChanged(appButton, modelData, false);
                        }
                        onClicked: event => {
                            if (event.button === Qt.RightButton) {
                                const pos = appButton.mapToItem(null, event.x, event.y);
                                root.requestContextMenu(modelData, pos.x, pos.y);
                            } else if (event.button === Qt.MiddleButton) {
                                root.launchNew(modelData);
                            } else {
                                root.activateApp(modelData);
                            }
                        }
                    }
                }
            }
        }
    }
}
