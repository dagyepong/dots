import QtQuick 6.10
import QtQuick.Layouts 6.10
import QtQuick.Effects
import Quickshell
import "../../Commons" as Commons
import "../../Widgets" as Widgets
import "../../Services" as Services
import "DisplayUtils.js" as DisplayUtils

Widgets.PopupWindow {
    id: popupWindow

    ipcTarget: "display"
    initialScale: 0.94
    transformOriginX: 0.5
    transformOriginY: 0.5
    closeOnClickOutside: false

    anchors {
        top: true
        left: true
    }

    margins {
        top: Quickshell.screens[0] ? (Quickshell.screens[0].height - implicitHeight) / 2 : 100
        left: Quickshell.screens[0] ? (Quickshell.screens[0].width - implicitWidth) / 2 : 100
    }

    readonly property color cSurface: Commons.Theme.background
    readonly property color cSurfaceContainer: Qt.lighter(Commons.Theme.background, 1.15)
    readonly property color cBorder: Qt.rgba(Commons.Theme.foreground.r, Commons.Theme.foreground.g, Commons.Theme.foreground.b, 0.08)

    implicitWidth: 600
    implicitHeight: 720

    Services.DisplayManagerService {
        id: displayService
    }

    Rectangle {
        id: backgroundRect
        anchors.fill: parent
        color: Commons.Theme.background
        radius: Commons.Theme.radiusPanel
        border.color: cBorder
        border.width: 1

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.35)
            shadowBlur: 1.0
            shadowVerticalOffset: 6
        }

        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16

            DisplayHeader {
                Layout.fillWidth: true
                monitorCount: displayService.monitorsList.count
                isLoading: displayService.isLoading
                onRefreshClicked: {
                    displayService.refreshMonitors();
                }
            }

            MonitorLayoutPreview {
                Layout.fillWidth: true
                Layout.preferredHeight: 160
                monitorsModel: displayService.monitorsList
                pendingChanges: displayService.pendingChanges
                visible: displayService.monitorsList.count > 0

                onPositionsChanged: function (positions) {
                    displayService.stageAllPositions(positions);
                }
            }

            Rectangle {
                id: monitorsContainer
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Commons.Theme.radius
                color: cSurfaceContainer
                clip: true

                Flickable {
                    id: monitorsFlickable
                    anchors.fill: parent
                    anchors.margins: 8
                    contentWidth: width
                    contentHeight: monitorColumn.height
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    Column {
                        id: monitorColumn
                        width: monitorsFlickable.width
                        spacing: 12

                        Repeater {
                            model: displayService.monitorsList

                            delegate: MonitorCard {
                                width: monitorsContainer.width - 16

                                pendingChanges: displayService.pendingChanges[name] || null

                                onToggleDisplay: function (monitorName, enabled) {
                                    displayService.toggleDisplay(monitorName, enabled);
                                }

                                onModeDropdownRequested: function (parentItem, modes, currentMode, monitorName) {
                                    showModePopup(parentItem, modes, currentMode, monitorName);
                                }

                                onScaleDropdownRequested: function (parentItem, monitorName, currentScale) {
                                    showScalePopup(parentItem, monitorName, currentScale);
                                }

                                onRotateDropdownRequested: function (parentItem, monitorName, currentTransform) {
                                    showRotatePopup(parentItem, monitorName, currentTransform);
                                }

                                onMirrorDropdownRequested: function (parentItem, monitorName, currentMirror) {
                                    showMirrorPopup(parentItem, monitorName, currentMirror);
                                }

                                onStopMirroringRequested: function (monitorName) {
                                    displayService.stageSetting(monitorName, "mirror", "");
                                }
                            }
                        }

                        Widgets.EmptyState {
                            width: monitorsFlickable.width
                            height: 200
                            visible: displayService.monitorsList.count === 0 && !displayService.isLoading
                            icon: "󰍹"
                            iconSize: 32
                            iconOpacity: 0.2
                            title: "No displays found"
                            subtitle: "Click refresh to reload"
                            textOpacity: 1.0
                        }
                    }
                }
            }

            ConfigPathEditor {
                Layout.fillWidth: true
                configPath: Services.ConfigService.hyprlandMonitorsConfigPath
                helpText: "Settings are saved to this file when applied. Include this file in your hyprland.conf using: source = " + Services.ConfigService.hyprlandMonitorsConfigPath.replace(/^~/, "~")
                onPathChanged: function (newPath) {
                    Services.ConfigService.setHyprlandMonitorsConfigPath(newPath);
                }
            }

            ApplyDiscardBar {
                Layout.fillWidth: true
                visible: displayService.hasUnsavedChanges
                onDiscardClicked: displayService.discardChanges()
                onApplyClicked: displayService.applyAllPendingChanges()
            }
        }

        ConfirmationDialog {
            id: confirmationDialog
            visible: false
            anchors.centerIn: backgroundRect
            z: 2000

            isPositionChange: confirmationDialog._hasOnlyPositionChanges

            pendingModeData: confirmationDialog._appliedModeData

            pendingSettings: confirmationDialog._appliedSettings

            property bool _hasOnlyPositionChanges: false
            property var _appliedModeData: null
            property var _appliedSettings: null

            Timer {
                id: countdownTimer
                interval: 1000
                repeat: true
                running: confirmationDialog.visible
                onTriggered: {
                    if (confirmationDialog.countdownSeconds > 0) {
                        confirmationDialog.countdownSeconds--;
                    } else {
                        countdownTimer.stop();
                        confirmationDialog.visible = false;
                        displayService.revertToPreviousState();
                    }
                }
            }

            onConfirmClicked: {
                countdownTimer.stop();
                confirmationDialog.visible = false;
            }

            onRevertClicked: {
                countdownTimer.stop();
                confirmationDialog.visible = false;
                displayService.revertToPreviousState();
            }
        }

        Connections {
            target: displayService
            function onChangesApplied(prevState) {
                var hasPositionChange = false;
                var hasNonPositionChange = false;
                var appliedModeData = null;
                var appliedSettings = {};

                for (var monitorName in prevState) {
                    var prev = prevState[monitorName];

                    for (var i = 0; i < displayService.monitorsList.count; i++) {
                        var monitor = displayService.monitorsList.get(i);
                        if (monitor.name === monitorName) {
                            if (prev.positionX !== monitor.positionX || prev.positionY !== monitor.positionY) {
                                hasPositionChange = true;
                            }

                            if (prev.mode !== monitor.currentMode) {
                                var match = monitor.currentMode.match(/(\d+)x(\d+)@([\d.]+)Hz/);
                                if (match && !appliedModeData) {
                                    appliedModeData = {
                                        formatted: monitor.currentMode,
                                        width: parseInt(match[1]),
                                        height: parseInt(match[2]),
                                        refresh: parseFloat(match[3])
                                    };
                                }
                                hasNonPositionChange = true;
                            }

                            if (prev.scale !== monitor.monitorScale) {
                                appliedSettings.scale = monitor.monitorScale;
                                hasNonPositionChange = true;
                            }
                            if (prev.transform !== monitor.monitorTransform) {
                                appliedSettings.transform = monitor.monitorTransform;
                                hasNonPositionChange = true;
                            }
                            if (prev.mirror !== monitor.mirrorTarget) {
                                if (monitor.mirrorTarget && monitor.mirrorTarget !== "") {
                                    appliedSettings.mirror = monitor.mirrorTarget;
                                    hasNonPositionChange = true;
                                }
                            }
                            break;
                        }
                    }
                }

                confirmationDialog._hasOnlyPositionChanges = hasPositionChange && !hasNonPositionChange;
                confirmationDialog._appliedModeData = appliedModeData;
                confirmationDialog._appliedSettings = Object.keys(appliedSettings).length > 0 ? appliedSettings : null;

                confirmationDialog.countdownSeconds = 10;

                confirmationDialog.visible = true;
            }
        }

        MouseArea {
            id: dropdownOverlay
            anchors.fill: parent
            z: 999
            visible: (modeSelectPopup.visible || scaleSelectPopup.visible || rotateSelectPopup.visible || mirrorSelectPopup.visible) && !confirmationDialog.visible
            hoverEnabled: true
            onPressed: function (mouse) {
                mouse.accepted = true;
                backgroundRect.closeAllDropdowns();
            }
        }

        function closeAllDropdowns() {
            modeSelectPopup.hide();
            scaleSelectPopup.hide();
            rotateSelectPopup.hide();
            mirrorSelectPopup.hide();
        }

        SelectListPopup {
            id: modeSelectPopup
            popupWidth: 300
            itemHeight: 40
            maxListHeight: 400
            onItemSelected: function (value) { displayService.stageMode(modeSelectPopup.contextMonitor, value); }
        }

        SelectListPopup {
            id: scaleSelectPopup
            popupWidth: 200
            onItemSelected: function (value) { displayService.stageSetting(scaleSelectPopup.contextMonitor, "scale", value); }
        }

        SelectListPopup {
            id: rotateSelectPopup
            popupWidth: 200
            onItemSelected: function (value) { displayService.stageSetting(rotateSelectPopup.contextMonitor, "transform", value); }
        }

        SelectListPopup {
            id: mirrorSelectPopup
            popupWidth: 250
            onItemSelected: function (value) { displayService.stageSetting(mirrorSelectPopup.contextMonitor, "mirror", value); }
        }

        Connections {
            target: popupWindow
            function onShouldShowChanged() {
                if (popupWindow.shouldShow) {
                    displayService.discardChanges();
                    displayService.refreshMonitors();
                } else {
                    displayService.discardChanges();
                }
            }
        }
    }

    function showModePopup(parentItem, modes, currentMode, monitorName) {
        backgroundRect.closeAllDropdowns();
        var arr = [];
        for (var i = 0; i < modes.length; i++) {
            arr.push({ value: modes[i], text: modes[i].formatted });
        }
        modeSelectPopup.model = arr;
        modeSelectPopup.contextMonitor = monitorName;
        modeSelectPopup.open(parentItem, backgroundRect);
    }

    function showScalePopup(parentItem, monitorName, currentScale) {
        backgroundRect.closeAllDropdowns();
        var arr = [];
        for (var i = 0; i < DisplayUtils.SCALE_OPTIONS.length; i++) {
            var s = DisplayUtils.SCALE_OPTIONS[i];
            arr.push({ value: s, text: s.toFixed(2) + "x" });
        }
        scaleSelectPopup.model = arr;
        scaleSelectPopup.contextMonitor = monitorName;
        scaleSelectPopup.open(parentItem, backgroundRect);
    }

    function showRotatePopup(parentItem, monitorName, currentTransform) {
        backgroundRect.closeAllDropdowns();
        rotateSelectPopup.model = DisplayUtils.ROTATE_OPTIONS;
        rotateSelectPopup.contextMonitor = monitorName;
        rotateSelectPopup.open(parentItem, backgroundRect);
    }

    function showMirrorPopup(parentItem, monitorName, currentMirror) {
        backgroundRect.closeAllDropdowns();
        var arr = [{ value: "", text: "None" }];
        for (var i = 0; i < displayService.monitorsList.count; i++) {
            var m = displayService.monitorsList.get(i);
            if (m.name !== monitorName) arr.push({ value: m.name, text: m.name });
        }
        mirrorSelectPopup.model = arr;
        mirrorSelectPopup.contextMonitor = monitorName;
        mirrorSelectPopup.open(parentItem, backgroundRect);
    }
}
