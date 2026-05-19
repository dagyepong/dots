import QtQuick
import Quickshell.Wayland
import qs.Common
import qs.Modals
import qs.Services
import qs.Widgets

HypePopout {
    id: systemUpdatePopout

    layerNamespace: "hype:system-update"

    property var parentWidget: null
    property var triggerScreen: null

    Ref {
        service: SystemUpdateService
    }

    property bool _reopenAfterUpgrade: false

    readonly property bool polkitModalOpen: polkitAuthSurfaceModal.shouldBeVisible
    readonly property bool inlineAuthActive: (PolkitService.agent?.isActive ?? false) && PolkitService.agent?.flow !== null
    readonly property bool anyModalOpen: polkitModalOpen || inlineAuthActive

    Connections {
        target: PolkitService.agent
        enabled: PolkitService.polkitAvailable && systemUpdatePopout.shouldBeVisible

        function onAuthenticationRequestStarted() {
            Qt.callLater(() => {
                const item = systemUpdatePopout.contentLoader.item;
                if (item && item.inlineAuthContent) {
                    item.inlineAuthContent.reset();
                    item.inlineAuthContent.forceActiveFocus();
                    item.inlineAuthContent.focusPasswordField();
                }
            });
        }
    }

    PolkitAuthSurfaceModal {
        id: polkitAuthSurfaceModal
        parentPopout: systemUpdatePopout
    }

    backgroundInteractive: !anyModalOpen

    customKeyboardFocus: {
        if (!shouldBeVisible)
            return WlrKeyboardFocus.None;
        if (polkitModalOpen)
            return WlrKeyboardFocus.None;
        if (CompositorService.useHyprlandFocusGrab)
            return WlrKeyboardFocus.OnDemand;
        return WlrKeyboardFocus.Exclusive;
    }

    Connections {
        target: SystemUpdateService
        function onIsUpgradingChanged() {
            const item = systemUpdatePopout.contentLoader.item;
            if (item) {
                item.upgradeStarting = false;
            }
            if (SystemUpdateService.isUpgrading)
                return;
            if (!systemUpdatePopout._reopenAfterUpgrade)
                return;
            systemUpdatePopout._reopenAfterUpgrade = false;
            systemUpdatePopout.open();
        }
    }

    popupWidth: 720
    popupHeight: 540
    triggerWidth: 55
    positioning: ""
    screen: triggerScreen
    shouldBeVisible: false
    contentHandlesKeys: true

    onBackgroundClicked: {
        if (anyModalOpen)
            return;
        close();
    }

    onShouldBeVisibleChanged: {
        if (!shouldBeVisible)
            return;
        const stale = !SystemUpdateService.lastCheckUnix || (Date.now() / 1000 - SystemUpdateService.lastCheckUnix) > 300;
        if (stale && !SystemUpdateService.isChecking && !SystemUpdateService.isUpgrading)
            SystemUpdateService.checkForUpdates();
    }

    content: Component {
        FocusScope {
            id: updaterPanel

            focus: true

            property bool upgradeStarting: false

            readonly property alias inlineAuthContent: inlineAuthLoader.item

            readonly property var hypeShellUpdate: (SystemUpdateService.availableUpdates || []).find(pkg => pkg.backend === "hypeshell" || pkg.repo === "hypeshell" || pkg.name === "HypeShell") || null
            readonly property bool hasHypeShellUpdate: hypeShellUpdate !== null
            readonly property int hypeShellUpdateCount: hasHypeShellUpdate ? 1 : 0
            readonly property var hypeShellUpdates: hasHypeShellUpdate ? [hypeShellUpdate] : []
            readonly property var generalUpdates: (SystemUpdateService.availableUpdates || []).filter(pkg => pkg.backend !== "hypeshell" && pkg.repo !== "hypeshell" && pkg.name !== "HypeShell")
            readonly property int generalUpdateCount: generalUpdates.length
            readonly property int pacmanUpdatesCount: generalUpdates.filter(pkg => pkg.backend === "pacman").length
            readonly property int paruUpdatesCount: generalUpdates.filter(pkg => pkg.backend === "paru" || pkg.backend === "yay" || pkg.repo === "aur").length
            readonly property int flatpakUpdatesCount: generalUpdates.filter(pkg => pkg.backend === "flatpak" || pkg.repo === "flatpak").length
            readonly property bool hasTerminalBackend: (SystemUpdateService.backends || []).some(b => b.runsInTerminal === true)
            readonly property bool isTerminalOperation: hasTerminalBackend || (SystemUpdateService.recentLog || []).some(line => String(line).indexOf("Running in terminal:") >= 0)
            readonly property color statusColor: SystemUpdateService.hasError ? Theme.error : (SystemUpdateService.isUpgrading ? Theme.primary : Theme.surfaceVariantText)

            function runHypeShellUpdate() {
                if (upgradeStarting || SystemUpdateService.isUpgrading)
                    return;
                upgradeStarting = true;
                const opts = {
                    includeFlatpak: false,
                    includeAUR: false,
                    targets: [hypeShellUpdate]
                };
                HYPEService.sysupdateUpgrade(opts, response => {
                    upgradeStarting = false;
                    if (response?.error) {
                        ToastService.showError(I18n.tr("Update failed to start"), response.error);
                        return;
                    }
                    SystemUpdateService.requestState();
                });
            }

            function runPacmanUpdate() {
                if (upgradeStarting || SystemUpdateService.isUpgrading)
                    return;
                upgradeStarting = true;
                const targets = generalUpdates.filter(pkg => pkg.backend === "pacman");
                const opts = {
                    includeFlatpak: false,
                    includeAUR: false,
                    targets: targets
                };
                HYPEService.sysupdateUpgrade(opts, response => {
                    upgradeStarting = false;
                    if (response?.error) {
                        ToastService.showError(I18n.tr("Update failed to start"), response.error);
                        return;
                    }
                    SystemUpdateService.requestState();
                });
            }

            function runParuUpdate() {
                if (upgradeStarting || SystemUpdateService.isUpgrading)
                    return;
                upgradeStarting = true;
                const targets = generalUpdates.filter(pkg => pkg.backend === "paru" || pkg.backend === "yay" || pkg.repo === "aur");
                const opts = {
                    includeFlatpak: false,
                    includeAUR: true,
                    targets: targets
                };
                HYPEService.sysupdateUpgrade(opts, response => {
                    upgradeStarting = false;
                    if (response?.error) {
                        ToastService.showError(I18n.tr("Update failed to start"), response.error);
                        return;
                    }
                    SystemUpdateService.requestState();
                });
            }

            function runFlatpakUpdate() {
                if (upgradeStarting || SystemUpdateService.isUpgrading)
                    return;
                upgradeStarting = true;
                const targets = generalUpdates.filter(pkg => pkg.backend === "flatpak" || pkg.repo === "flatpak");
                const opts = {
                    includeFlatpak: true,
                    includeAUR: false,
                    targets: targets
                };
                HYPEService.sysupdateUpgrade(opts, response => {
                    upgradeStarting = false;
                    if (response?.error) {
                        ToastService.showError(I18n.tr("Update failed to start"), response.error);
                        return;
                    }
                    SystemUpdateService.requestState();
                });
            }

            function runSystemUpdate() {
                if (upgradeStarting || SystemUpdateService.isUpgrading)
                    return;
                upgradeStarting = true;
                const opts = {
                    includeFlatpak: SettingsData.updaterIncludeFlatpak,
                    includeAUR: SettingsData.updaterAllowAUR,
                    targets: generalUpdates
                };
                HYPEService.sysupdateUpgrade(opts, response => {
                    upgradeStarting = false;
                    if (response?.error) {
                        ToastService.showError(I18n.tr("Update failed to start"), response.error);
                        return;
                    }
                    SystemUpdateService.requestState();
                });
            }

            function runUpdate() {
                if (upgradeStarting)
                    return;
                if (SystemUpdateService.isUpgrading) {
                    SystemUpdateService.cancelUpdates();
                    return;
                }
                if (hasHypeShellUpdate) {
                    runHypeShellUpdate();
                } else if (generalUpdateCount > 0) {
                    runSystemUpdate();
                }
            }

            function statusText() {
                switch (true) {
                case SystemUpdateService.isUpgrading:
                    return I18n.tr("Updating");
                case SystemUpdateService.isChecking:
                    return I18n.tr("Checking");
                case SystemUpdateService.hasError:
                    return I18n.tr("Error");
                default:
                    const total = hypeShellUpdateCount + generalUpdateCount;
                    if (total === 0)
                        return I18n.tr("Current");
                    return I18n.tr("%1 updates").arg(total);
                }
            }

            function terminalText() {
                const log = SystemUpdateService.recentLog || [];
                if (log.length > 0)
                    return log.join("\n");
                if (SystemUpdateService.hasError)
                    return "$ hype update\nerror: " + SystemUpdateService.errorMessage;
                if (SystemUpdateService.isChecking)
                    return "$ hype update --check\nresolving HypeShell and system update state...";
                if (hypeShellUpdateCount > 0)
                    return "$ hype update --self\nready: HypeShell " + hypeShellUpdate.fromVersion + " -> " + hypeShellUpdate.toVersion;
                if (!SystemUpdateService.helperAvailable)
                    return "$ hype update\nno supported update backend is available";
                return "$ hype update --self\nHypeShell current";
            }

            function repoLabel(pkg) {
                if (!pkg)
                    return "";
                if (pkg.repo === "hypeshell")
                    return "hype";
                return pkg.repo || "";
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    systemUpdatePopout.close();
                    event.accepted = true;
                    return;
                }
                if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && primaryMouseArea.enabled) {
                    updaterPanel.runUpdate();
                    event.accepted = true;
                }
            }

            Component.onCompleted: {
                if (systemUpdatePopout.shouldBeVisible)
                    forceActiveFocus();
            }

            Rectangle {
                anchors.fill: parent
                color: "transparent"

                Rectangle {
                    id: commandShade
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.leftMargin: Theme.spacingL
                    anchors.rightMargin: Theme.spacingL
                    anchors.topMargin: Theme.spacingL
                    height: 58
                    radius: Theme.cornerRadius
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.86)
                    border.color: Theme.withAlpha(Theme.outline, 0.16)
                    border.width: 1

                    Row {
                        anchors.left: parent.left
                        anchors.right: statusPill.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM
                        anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingM

                        HypeIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "terminal"
                            size: 24
                            color: Theme.primary
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 24 - Theme.spacingM
                            spacing: 2

                            StyledText {
                                width: parent.width
                                text: "hype update --self"
                                font.family: Theme.monoFontFamily || "monospace"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                                elide: Text.ElideRight
                            }

                            StyledText {
                                width: parent.width
                                text: {
                                    const names = (SystemUpdateService.backends || []).map(b => b.displayName).join(", ");
                                    return names.length > 0 ? names : I18n.tr("Waiting for update service");
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Rectangle {
                        id: statusPill
                        anchors.right: refreshButton.left
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(92, statusTextLabel.implicitWidth + Theme.spacingL)
                        height: 30
                        radius: 15
                        color: Theme.withAlpha(updaterPanel.statusColor, 0.16)

                        StyledText {
                            id: statusTextLabel
                            anchors.centerIn: parent
                            text: updaterPanel.statusText()
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: updaterPanel.statusColor
                        }
                    }

                    HypeActionButton {
                        id: refreshButton
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        buttonSize: 32
                        iconName: "refresh"
                        iconSize: 18
                        iconColor: Theme.surfaceText
                        enabled: !SystemUpdateService.isChecking && !SystemUpdateService.isUpgrading
                        opacity: enabled ? 1.0 : 0.5
                        onClicked: SystemUpdateService.checkForUpdates()

                        RotationAnimator on rotation {
                            from: 0
                            to: 360
                            duration: 1000
                            loops: Animation.Infinite
                            running: SystemUpdateService.isChecking

                            onRunningChanged: {
                                if (!running)
                                    refreshButton.rotation = 0;
                            }
                        }
                    }
                }

                Rectangle {
                    id: terminalShade
                    anchors.left: parent.left
                    anchors.right: packageShade.left
                    anchors.top: commandShade.bottom
                    anchors.bottom: buttonsRow.top
                    anchors.leftMargin: Theme.spacingL
                    anchors.rightMargin: Theme.spacingM
                    anchors.topMargin: Theme.spacingM
                    anchors.bottomMargin: Theme.spacingM
                    radius: Theme.cornerRadius
                    color: "#0c0f14"
                    border.color: Theme.withAlpha(Theme.primary, 0.35)
                    border.width: 1
                    clip: true

                    Rectangle {
                        id: terminalHeader
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: 34
                        color: "#111722"

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Theme.spacingM
                            spacing: 6

                            Repeater {
                                model: ["#ff5f57", "#ffbd2e", "#28c840"]

                                Rectangle {
                                    required property string modelData
                                    width: 9
                                    height: 9
                                    radius: 5
                                    color: modelData
                                }
                            }
                        }

                        StyledText {
                            anchors.centerIn: parent
                            text: SystemUpdateService.isUpgrading ? I18n.tr("update log") : I18n.tr("updates dashboard")
                            font.family: Theme.monoFontFamily || "monospace"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.withAlpha(Theme.surfaceText, 0.7)
                        }
                    }

                    HypeFlickable {
                        id: terminalScroll
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: terminalHeader.bottom
                        anchors.bottom: parent.bottom
                        anchors.margins: Theme.spacingM
                        contentWidth: width
                        contentHeight: Math.max(height, terminalLog.implicitHeight)
                        clip: true
                        visible: SystemUpdateService.isUpgrading

                        onContentHeightChanged: {
                            if (contentHeight > height)
                                contentY = contentHeight - height;
                        }

                        StyledText {
                            id: terminalLog
                            width: parent.width
                            text: updaterPanel.terminalText()
                            font.family: Theme.monoFontFamily || "monospace"
                            font.pixelSize: Theme.fontSizeSmall
                            lineHeight: 1.18
                            color: SystemUpdateService.hasError ? Theme.error : "#d6e4ff"
                            wrapMode: Text.WrapAnywhere
                        }
                    }

                    HypeFlickable {
                        id: dashboardScroll
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: terminalHeader.bottom
                        anchors.bottom: parent.bottom
                        anchors.margins: Theme.spacingM
                        contentWidth: width
                        contentHeight: dashboardColumn.implicitHeight
                        clip: true
                        visible: !SystemUpdateService.isUpgrading

                        Column {
                            id: dashboardColumn
                            width: parent.width
                            spacing: Theme.spacingM

                            // HypeShell Card
                            Rectangle {
                                width: parent.width
                                height: 130
                                radius: Theme.cornerRadius
                                color: Theme.withAlpha(Theme.primary, 0.04)
                                border.color: Theme.withAlpha(Theme.primary, 0.28)
                                border.width: 1
                                visible: updaterPanel.hasHypeShellUpdate

                                Rectangle {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    color: "transparent"
                                    border.color: Theme.primary
                                    border.width: 1
                                    opacity: 0.15
                                }

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingM
                                    spacing: Theme.spacingM

                                    Rectangle {
                                        width: 36
                                        height: 36
                                        radius: 18
                                        color: Theme.withAlpha(Theme.primary, 0.12)
                                        anchors.verticalCenter: parent.verticalCenter

                                        HypeIcon {
                                            anchors.centerIn: parent
                                            name: "system_update_alt"
                                            size: 20
                                            color: Theme.primary
                                        }
                                    }

                                    Column {
                                        width: parent.width - 36 - Theme.spacingM
                                        spacing: 4
                                        anchors.verticalCenter: parent.verticalCenter

                                        StyledText {
                                            text: I18n.tr("HypeShell Self-Update Available")
                                            font.pixelSize: Theme.fontSizeMedium
                                            font.weight: Font.SemiBold
                                            color: Theme.primary
                                        }

                                        StyledText {
                                            text: updaterPanel.hasHypeShellUpdate ? `${updaterPanel.hypeShellUpdate.fromVersion}  ➔  ${updaterPanel.hypeShellUpdate.toVersion}` : ""
                                            font.family: Theme.monoFontFamily || "monospace"
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: Font.Medium
                                            color: Theme.surfaceText
                                        }

                                        Row {
                                            spacing: Theme.spacingM

                                            Rectangle {
                                                width: 100
                                                height: 28
                                                radius: 14
                                                color: changelogMouse.containsMouse ? Theme.secondaryHover : Theme.withAlpha(Theme.surfaceVariantText, 0.1)

                                                StyledText {
                                                    anchors.centerIn: parent
                                                    text: I18n.tr("Changelog")
                                                    font.pixelSize: Theme.fontSizeSmall
                                                    font.weight: Font.Medium
                                                    color: Theme.surfaceText
                                                }

                                                MouseArea {
                                                    id: changelogMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        const url = (updaterPanel.hasHypeShellUpdate && updaterPanel.hypeShellUpdate.changelogUrl) || "https://github.com/acarlton5/HypeShell/commits/main";
                                                        Qt.openUrlExternally(url);
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Pacman Updates Card
                            Rectangle {
                                width: parent.width
                                height: 86
                                radius: Theme.cornerRadius
                                color: Theme.withAlpha(Theme.surfaceVariantText, 0.04)
                                border.color: Theme.withAlpha(Theme.outline, 0.14)
                                border.width: 1
                                visible: updaterPanel.pacmanUpdatesCount > 0

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingM
                                    spacing: Theme.spacingM

                                    Rectangle {
                                        width: 36
                                        height: 36
                                        radius: 18
                                        color: Theme.withAlpha(Theme.surfaceVariantText, 0.1)
                                        anchors.verticalCenter: parent.verticalCenter

                                        HypeIcon {
                                            anchors.centerIn: parent
                                            name: "apps"
                                            size: 20
                                            color: Theme.surfaceVariantText
                                        }
                                    }

                                    Column {
                                        width: parent.width - 36 - Theme.spacingM
                                        spacing: 2
                                        anchors.verticalCenter: parent.verticalCenter

                                        StyledText {
                                            text: I18n.tr("Pacman Updates")
                                            font.pixelSize: Theme.fontSizeMedium
                                            font.weight: Font.SemiBold
                                            color: Theme.surfaceText
                                        }

                                        StyledText {
                                            text: I18n.tr("%1 updates available").arg(updaterPanel.pacmanUpdatesCount)
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                        }
                                    }
                                }
                            }

                            // Paru (AUR) Updates Card
                            Rectangle {
                                width: parent.width
                                height: 86
                                radius: Theme.cornerRadius
                                color: Theme.withAlpha(Theme.surfaceVariantText, 0.04)
                                border.color: Theme.withAlpha(Theme.outline, 0.14)
                                border.width: 1
                                visible: updaterPanel.paruUpdatesCount > 0

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingM
                                    spacing: Theme.spacingM

                                    Rectangle {
                                        width: 36
                                        height: 36
                                        radius: 18
                                        color: Theme.withAlpha(Theme.surfaceVariantText, 0.1)
                                        anchors.verticalCenter: parent.verticalCenter

                                        HypeIcon {
                                            anchors.centerIn: parent
                                            name: "extension"
                                            size: 20
                                            color: Theme.surfaceVariantText
                                        }
                                    }

                                    Column {
                                        width: parent.width - 36 - Theme.spacingM
                                        spacing: 2
                                        anchors.verticalCenter: parent.verticalCenter

                                        StyledText {
                                            text: I18n.tr("Paru Updates (AUR)")
                                            font.pixelSize: Theme.fontSizeMedium
                                            font.weight: Font.SemiBold
                                            color: Theme.surfaceText
                                        }

                                        StyledText {
                                            text: I18n.tr("%1 updates available").arg(updaterPanel.paruUpdatesCount)
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                        }
                                    }
                                }
                            }

                            // Flatpak Updates Card
                            Rectangle {
                                width: parent.width
                                height: 86
                                radius: Theme.cornerRadius
                                color: Theme.withAlpha(Theme.surfaceVariantText, 0.04)
                                border.color: Theme.withAlpha(Theme.outline, 0.14)
                                border.width: 1
                                visible: updaterPanel.flatpakUpdatesCount > 0

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingM
                                    spacing: Theme.spacingM

                                    Rectangle {
                                        width: 36
                                        height: 36
                                        radius: 18
                                        color: Theme.withAlpha(Theme.surfaceVariantText, 0.1)
                                        anchors.verticalCenter: parent.verticalCenter

                                        HypeIcon {
                                            anchors.centerIn: parent
                                            name: "cloud_download"
                                            size: 20
                                            color: Theme.surfaceVariantText
                                        }
                                    }

                                    Column {
                                        width: parent.width - 36 - Theme.spacingM
                                        spacing: 2
                                        anchors.verticalCenter: parent.verticalCenter

                                        StyledText {
                                            text: I18n.tr("Flatpak Updates")
                                            font.pixelSize: Theme.fontSizeMedium
                                            font.weight: Font.SemiBold
                                            color: Theme.surfaceText
                                        }

                                        StyledText {
                                            text: I18n.tr("%1 updates available").arg(updaterPanel.flatpakUpdatesCount)
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                        }
                                    }
                                }
                            }

                            // Welcome / Success Card
                            Rectangle {
                                width: parent.width
                                height: 120
                                radius: Theme.cornerRadius
                                color: Theme.withAlpha(Theme.success, 0.04)
                                border.color: Theme.withAlpha(Theme.success, 0.2)
                                border.width: 1
                                visible: !updaterPanel.hasHypeShellUpdate && updaterPanel.generalUpdateCount === 0

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingM
                                    spacing: Theme.spacingM

                                    Rectangle {
                                        width: 48
                                        height: 48
                                        radius: 24
                                        color: Theme.withAlpha(Theme.success, 0.12)
                                        anchors.verticalCenter: parent.verticalCenter

                                        HypeIcon {
                                            anchors.centerIn: parent
                                            name: "check"
                                            size: 24
                                            color: Theme.success
                                        }
                                    }

                                    Column {
                                        width: parent.width - 48 - Theme.spacingM
                                        spacing: 4
                                        anchors.verticalCenter: parent.verticalCenter

                                        StyledText {
                                            text: I18n.tr("System Up To Date")
                                            font.pixelSize: Theme.fontSizeLarge
                                            font.weight: Font.SemiBold
                                            color: Theme.success
                                        }

                                        StyledText {
                                            text: I18n.tr("Everything is clean. No updates are currently pending.")
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                            wrapMode: Text.WordWrap
                                            width: parent.width
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 32
                        visible: updaterPanel.isTerminalOperation && SystemUpdateService.isUpgrading
                        color: Theme.withAlpha(Theme.primary, 0.18)

                        StyledText {
                            anchors.centerIn: parent
                            text: I18n.tr("Interactive terminal is running")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.primary
                            font.weight: Font.Medium
                        }
                    }
                }

                Rectangle {
                    id: packageShade
                    anchors.right: parent.right
                    anchors.top: commandShade.bottom
                    anchors.bottom: buttonsRow.top
                    anchors.rightMargin: Theme.spacingL
                    anchors.topMargin: Theme.spacingM
                    anchors.bottomMargin: Theme.spacingM
                    width: 230
                    radius: Theme.cornerRadius
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.72)
                    border.color: Theme.withAlpha(Theme.outline, 0.14)
                    border.width: 1

                    StyledText {
                        id: listTitle
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.spacingM
                        text: I18n.tr("Queue")
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }

                    StyledText {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: listTitle.bottom
                        anchors.bottom: parent.bottom
                        anchors.margins: Theme.spacingM
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        visible: !SystemUpdateService.isUpgrading && (updaterPanel.generalUpdateCount === 0 || SystemUpdateService.hasError || SystemUpdateService.isChecking)
                        text: {
                            switch (true) {
                            case SystemUpdateService.hasError:
                                return I18n.tr("Failed: %1").arg(SystemUpdateService.errorMessage);
                            case !SystemUpdateService.helperAvailable:
                                return I18n.tr("No update backend");
                            case SystemUpdateService.isChecking:
                                return I18n.tr("Checking...");
                            default:
                                return I18n.tr("Packages current");
                            }
                        }
                        font.pixelSize: Theme.fontSizeSmall
                        color: SystemUpdateService.hasError ? Theme.error : Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                    }

                    HypeListView {
                        id: packagesList
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: listTitle.bottom
                        anchors.bottom: parent.bottom
                        anchors.margins: Theme.spacingS
                        visible: updaterPanel.generalUpdateCount > 0 && !SystemUpdateService.hasError && !SystemUpdateService.isChecking
                        clip: true
                        spacing: Theme.spacingXS
                        model: updaterPanel.generalUpdates

                        delegate: Rectangle {
                            width: ListView.view.width
                            height: 58
                            radius: Theme.cornerRadius
                            color: packageMouseArea.containsMouse ? Theme.primaryHoverLight : "transparent"

                            required property var modelData

                            Row {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: Theme.spacingS
                                anchors.rightMargin: Theme.spacingS
                                spacing: Theme.spacingS

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 42
                                    height: 22
                                    radius: 11
                                    color: Theme.withAlpha(Theme.primary, 0.18)

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: updaterPanel.repoLabel(modelData)
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.primary
                                        elide: Text.ElideRight
                                    }
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 42 - Theme.spacingS
                                    spacing: 2

                                    StyledText {
                                        width: parent.width
                                        text: modelData.name || ""
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceText
                                        font.weight: Font.Medium
                                        elide: Text.ElideRight
                                    }

                                    StyledText {
                                        width: parent.width
                                        text: {
                                            const from = modelData.fromVersion || "";
                                            const to = modelData.toVersion || "";
                                            if (from && to)
                                                return `${from} -> ${to}`;
                                            return to || from || "";
                                        }
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            MouseArea {
                                id: packageMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: modelData.changelogUrl ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (modelData.changelogUrl)
                                        Qt.openUrlExternally(modelData.changelogUrl);
                                }
                            }
                        }
                    }
                }

                Row {
                    id: buttonsRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: Theme.spacingL
                    anchors.rightMargin: Theme.spacingL
                    anchors.bottomMargin: Theme.spacingL
                    spacing: Theme.spacingM
                    height: 44

                    Rectangle {
                        width: Math.max(210, (parent.width - Theme.spacingM) * 0.42)
                        height: parent.height
                        radius: Theme.cornerRadius
                        color: primaryMouseArea.containsMouse && primaryMouseArea.enabled ? Theme.primaryHover : Theme.withAlpha(Theme.primary, 0.14)
                        opacity: primaryMouseArea.enabled ? 1.0 : 0.5

                        Row {
                            anchors.centerIn: parent
                            spacing: Theme.spacingS

                            HypeIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: SystemUpdateService.isUpgrading ? "close" : "system_update_alt"
                                size: 18
                                color: Theme.primary
                            }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: {
                                    if (SystemUpdateService.isUpgrading)
                                        return I18n.tr("Cancel");
                                    return I18n.tr("Update All");
                                }
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.primary
                            }
                        }

                        MouseArea {
                            id: primaryMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: (SystemUpdateService.isUpgrading || updaterPanel.hypeShellUpdateCount > 0 || updaterPanel.generalUpdateCount > 0) && !updaterPanel.upgradeStarting
                            onClicked: updaterPanel.runUpdate()
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.shortDuration
                                easing.type: Theme.standardEasing
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width - parent.children[0].width - Theme.spacingM
                        height: parent.height
                        radius: Theme.cornerRadius
                        color: closeMouseArea.containsMouse ? Theme.errorPressed : Theme.secondaryHover

                        StyledText {
                            anchors.centerIn: parent
                            text: I18n.tr("Close")
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        MouseArea {
                            id: closeMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: systemUpdatePopout.close()
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.shortDuration
                                easing.type: Theme.standardEasing
                            }
                        }
                    }
                }

                Rectangle {
                    id: inlineAuthContainer
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: commandShade.bottom
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: Theme.spacingL
                    anchors.rightMargin: Theme.spacingL
                    anchors.topMargin: Theme.spacingM
                    anchors.bottomMargin: Theme.spacingL
                    radius: Theme.cornerRadius
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.96)
                    border.color: Theme.withAlpha(Theme.primary, 0.35)
                    border.width: 1
                    visible: systemUpdatePopout.inlineAuthActive
                    clip: true

                    Loader {
                        id: inlineAuthLoader
                        anchors.fill: parent
                        anchors.margins: Theme.spacingL
                        active: inlineAuthContainer.visible
                        focus: true
                        sourceComponent: PolkitAuthContent {
                            focus: true
                        }
                    }
                }


            }
        }
    }
}
