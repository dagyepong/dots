pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common

Singleton {
    id: root

    property var controlCenterPopout: null
    property var controlCenterLoader: null
    property var notificationCenterPopout: null
    property var notificationCenterLoader: null
    property var appDrawerPopout: null
    property var appDrawerLoader: null
    property var processListPopout: null
    property var processListPopoutLoader: null
    property var hypeDashPopout: null
    property var hypeDashPopoutLoader: null
    property var batteryPopout: null
    property var batteryPopoutLoader: null
    property var vpnPopout: null
    property var vpnPopoutLoader: null
    property var systemUpdatePopout: null
    property var systemUpdateLoader: null
    property var layoutPopout: null
    property var layoutPopoutLoader: null
    property var clipboardHistoryPopout: null
    property var clipboardHistoryPopoutLoader: null

    property var settingsModal: null
    property var settingsModalLoader: null
    property var clipboardHistoryModal: null
    property var hypeLauncherV2Modal: null
    property var hypeLauncherV2ModalLoader: null
    property var powerMenuModal: null
    property var processListModal: null
    property var processListModalLoader: null
    property var colorPickerModal: null
    property var notificationModal: null
    property var wifiPasswordModal: null
    property var wifiPasswordModalLoader: null
    property var wifiQRCodeModal: null
    property var wifiQRCodeModalLoader: null
    property var polkitAuthModal: null
    property var polkitAuthModalLoader: null
    property var bluetoothPairingModal: null
    property var networkInfoModal: null
    property var windowRuleModalLoader: null

    property var notepadSlideouts: []

    property string pendingThemeInstall: ""
    property string pendingPluginInstall: ""

    function setPosition(popout, x, y, width, section, screen) {
        if (popout && popout.setTriggerPosition && arguments.length >= 6) {
            popout.setTriggerPosition(x, y, width, section, screen);
        }
    }

    function openControlCenter(x, y, width, section, screen) {
        if (controlCenterPopout) {
            setPosition(controlCenterPopout, x, y, width, section, screen);
            controlCenterPopout.open();
        }
    }

    function closeControlCenter() {
        controlCenterPopout?.close();
    }

    function unloadControlCenter() {
        if (!controlCenterLoader)
            return;
        controlCenterPopout = null;
        controlCenterLoader.active = false;
    }

    function toggleControlCenter(x, y, width, section, screen) {
        if (controlCenterPopout) {
            setPosition(controlCenterPopout, x, y, width, section, screen);
            controlCenterPopout.toggle();
        }
    }

    function openNotificationCenter(x, y, width, section, screen) {
        if (notificationCenterPopout) {
            setPosition(notificationCenterPopout, x, y, width, section, screen);
            notificationCenterPopout.open();
        }
    }

    function closeNotificationCenter() {
        notificationCenterPopout?.close();
    }

    function unloadNotificationCenter() {
        if (!notificationCenterLoader)
            return;
        notificationCenterPopout = null;
        notificationCenterLoader.active = false;
    }

    function toggleNotificationCenter(x, y, width, section, screen) {
        if (notificationCenterPopout) {
            setPosition(notificationCenterPopout, x, y, width, section, screen);
            notificationCenterPopout.toggle();
        }
    }

    function openAppDrawer(x, y, width, section, screen) {
        if (appDrawerPopout) {
            setPosition(appDrawerPopout, x, y, width, section, screen);
            appDrawerPopout.open();
        }
    }

    function closeAppDrawer() {
        appDrawerPopout?.close();
    }

    function unloadAppDrawer() {
        if (!appDrawerLoader)
            return;
        appDrawerPopout = null;
        appDrawerLoader.active = false;
    }

    function toggleAppDrawer(x, y, width, section, screen) {
        if (appDrawerPopout) {
            setPosition(appDrawerPopout, x, y, width, section, screen);
            appDrawerPopout.toggle();
        }
    }

    function openProcessList(x, y, width, section, screen) {
        if (processListPopout) {
            setPosition(processListPopout, x, y, width, section, screen);
            processListPopout.open();
        }
    }

    function closeProcessList() {
        processListPopout?.close();
    }

    function unloadProcessListPopout() {
        if (!processListPopoutLoader)
            return;
        processListPopout = null;
        processListPopoutLoader.active = false;
    }

    function toggleProcessList(x, y, width, section, screen) {
        if (processListPopout) {
            setPosition(processListPopout, x, y, width, section, screen);
            processListPopout.toggle();
        }
    }

    property bool _hypeDashWantsOpen: false
    property bool _hypeDashWantsToggle: false
    property int _hypeDashPendingTab: 0
    property real _hypeDashPendingX: 0
    property real _hypeDashPendingY: 0
    property real _hypeDashPendingWidth: 0
    property string _hypeDashPendingSection: ""
    property var _hypeDashPendingScreen: null
    property bool _hypeDashHasPosition: false

    function _storeHypeDashPosition(x, y, width, section, screen, hasPos) {
        _hypeDashPendingX = x;
        _hypeDashPendingY = y;
        _hypeDashPendingWidth = width;
        _hypeDashPendingSection = section;
        _hypeDashPendingScreen = screen;
        _hypeDashHasPosition = hasPos;
    }

    function openHypeDash(tabIndex, x, y, width, section, screen) {
        _hypeDashPendingTab = tabIndex || 0;
        if (hypeDashPopout) {
            if (arguments.length >= 6)
                setPosition(hypeDashPopout, x, y, width, section, screen);
            hypeDashPopout.currentTabIndex = _hypeDashPendingTab;
            hypeDashPopout.dashVisible = true;
            return;
        }
        if (!hypeDashPopoutLoader)
            return;
        _storeHypeDashPosition(x, y, width, section, screen, arguments.length >= 6);
        _hypeDashWantsOpen = true;
        _hypeDashWantsToggle = false;
        hypeDashPopoutLoader.active = true;
    }

    function closeHypeDash() {
        if (hypeDashPopout)
            hypeDashPopout.dashVisible = false;
    }

    function unloadHypeDash() {
        // HypeDash is intentionally kept alive after first use. Destroying this
        // lazy popout during its close signal can invalidate connected overlay
        // bindings while Qt is still unwinding the signal stack.
    }

    function toggleHypeDash(tabIndex, x, y, width, section, screen) {
        _hypeDashPendingTab = tabIndex || 0;
        if (hypeDashPopout) {
            if (arguments.length >= 6)
                setPosition(hypeDashPopout, x, y, width, section, screen);
            if (hypeDashPopout.dashVisible) {
                hypeDashPopout.dashVisible = false;
            } else {
                hypeDashPopout.currentTabIndex = _hypeDashPendingTab;
                hypeDashPopout.dashVisible = true;
            }
            return;
        }
        if (!hypeDashPopoutLoader)
            return;
        _storeHypeDashPosition(x, y, width, section, screen, arguments.length >= 6);
        _hypeDashWantsToggle = true;
        _hypeDashWantsOpen = false;
        hypeDashPopoutLoader.active = true;
    }

    function _onHypeDashPopoutLoaded() {
        if (!hypeDashPopout)
            return;

        if (_hypeDashHasPosition)
            setPosition(hypeDashPopout, _hypeDashPendingX, _hypeDashPendingY, _hypeDashPendingWidth, _hypeDashPendingSection, _hypeDashPendingScreen);

        if (_hypeDashWantsOpen) {
            _hypeDashWantsOpen = false;
            hypeDashPopout.currentTabIndex = _hypeDashPendingTab;
            hypeDashPopout.dashVisible = true;
            return;
        }
        if (_hypeDashWantsToggle) {
            _hypeDashWantsToggle = false;
            if (hypeDashPopout.dashVisible) {
                hypeDashPopout.dashVisible = false;
            } else {
                hypeDashPopout.currentTabIndex = _hypeDashPendingTab;
                hypeDashPopout.dashVisible = true;
            }
        }
    }

    function openBattery(x, y, width, section, screen) {
        if (batteryPopout) {
            setPosition(batteryPopout, x, y, width, section, screen);
            batteryPopout.open();
        }
    }

    function closeBattery() {
        batteryPopout?.close();
    }

    function unloadBattery() {
        if (!batteryPopoutLoader)
            return;
        batteryPopout = null;
        batteryPopoutLoader.active = false;
    }

    function toggleBattery(x, y, width, section, screen) {
        if (batteryPopout) {
            setPosition(batteryPopout, x, y, width, section, screen);
            batteryPopout.toggle();
        }
    }

    function openVpn(x, y, width, section, screen) {
        if (vpnPopout) {
            setPosition(vpnPopout, x, y, width, section, screen);
            vpnPopout.open();
        }
    }

    function closeVpn() {
        vpnPopout?.close();
    }

    function unloadVpn() {
        if (!vpnPopoutLoader)
            return;
        vpnPopout = null;
        vpnPopoutLoader.active = false;
    }

    function toggleVpn(x, y, width, section, screen) {
        if (vpnPopout) {
            setPosition(vpnPopout, x, y, width, section, screen);
            vpnPopout.toggle();
        }
    }

    property bool _systemUpdateWantsOpen: false
    property bool _systemUpdateWantsToggle: false
    property real _systemUpdatePendingX: 0
    property real _systemUpdatePendingY: 0
    property real _systemUpdatePendingWidth: 40
    property string _systemUpdatePendingSection: "center"
    property var _systemUpdatePendingScreen: null
    property bool _systemUpdateHasPosition: false

    function _defaultSystemUpdateScreen() {
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }

    function _storeSystemUpdatePosition(x, y, width, section, screen, hasPos) {
        _systemUpdateHasPosition = hasPos;
        if (hasPos) {
            _systemUpdatePendingX = x;
            _systemUpdatePendingY = y;
            _systemUpdatePendingWidth = width;
            _systemUpdatePendingSection = section;
            _systemUpdatePendingScreen = screen;
            return;
        }

        const fallbackScreen = _defaultSystemUpdateScreen();
        _systemUpdatePendingScreen = fallbackScreen;
        _systemUpdatePendingWidth = 40;
        _systemUpdatePendingSection = "center";
        if (fallbackScreen) {
            _systemUpdatePendingX = Math.max(0, fallbackScreen.width / 2 - _systemUpdatePendingWidth / 2);
            _systemUpdatePendingY = Math.max(Theme.spacingL, Theme.barHeight + Theme.spacingM);
        } else {
            _systemUpdatePendingX = 0;
            _systemUpdatePendingY = 0;
        }
    }

    function _applySystemUpdatePosition() {
        if (!systemUpdatePopout)
            return;
        if (_systemUpdatePendingScreen) {
            systemUpdatePopout.setTriggerPosition(_systemUpdatePendingX, _systemUpdatePendingY, _systemUpdatePendingWidth, _systemUpdatePendingSection, _systemUpdatePendingScreen, SettingsData.Position.Top, Theme.barHeight - 4, 4, null);
        }
    }

    function openSystemUpdate(x, y, width, section, screen) {
        if (!systemUpdatePopout) {
            if (!systemUpdateLoader)
                return;
            _storeSystemUpdatePosition(x, y, width, section, screen, arguments.length >= 5);
            _systemUpdateWantsOpen = true;
            _systemUpdateWantsToggle = false;
            systemUpdateLoader.active = true;
            return;
        }

        if (arguments.length >= 5) {
            _storeSystemUpdatePosition(x, y, width, section, screen, true);
            _applySystemUpdatePosition();
        } else if (!systemUpdatePopout.screen) {
            _storeSystemUpdatePosition(0, 0, 40, "center", null, false);
            _applySystemUpdatePosition();
        }
        if (systemUpdatePopout) {
            systemUpdatePopout.open();
        }
    }

    function closeSystemUpdate() {
        systemUpdatePopout?.close();
    }

    function unloadSystemUpdate() {
        if (!systemUpdateLoader)
            return;
        systemUpdatePopout = null;
        systemUpdateLoader.active = false;
    }

    function toggleSystemUpdate(x, y, width, section, screen) {
        if (!systemUpdatePopout) {
            if (!systemUpdateLoader)
                return;
            _storeSystemUpdatePosition(x, y, width, section, screen, arguments.length >= 5);
            _systemUpdateWantsToggle = true;
            _systemUpdateWantsOpen = false;
            systemUpdateLoader.active = true;
            return;
        }

        if (arguments.length >= 5) {
            _storeSystemUpdatePosition(x, y, width, section, screen, true);
            _applySystemUpdatePosition();
        } else if (!systemUpdatePopout.screen) {
            _storeSystemUpdatePosition(0, 0, 40, "center", null, false);
            _applySystemUpdatePosition();
        }
        if (systemUpdatePopout) {
            systemUpdatePopout.toggle();
        }
    }

    function _onSystemUpdatePopoutLoaded() {
        if (!systemUpdatePopout)
            return;

        _applySystemUpdatePosition();

        if (_systemUpdateWantsOpen) {
            _systemUpdateWantsOpen = false;
            systemUpdatePopout.open();
            return;
        }
        if (_systemUpdateWantsToggle) {
            _systemUpdateWantsToggle = false;
            systemUpdatePopout.toggle();
        }
    }

    property bool _settingsWantsOpen: false
    property bool _settingsWantsToggle: false

    property string _settingsPendingTab: ""
    property int _settingsPendingTabIndex: -1

    function openSettings() {
        if (settingsModal) {
            settingsModal.show();
        } else if (settingsModalLoader) {
            _settingsWantsOpen = true;
            _settingsWantsToggle = false;
            settingsModalLoader.activeAsync = true;
        }
    }

    function openSettingsWithTab(tabName: string) {
        if (settingsModal) {
            settingsModal.showWithTabName(tabName);
            return;
        }
        if (settingsModalLoader) {
            _settingsPendingTab = tabName;
            _settingsWantsOpen = true;
            _settingsWantsToggle = false;
            settingsModalLoader.activeAsync = true;
        }
    }

    function openSettingsWithTabIndex(tabIndex: int) {
        if (settingsModal) {
            settingsModal.showWithTab(tabIndex);
            return;
        }
        if (settingsModalLoader) {
            _settingsPendingTabIndex = tabIndex;
            _settingsWantsOpen = true;
            _settingsWantsToggle = false;
            settingsModalLoader.activeAsync = true;
        }
    }

    function closeSettings() {
        settingsModal?.close();
    }

    function toggleSettings() {
        if (settingsModal) {
            settingsModal.toggle();
        } else if (settingsModalLoader) {
            _settingsWantsToggle = true;
            _settingsWantsOpen = false;
            settingsModalLoader.activeAsync = true;
        }
    }

    function toggleSettingsWithTab(tabName: string) {
        if (settingsModal) {
            var idx = settingsModal.resolveTabIndex(tabName);
            if (idx >= 0)
                settingsModal.currentTabIndex = idx;
            settingsModal.toggle();
            return;
        }
        if (settingsModalLoader) {
            _settingsPendingTab = tabName;
            _settingsWantsToggle = true;
            _settingsWantsOpen = false;
            settingsModalLoader.activeAsync = true;
        }
    }

    function focusOrToggleSettings() {
        if (settingsModal?.visible) {
            const settingsTitle = I18n.tr("Settings", "settings window title");
            for (const toplevel of ToplevelManager.toplevels.values) {
                if (toplevel.title !== "Settings" && toplevel.title !== settingsTitle)
                    continue;
                if (toplevel.activated) {
                    settingsModal.hide();
                    return;
                }
                toplevel.activate();
                return;
            }
        }
        openSettings();
    }

    function focusOrToggleSettingsWithTab(tabName: string) {
        if (settingsModal?.visible) {
            const settingsTitle = I18n.tr("Settings", "settings window title");
            for (const toplevel of ToplevelManager.toplevels.values) {
                if (toplevel.title !== "Settings" && toplevel.title !== settingsTitle)
                    continue;
                if (toplevel.activated) {
                    settingsModal.hide();
                    return;
                }
                var idx = settingsModal.resolveTabIndex(tabName);
                if (idx >= 0)
                    settingsModal.currentTabIndex = idx;
                toplevel.activate();
                return;
            }
        }
        openSettingsWithTab(tabName);
    }

    function unloadSettings() {
        if (settingsModalLoader) {
            settingsModal = null;
            settingsModalLoader.active = false;
        }
    }

    function _onSettingsModalLoaded() {
        if (_settingsWantsOpen) {
            _settingsWantsOpen = false;
            if (_settingsPendingTabIndex >= 0) {
                settingsModal?.showWithTab(_settingsPendingTabIndex);
                _settingsPendingTabIndex = -1;
            } else if (_settingsPendingTab) {
                settingsModal?.showWithTabName(_settingsPendingTab);
                _settingsPendingTab = "";
            } else {
                settingsModal?.show();
            }
            return;
        }
        if (_settingsWantsToggle) {
            _settingsWantsToggle = false;
            if (_settingsPendingTabIndex >= 0) {
                settingsModal.currentTabIndex = _settingsPendingTabIndex;
                _settingsPendingTabIndex = -1;
            } else if (_settingsPendingTab) {
                var idx = settingsModal?.resolveTabIndex(_settingsPendingTab) ?? -1;
                if (idx >= 0)
                    settingsModal.currentTabIndex = idx;
                _settingsPendingTab = "";
            }
            settingsModal?.toggle();
        }
    }

    function openClipboardHistory() {
        clipboardHistoryModal?.show();
    }

    function closeClipboardHistory() {
        clipboardHistoryModal?.close();
    }

    function unloadClipboardHistoryPopout() {
        if (!clipboardHistoryPopoutLoader)
            return;
        clipboardHistoryPopout = null;
        clipboardHistoryPopoutLoader.active = false;
    }

    function unloadLayoutPopout() {
        if (!layoutPopoutLoader)
            return;
        layoutPopout = null;
        layoutPopoutLoader.active = false;
    }

    property bool _hypeLauncherV2WantsOpen: false
    property bool _hypeLauncherV2WantsToggle: false
    property string _hypeLauncherV2PendingQuery: ""
    property string _hypeLauncherV2PendingMode: ""

    function openHypeLauncherV2() {
        if (hypeLauncherV2Modal) {
            hypeLauncherV2Modal.show();
        } else if (hypeLauncherV2ModalLoader) {
            _hypeLauncherV2WantsOpen = true;
            _hypeLauncherV2WantsToggle = false;
            hypeLauncherV2ModalLoader.active = true;
        }
    }

    function openHypeLauncherV2WithQuery(query: string) {
        if (hypeLauncherV2Modal) {
            hypeLauncherV2Modal.showWithQuery(query);
        } else if (hypeLauncherV2ModalLoader) {
            _hypeLauncherV2PendingQuery = query;
            _hypeLauncherV2WantsOpen = true;
            _hypeLauncherV2WantsToggle = false;
            hypeLauncherV2ModalLoader.active = true;
        }
    }

    function openHypeLauncherV2WithMode(mode: string) {
        if (hypeLauncherV2Modal) {
            hypeLauncherV2Modal.showWithMode(mode);
        } else if (hypeLauncherV2ModalLoader) {
            _hypeLauncherV2PendingMode = mode;
            _hypeLauncherV2WantsOpen = true;
            _hypeLauncherV2WantsToggle = false;
            hypeLauncherV2ModalLoader.active = true;
        }
    }

    function closeHypeLauncherV2() {
        hypeLauncherV2Modal?.hide();
    }

    function unloadHypeLauncherV2() {
        if (hypeLauncherV2ModalLoader) {
            hypeLauncherV2Modal = null;
            hypeLauncherV2ModalLoader.active = false;
        }
    }

    function toggleHypeLauncherV2() {
        if (hypeLauncherV2Modal) {
            hypeLauncherV2Modal.toggle();
        } else if (hypeLauncherV2ModalLoader) {
            _hypeLauncherV2WantsToggle = true;
            _hypeLauncherV2WantsOpen = false;
            hypeLauncherV2ModalLoader.active = true;
        }
    }

    function toggleHypeLauncherV2WithMode(mode: string) {
        if (hypeLauncherV2Modal) {
            hypeLauncherV2Modal.toggleWithMode(mode);
        } else if (hypeLauncherV2ModalLoader) {
            _hypeLauncherV2PendingMode = mode;
            _hypeLauncherV2WantsToggle = true;
            _hypeLauncherV2WantsOpen = false;
            hypeLauncherV2ModalLoader.active = true;
        }
    }

    function toggleHypeLauncherV2WithQuery(query: string) {
        if (hypeLauncherV2Modal) {
            hypeLauncherV2Modal.toggleWithQuery(query);
        } else if (hypeLauncherV2ModalLoader) {
            _hypeLauncherV2PendingQuery = query;
            _hypeLauncherV2WantsOpen = true;
            _hypeLauncherV2WantsToggle = false;
            hypeLauncherV2ModalLoader.active = true;
        }
    }

    function _onHypeLauncherV2ModalLoaded() {
        if (_hypeLauncherV2WantsOpen) {
            _hypeLauncherV2WantsOpen = false;
            if (_hypeLauncherV2PendingQuery) {
                hypeLauncherV2Modal?.showWithQuery(_hypeLauncherV2PendingQuery);
                _hypeLauncherV2PendingQuery = "";
            } else if (_hypeLauncherV2PendingMode) {
                hypeLauncherV2Modal?.showWithMode(_hypeLauncherV2PendingMode);
                _hypeLauncherV2PendingMode = "";
            } else {
                hypeLauncherV2Modal?.show();
            }
            return;
        }
        if (_hypeLauncherV2WantsToggle) {
            _hypeLauncherV2WantsToggle = false;
            if (_hypeLauncherV2PendingMode) {
                hypeLauncherV2Modal?.toggleWithMode(_hypeLauncherV2PendingMode);
                _hypeLauncherV2PendingMode = "";
            } else {
                hypeLauncherV2Modal?.toggle();
            }
        }
    }

    function openPowerMenu() {
        powerMenuModal?.openCentered();
    }

    function closePowerMenu() {
        powerMenuModal?.close();
    }

    function togglePowerMenu() {
        if (powerMenuModal) {
            if (powerMenuModal.shouldBeVisible) {
                powerMenuModal.close();
            } else {
                powerMenuModal.openCentered();
            }
        }
    }

    function showProcessListModal() {
        if (processListModal) {
            processListModal.show();
        } else if (processListModalLoader) {
            processListModalLoader.active = true;
            Qt.callLater(() => processListModal?.show());
        }
    }

    function hideProcessListModal() {
        processListModal?.hide();
    }

    function unloadProcessListModal() {
        if (processListModalLoader) {
            processListModal = null;
            processListModalLoader.active = false;
        }
    }

    function toggleProcessListModal() {
        if (processListModal) {
            processListModal.toggle();
        } else if (processListModalLoader) {
            processListModalLoader.active = true;
            Qt.callLater(() => processListModal?.show());
        }
    }

    function showColorPicker() {
        colorPickerModal?.show();
    }

    function hideColorPicker() {
        colorPickerModal?.close();
    }

    function showNotificationModal() {
        notificationModal?.show();
    }

    function hideNotificationModal() {
        notificationModal?.close();
    }

    function showWifiPasswordModal(ssid) {
        if (wifiPasswordModalLoader)
            wifiPasswordModalLoader.active = true;
        if (wifiPasswordModal)
            wifiPasswordModal.show(ssid);
    }

    function showWifiQRCodeModal(ssid) {
        if (wifiQRCodeModalLoader)
            wifiQRCodeModalLoader.active = true;
        if (wifiQRCodeModal)
            wifiQRCodeModal.show(ssid);
    }

    function showHiddenNetworkModal() {
        if (wifiPasswordModalLoader)
            wifiPasswordModalLoader.active = true;
        if (wifiPasswordModal)
            wifiPasswordModal.showHidden();
    }

    function hideWifiPasswordModal() {
        wifiPasswordModal?.hide();
    }

    function showNetworkInfoModal() {
        networkInfoModal?.show();
    }

    function hideNetworkInfoModal() {
        networkInfoModal?.close();
    }

    function openNotepad() {
        if (notepadSlideouts.length > 0) {
            notepadSlideouts[0]?.show();
        }
    }

    function closeNotepad() {
        if (notepadSlideouts.length > 0) {
            notepadSlideouts[0]?.hide();
        }
    }

    function toggleNotepad() {
        if (notepadSlideouts.length > 0) {
            notepadSlideouts[0]?.toggle();
        }
    }
}
