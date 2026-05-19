import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: aboutTab

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    readonly property var availableUpdates: SystemUpdateService.availableUpdates || []
    readonly property var hypeShellUpdate: availableUpdates.find(pkg => pkg.backend === "hypeshell" || pkg.repo === "hypeshell" || pkg.name === "HypeShell") || null
    readonly property bool hasHypeShellUpdate: hypeShellUpdate !== null
    readonly property int pacmanUpdatesCount: availableUpdates.filter(pkg => pkg.backend === "pacman").length
    readonly property int paruUpdatesCount: availableUpdates.filter(pkg => pkg.backend === "paru" || pkg.backend === "yay" || pkg.repo === "aur").length
    readonly property int flatpakUpdatesCount: availableUpdates.filter(pkg => pkg.backend === "flatpak" || pkg.repo === "flatpak").length
    readonly property int totalSystemUpdates: pacmanUpdatesCount + paruUpdatesCount + flatpakUpdatesCount

    function triggerCheck() {
        SystemUpdateService.checkForUpdates();
        ShellVersionService.checkForUpdates();
    }

    property bool isHyprland: CompositorService.isHyprland
    property bool isNiri: CompositorService.isNiri
    property bool isSway: CompositorService.isSway
    property bool isScroll: CompositorService.isScroll
    property bool isMiracle: CompositorService.isMiracle
    property bool isDwl: CompositorService.isDwl
    property bool isLabwc: CompositorService.isLabwc

    property string compositorName: {
        if (isHyprland)
            return "hyprland";
        if (isSway)
            return "sway";
        if (isScroll)
            return "scroll";
        if (isMiracle)
            return "miracle";
        if (isDwl)
            return "mangowc";
        if (isLabwc)
            return "labwc";
        return "niri";
    }

    property string compositorLogo: {
        if (isHyprland)
            return "/assets/hyprland.svg";
        if (isSway)
            return "/assets/sway.svg";
        if (isScroll)
            return "/assets/sway.svg";
        if (isMiracle)
            return "/assets/miraclewm.svg";
        if (isDwl)
            return "/assets/mango.png";
        if (isLabwc)
            return "/assets/labwc.png";
        return "/assets/niri.svg";
    }

    property string compositorUrl: {
        if (isHyprland)
            return "https://hypr.land";
        if (isSway)
            return "https://swaywm.org";
        if (isScroll)
            return "https://github.com/dawsers/scroll";
        if (isMiracle)
            return "https://github.com/miracle-wm-org/miracle-wm";
        if (isDwl)
            return "https://github.com/DreamMaoMao/mangowc";
        if (isLabwc)
            return "https://labwc.github.io/";
        return "https://github.com/niri-wm/niri";
    }

    property string compositorTooltip: {
        if (isHyprland)
            return I18n.tr("Hyprland Website");
        if (isSway)
            return I18n.tr("Sway Website");
        if (isScroll)
            return I18n.tr("Scroll GitHub");
        if (isMiracle)
            return I18n.tr("Scroll GitHub");
        if (isDwl)
            return I18n.tr("mangowc GitHub");
        if (isLabwc)
            return I18n.tr("LabWC Website");
        return I18n.tr("niri GitHub");
    }

    property string hypeDiscordUrl: "https://github.com/acarlton5/HypeShell"
    property string hypeDiscordTooltip: I18n.tr("HypeShell GitHub")

    property string compositorDiscordUrl: {
        if (isHyprland)
            return "https://discord.com/invite/hQ9XvMUjjr";
        if (isDwl)
            return "https://discord.gg/CPjbDxesh5";
        return "";
    }

    property string compositorDiscordTooltip: {
        if (isHyprland)
            return I18n.tr("Hyprland Discord Server");
        if (isDwl)
            return I18n.tr("mangowc Discord Server");
        return "";
    }

    property string redditUrl: "https://reddit.com/r/niri"
    property string redditTooltip: I18n.tr("r/niri Subreddit")

    property string ircUrl: "https://web.libera.chat/gamja/?channels=#labwc"
    property string ircTooltip: I18n.tr("LabWC IRC Channel")

    property bool showMatrix: isNiri && !isHyprland && !isSway && !isScroll && !isMiracle && !isDwl && !isLabwc
    property bool showCompositorDiscord: false
    property bool showReddit: isNiri && !isHyprland && !isSway && !isScroll && !isMiracle && !isDwl && !isLabwc
    property bool showIrc: isLabwc

    function displayVersion() {
        if (ShellVersionService.installedCommit)
            return "HypeShell " + ShellVersionService.installedCommit;
        if (ShellVersionService.shellVersion)
            return "HypeShell " + ShellVersionService.shellVersion.replace(/^hype\s*/i, "").replace(/^hype\s*/i, "");
        if (HYPEService.cliVersion)
            return "HypeShell " + HYPEService.cliVersion;
        return "HypeShell source build";
    }

    function updateStatusText() {
        switch (ShellVersionService.updateStatus) {
        case "checking":
            return I18n.tr("Checking for updates...");
        case "current":
            return I18n.tr("HypeShell is up to date");
        case "available":
            return I18n.tr("Update available");
        case "error":
            return ShellVersionService.updateError || I18n.tr("Could not check for updates");
        default:
            return I18n.tr("Update status has not been checked");
        }
    }

    function updateStatusColor() {
        switch (ShellVersionService.updateStatus) {
        case "current":
            return Theme.success;
        case "available":
            return Theme.warning;
        case "error":
            return Theme.error;
        default:
            return Theme.surfaceVariantText;
        }
    }

    function terminalLaunchArgs(terminal, title, shellCmd) {
        const appId = "hypeshell-update";
        const full = `export SUDO_PROMPT="[HypeShell] sudo password for %u: "; printf '\\033[1;36m=== ${title} ===\\033[0m\\n'; printf '\\033[2m$ ${shellCmd}\\033[0m\\n\\n'; ${shellCmd}; status=$?; printf '\\n\\033[1;32m=== Update finished. Press Enter to close. ===\\033[0m\\n'; read _; exit $status`;
        switch (terminal) {
        case "kitty":
            return [terminal, "--class", appId, "-T", title, "-e", "sh", "-c", full];
        case "alacritty":
            return [terminal, "--class", appId, "-T", title, "-e", "sh", "-c", full];
        case "foot":
            return [terminal, "--app-id=" + appId, "--title=" + title, "-e", "sh", "-c", full];
        case "ghostty":
            return [terminal, "--class=" + appId, "--title=" + title, "-e", "sh", "-c", full];
        case "wezterm":
            return [terminal, "--class", appId, "-T", title, "-e", "sh", "-c", full];
        case "konsole":
            return [terminal, "-p", "tabtitle=" + title, "-e", "sh", "-c", full];
        case "gnome-terminal":
            return [terminal, "--title=" + title, "--", "sh", "-c", full];
        case "xterm":
            return [terminal, "-class", appId, "-T", title, "-e", "sh", "-c", full];
        default:
            return [terminal, "-e", "sh", "-c", full];
        }
    }

    function runHypeUpdate() {
        if (SystemUpdateService.sysupdateAvailable && HYPEService.isConnected) {
            PopoutService.openSystemUpdate();
            HYPEService.sysupdateRefresh(true, refreshResponse => {
                if (refreshResponse.error) {
                    ToastService.showError(I18n.tr("Update check failed"), refreshResponse.error);
                    return;
                }
                const packages = refreshResponse.result?.packages || [];
                const target = packages.find(pkg => pkg.backend === "hypeshell" || pkg.repo === "hypeshell" || pkg.name === "HypeShell");
                SystemUpdateService.requestState();
                if (!target) {
                    ShellVersionService.checkForUpdates();
                    ToastService.showInfo(I18n.tr("HypeShell is up to date"), I18n.tr("No HypeShell update is currently available."));
                    return;
                }

                PopoutService.openSystemUpdate();
                HYPEService.sysupdateUpgrade({
                    "targets": [target]
                }, response => {
                    if (response.error) {
                        ToastService.showError(I18n.tr("Update failed to start"), response.error);
                        return;
                    }
                    SystemUpdateService.requestState();
                    PopoutService.openSystemUpdate();
                });
            });
            return;
        }

        const installed = SessionData.installedTerminals || [];
        const terminal = SessionData.resolveTerminal() || (installed.length > 0 ? installed[0] : "");
        if (!terminal || terminal.length === 0) {
            ToastService.showError(I18n.tr("No terminal configured"), I18n.tr("Pick a terminal in Settings or install kitty."));
            return;
        }

        const command = ShellVersionService.installerUpdateCommand("--reboot-if-needed");
        Quickshell.execDetached(aboutTab.terminalLaunchArgs(terminal, "HypeShell Update", command));
        ToastService.showInfo(I18n.tr("HypeShell update started"), I18n.tr("Follow the terminal window to finish the update."));
    }

    HypeFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: mainColumn.height + Theme.spacingXL
        contentWidth: width

        Column {
            id: mainColumn
            topPadding: 4

            width: Math.min(550, parent.width - Theme.spacingL * 2)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingXL

            // ASCII Art Header
            StyledRect {
                width: parent.width
                height: asciiSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 0

                Column {
                    id: asciiSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: parent.width < 350 ? Theme.spacingM : Theme.spacingL

                        property bool compactLogo: parent.width < 400
                        property bool hideLogo: parent.width < 280

                        Image {
                            id: logoImage

                            visible: !parent.hideLogo
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.compactLogo ? 80 : 120
                            height: width
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true
                            asynchronous: true
                            source: "file://" + Theme.shellDir + "/assets/hypeshell-logo.svg"
                            layer.enabled: true
                            layer.smooth: true
                            layer.mipmap: true
                            layer.effect: MultiEffect {
                                saturation: 0
                                colorization: 1
                                colorizationColor: Theme.primary
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "HYPESHELL"
                            font.pixelSize: parent.compactLogo ? 32 : 48
                            font.weight: Font.Bold
                            font.family: interFont.name
                            color: Theme.surfaceText
                            antialiasing: true

                            FontLoader {
                                id: interFont
                                source: Qt.resolvedUrl("../../assets/fonts/inter/InterVariable.ttf")
                            }
                        }
                    }

                    StyledText {
                        text: aboutTab.displayVersion()
                        font.pixelSize: Theme.fontSizeXLarge
                        font.weight: Font.Bold
                        color: Theme.surfaceText
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width
                    }

                    StyledText {
                        visible: ShellVersionService.shellCodename.length > 0
                        text: `"${ShellVersionService.shellCodename}"`
                        font.pixelSize: Theme.fontSizeMedium
                        font.italic: true
                        color: Theme.surfaceVariantText
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width
                    }

                    Row {
                        id: resourceButtonsRow
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.spacingS

                        property bool compactMode: parent.width < 450

                        HypeButton {
                            id: docsButton
                            text: resourceButtonsRow.compactMode ? "" : I18n.tr("Docs")
                            iconName: "menu_book"
                            iconSize: 18
                            backgroundColor: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08)
                            textColor: Theme.surfaceText
                            onClicked: Qt.openUrlExternally("https://github.com/acarlton5/HypeShell")
                            onHoveredChanged: {
                                if (hovered)
                                    resourceTooltip.show(resourceButtonsRow.compactMode ? I18n.tr("Docs") + " - github.com/acarlton5/HypeShell" : "github.com/acarlton5/HypeShell", docsButton, 0, 0, "bottom");
                                else
                                    resourceTooltip.hide();
                            }
                        }

                        HypeButton {
                            id: pluginsButton
                            text: resourceButtonsRow.compactMode ? "" : I18n.tr("Plugins")
                            iconName: "extension"
                            iconSize: 18
                            backgroundColor: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08)
                            textColor: Theme.surfaceText
                            onClicked: Qt.openUrlExternally("https://github.com/acarlton5/HypeRegistry")
                            onHoveredChanged: {
                                if (hovered)
                                    resourceTooltip.show(resourceButtonsRow.compactMode ? I18n.tr("Plugins") + " - github.com/acarlton5/HypeRegistry" : "github.com/acarlton5/HypeRegistry", pluginsButton, 0, 0, "bottom");
                                else
                                    resourceTooltip.hide();
                            }
                        }

                        HypeButton {
                            id: githubButton
                            text: resourceButtonsRow.compactMode ? "" : I18n.tr("GitHub")
                            iconName: "code"
                            iconSize: 18
                            backgroundColor: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08)
                            textColor: Theme.surfaceText
                            onClicked: Qt.openUrlExternally("https://github.com/acarlton5/HypeShell")
                            onHoveredChanged: {
                                if (hovered)
                                    resourceTooltip.show(resourceButtonsRow.compactMode ? "GitHub - acarlton5/HypeShell" : "github.com/acarlton5/HypeShell", githubButton, 0, 0, "bottom");
                                else
                                    resourceTooltip.hide();
                            }
                        }

                        HypeButton {
                            id: kofiButton
                            text: resourceButtonsRow.compactMode ? "" : I18n.tr("Issues")
                            iconName: "bug_report"
                            iconSize: 18
                            backgroundColor: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                            textColor: Theme.primary
                            onClicked: Qt.openUrlExternally("https://github.com/acarlton5/HypeShell/issues")
                            onHoveredChanged: {
                                if (hovered)
                                    resourceTooltip.show(resourceButtonsRow.compactMode ? I18n.tr("Issues") + " - github.com/acarlton5/HypeShell/issues" : "github.com/acarlton5/HypeShell/issues", kofiButton, 0, 0, "bottom");
                                else
                                    resourceTooltip.hide();
                            }
                        }
                    }

                    HypeTooltipV2 {
                        id: resourceTooltip
                    }

                    Item {
                        id: communityIcons
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: 24
                        width: {
                            let baseWidth = compositorButton.width + hypeDiscordButton.width + Theme.spacingM;
                            if (showMatrix) {
                                baseWidth += matrixButton.width + 4;
                            }
                            if (showIrc) {
                                baseWidth += ircButton.width + Theme.spacingM;
                            }
                            if (showCompositorDiscord) {
                                baseWidth += compositorDiscordButton.width + Theme.spacingM;
                            }
                            if (showReddit) {
                                baseWidth += redditButton.width + Theme.spacingM;
                            }
                            return baseWidth;
                        }

                        Item {
                            id: compositorButton
                            width: 24
                            height: 24
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: -2
                            x: 0

                            property bool hovered: false
                            property string tooltipText: compositorTooltip

                            Image {
                                anchors.fill: parent
                                source: Qt.resolvedUrl(".").toString().replace("file://", "").replace("/Modules/Settings/", "") + compositorLogo
                                sourceSize: Qt.size(24, 24)
                                smooth: true
                                fillMode: Image.PreserveAspectFit
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onEntered: parent.hovered = true
                                onExited: parent.hovered = false
                                onClicked: Qt.openUrlExternally(compositorUrl)
                            }
                        }

                        Item {
                            id: matrixButton
                            width: 30
                            height: 24
                            x: compositorButton.x + compositorButton.width + 4
                            visible: showMatrix

                            property bool hovered: false
                            property string tooltipText: I18n.tr("niri Matrix Chat")

                            Image {
                                anchors.fill: parent
                                source: Qt.resolvedUrl(".").toString().replace("file://", "").replace("/Modules/Settings/", "") + "/assets/matrix-logo-white.svg"
                                sourceSize: Qt.size(28, 18)
                                smooth: true
                                fillMode: Image.PreserveAspectFit
                                layer.enabled: true

                                layer.effect: MultiEffect {
                                    colorization: 1
                                    colorizationColor: Theme.surfaceText
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onEntered: parent.hovered = true
                                onExited: parent.hovered = false
                                onClicked: Qt.openUrlExternally("https://matrix.to/#/#niri:matrix.org")
                            }
                        }

                        Item {
                            id: ircButton
                            width: 24
                            height: 24
                            x: compositorButton.x + compositorButton.width + Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            visible: showIrc

                            property bool hovered: false
                            property string tooltipText: ircTooltip

                            HypeIcon {
                                anchors.centerIn: parent
                                name: "forum"
                                size: 20
                                color: Theme.surfaceText
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onEntered: parent.hovered = true
                                onExited: parent.hovered = false
                                onClicked: Qt.openUrlExternally(ircUrl)
                            }
                        }

                        Item {
                            id: hypeDiscordButton
                            width: 20
                            height: 20
                            x: {
                                if (showMatrix)
                                    return matrixButton.x + matrixButton.width + Theme.spacingM;
                                if (showIrc)
                                    return ircButton.x + ircButton.width + Theme.spacingM;
                                return compositorButton.x + compositorButton.width + Theme.spacingM;
                            }
                            anchors.verticalCenter: parent.verticalCenter

                            property bool hovered: false
                            property string tooltipText: hypeDiscordTooltip

                            HypeIcon {
                                anchors.centerIn: parent
                                name: "code"
                                size: 20
                                color: Theme.surfaceText
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onEntered: parent.hovered = true
                                onExited: parent.hovered = false
                                onClicked: Qt.openUrlExternally(hypeDiscordUrl)
                            }
                        }

                        Item {
                            id: compositorDiscordButton
                            width: 20
                            height: 20
                            x: hypeDiscordButton.x + hypeDiscordButton.width + Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            visible: showCompositorDiscord

                            property bool hovered: false
                            property string tooltipText: compositorDiscordTooltip

                            Image {
                                anchors.fill: parent
                                source: Qt.resolvedUrl(".").toString().replace("file://", "").replace("/Modules/Settings/", "") + "/assets/discord.svg"
                                sourceSize: Qt.size(20, 20)
                                smooth: true
                                fillMode: Image.PreserveAspectFit
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onEntered: parent.hovered = true
                                onExited: parent.hovered = false
                                onClicked: Qt.openUrlExternally(compositorDiscordUrl)
                            }
                        }

                        Item {
                            id: redditButton
                            width: 20
                            height: 20
                            x: showCompositorDiscord ? compositorDiscordButton.x + compositorDiscordButton.width + Theme.spacingM : hypeDiscordButton.x + hypeDiscordButton.width + Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            visible: showReddit

                            property bool hovered: false
                            property string tooltipText: redditTooltip

                            Image {
                                anchors.fill: parent
                                source: Qt.resolvedUrl(".").toString().replace("file://", "").replace("/Modules/Settings/", "") + "/assets/reddit.svg"
                                sourceSize: Qt.size(20, 20)
                                smooth: true
                                fillMode: Image.PreserveAspectFit
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onEntered: parent.hovered = true
                                onExited: parent.hovered = false
                                onClicked: Qt.openUrlExternally(redditUrl)
                            }
                        }
                    }
                }
            }

            // Project Information
            StyledRect {
                width: parent.width
                height: projectSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 0

                Column {
                    id: projectSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        HypeIcon {
                            name: "info"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("About")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    StyledText {
                        text: I18n.tr('HypeShell is a Hyprland-focused desktop shell for DSS-OS and Hype systems with a <a href="https://m3.material.io/" style="text-decoration:none; color:%1;">Material 3 inspired</a> interface.<br /><br/>It is built with <a href="https://quickshell.org" style="text-decoration:none; color:%1;">Quickshell</a> for the desktop UI and <a href="https://go.dev" style="text-decoration:none; color:%1;">Go</a> for the HypeShell backend.').arg(Theme.primary)
                        textFormat: Text.RichText
                        font.pixelSize: Theme.fontSizeMedium
                        linkColor: Theme.primary
                        onLinkActivated: url => Qt.openUrlExternally(url)
                        color: Theme.surfaceVariantText
                        width: parent.width
                        wrapMode: Text.WordWrap

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                            acceptedButtons: Qt.NoButton
                            propagateComposedEvents: true
                        }
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: updatesSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 0

                Column {
                    id: updatesSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        HypeIcon {
                            name: "system_update"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Updates")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    StyledText {
                        text: (ShellVersionService.updateStatus === "checking" || SystemUpdateService.isChecking) ? I18n.tr("Checking for updates...") : aboutTab.updateStatusText()
                        font.pixelSize: Theme.fontSizeMedium
                        color: aboutTab.updateStatusColor()
                        width: parent.width
                        wrapMode: Text.WordWrap
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        Column {
                            width: (parent.width - Theme.spacingM) / 2
                            spacing: Theme.spacingXS

                            StyledText {
                                text: I18n.tr("Installed")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }

                            StyledText {
                                text: ShellVersionService.installedCommit || I18n.tr("Unknown")
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }

                        Column {
                            width: (parent.width - Theme.spacingM) / 2
                            spacing: Theme.spacingXS

                            StyledText {
                                text: I18n.tr("Latest")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }

                            StyledText {
                                text: ShellVersionService.latestCommit || (ShellVersionService.updateStatus === "checking" ? I18n.tr("Checking") : I18n.tr("Not checked"))
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }
                    }

                    // Sectioned Update Cards
                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        // HypeShell Card
                        StyledRect {
                            width: parent.width
                            height: 60
                            radius: Theme.cornerRadius - 2
                            color: Theme.withAlpha(Theme.surfaceVariantText, 0.04)
                            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
                            border.width: 1

                            Row {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingM
                                spacing: Theme.spacingM

                                HypeIcon {
                                    name: "system_update_alt"
                                    size: 18
                                    color: aboutTab.hasHypeShellUpdate ? Theme.primary : Theme.success
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    StyledText {
                                        text: I18n.tr("HypeShell")
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Font.Medium
                                        color: Theme.surfaceText
                                    }

                                    StyledText {
                                        text: aboutTab.hasHypeShellUpdate ? `${aboutTab.hypeShellUpdate.fromVersion}  ➔  ${aboutTab.hypeShellUpdate.toVersion}` : I18n.tr("Up to date")
                                        font.family: aboutTab.hasHypeShellUpdate ? (Theme.monoFontFamily || "monospace") : undefined
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: aboutTab.hasHypeShellUpdate ? Theme.primary : Theme.success
                                    }
                                }
                            }
                        }

                        // Pacman Card
                        StyledRect {
                            width: parent.width
                            height: 60
                            radius: Theme.cornerRadius - 2
                            color: Theme.withAlpha(Theme.surfaceVariantText, 0.04)
                            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
                            border.width: 1

                            Row {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingM
                                spacing: Theme.spacingM

                                HypeIcon {
                                    name: "apps"
                                    size: 18
                                    color: aboutTab.pacmanUpdatesCount > 0 ? Theme.primary : Theme.surfaceVariantText
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    StyledText {
                                        text: I18n.tr("Pacman Updates")
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Font.Medium
                                        color: Theme.surfaceText
                                    }

                                    StyledText {
                                        text: aboutTab.pacmanUpdatesCount === 0 ? I18n.tr("Up to date") : I18n.tr("%1 updates available").arg(aboutTab.pacmanUpdatesCount)
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: aboutTab.pacmanUpdatesCount > 0 ? Theme.primary : Theme.success
                                    }
                                }
                            }
                        }

                        // Paru Card
                        StyledRect {
                            width: parent.width
                            height: 60
                            radius: Theme.cornerRadius - 2
                            color: Theme.withAlpha(Theme.surfaceVariantText, 0.04)
                            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
                            border.width: 1

                            Row {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingM
                                spacing: Theme.spacingM

                                HypeIcon {
                                    name: "extension"
                                    size: 18
                                    color: aboutTab.paruUpdatesCount > 0 ? Theme.primary : Theme.surfaceVariantText
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    StyledText {
                                        text: I18n.tr("Paru Updates (AUR)")
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Font.Medium
                                        color: Theme.surfaceText
                                    }

                                    StyledText {
                                        text: aboutTab.paruUpdatesCount === 0 ? I18n.tr("Up to date") : I18n.tr("%1 updates available").arg(aboutTab.paruUpdatesCount)
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: aboutTab.paruUpdatesCount > 0 ? Theme.primary : Theme.success
                                    }
                                }
                            }
                        }

                        // Flatpak Card
                        StyledRect {
                            width: parent.width
                            height: 60
                            radius: Theme.cornerRadius - 2
                            color: Theme.withAlpha(Theme.surfaceVariantText, 0.04)
                            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
                            border.width: 1

                            Row {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingM
                                spacing: Theme.spacingM

                                HypeIcon {
                                    name: "cloud_download"
                                    size: 18
                                    color: aboutTab.flatpakUpdatesCount > 0 ? Theme.primary : Theme.surfaceVariantText
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    StyledText {
                                        text: I18n.tr("Flatpak Updates")
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Font.Medium
                                        color: Theme.surfaceText
                                    }

                                    StyledText {
                                        text: aboutTab.flatpakUpdatesCount === 0 ? I18n.tr("Up to date") : I18n.tr("%1 updates available").arg(aboutTab.flatpakUpdatesCount)
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: aboutTab.flatpakUpdatesCount > 0 ? Theme.primary : Theme.success
                                    }
                                }
                            }
                        }
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.spacingS

                        HypeButton {
                            text: (ShellVersionService.updateStatus === "checking" || SystemUpdateService.isChecking) ? I18n.tr("Checking") : I18n.tr("Check for Updates")
                            iconName: "refresh"
                            enabled: ShellVersionService.updateStatus !== "checking" && !SystemUpdateService.isChecking
                            backgroundColor: Theme.primary
                            textColor: Theme.primaryText
                            onClicked: aboutTab.triggerCheck()
                        }

                        HypeButton {
                            text: I18n.tr("Update Now")
                            iconName: "system_update"
                            visible: aboutTab.hasHypeShellUpdate || aboutTab.totalSystemUpdates > 0
                            backgroundColor: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08)
                            textColor: Theme.surfaceText
                            onClicked: PopoutService.openSystemUpdate()
                        }
                    }
                }
            }

            StyledRect {
                visible: false
                width: parent.width
                height: backendSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 0

                Column {
                    id: backendSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        HypeIcon {
                            name: "dns"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Backend")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        anchors.left: parent.left
                        spacing: Theme.spacingL

                        Column {
                            spacing: 2

                            StyledText {
                                text: I18n.tr("Version")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                horizontalAlignment: Text.AlignLeft
                            }

                            StyledText {
                                text: HYPEService.cliVersion || "—"
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                                horizontalAlignment: Text.AlignLeft
                            }
                        }

                        Rectangle {
                            width: 1
                            height: 32
                            color: Theme.outlineVariant
                        }

                        Column {
                            spacing: 2

                            StyledText {
                                text: I18n.tr("API")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                horizontalAlignment: Text.AlignLeft
                            }

                            StyledText {
                                text: `v${HYPEService.apiVersion}`
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                                horizontalAlignment: Text.AlignLeft
                            }
                        }

                        Rectangle {
                            width: 1
                            height: 32
                            color: Theme.outlineVariant
                        }

                        Column {
                            spacing: 2

                            StyledText {
                                text: I18n.tr("Status")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                horizontalAlignment: Text.AlignLeft
                            }

                            Row {
                                spacing: 4

                                Rectangle {
                                    width: 8
                                    height: 8
                                    radius: 4
                                    color: Theme.success
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: I18n.tr("Connected")
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                    horizontalAlignment: Text.AlignLeft
                                }
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS
                        visible: HYPEService.capabilities.length > 0

                        StyledText {
                            text: I18n.tr("Capabilities")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            width: parent.width
                            horizontalAlignment: Text.AlignLeft
                        }

                        Flow {
                            width: parent.width
                            spacing: 6

                            Repeater {
                                model: HYPEService.capabilities

                                Rectangle {
                                    width: capText.implicitWidth + 16
                                    height: 26
                                    radius: 13
                                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)

                                    StyledText {
                                        id: capText
                                        anchors.centerIn: parent
                                        text: modelData
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.primary
                                    }
                                }
                            }
                        }
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: toolsSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 0

                Column {
                    id: toolsSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        HypeIcon {
                            name: "build"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Tools")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        anchors.left: parent.left
                        spacing: Theme.spacingS

                        HypeButton {
                            text: I18n.tr("Show Welcome")
                            iconName: "waving_hand"
                            backgroundColor: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08)
                            textColor: Theme.surfaceText
                            onClicked: FirstLaunchService.showWelcome()
                        }

                        HypeButton {
                            text: I18n.tr("System Check")
                            iconName: "vital_signs"
                            backgroundColor: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08)
                            textColor: Theme.surfaceText
                            onClicked: FirstLaunchService.showDoctor()
                        }
                    }
                }
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: I18n.tr('<a href="https://github.com/acarlton5/HypeShell/blob/main/LICENSE" style="text-decoration:none; color:%1;">MIT License</a>').arg(Theme.surfaceVariantText)
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceVariantText
                textFormat: Text.RichText
                wrapMode: Text.NoWrap
                onLinkActivated: url => Qt.openUrlExternally(url)

                MouseArea {
                    anchors.fill: parent
                    cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                    acceptedButtons: Qt.NoButton
                    propagateComposedEvents: true
                }
            }
        }
    }

    // Community tooltip - positioned absolutely above everything
    Rectangle {
        id: communityTooltip
        parent: aboutTab
        z: 1000

        property var hoveredButton: {
            if (compositorButton.hovered)
                return compositorButton;
            if (matrixButton.visible && matrixButton.hovered)
                return matrixButton;
            if (ircButton.visible && ircButton.hovered)
                return ircButton;
            if (hypeDiscordButton.hovered)
                return hypeDiscordButton;
            if (compositorDiscordButton.visible && compositorDiscordButton.hovered)
                return compositorDiscordButton;
            if (redditButton.visible && redditButton.hovered)
                return redditButton;
            return null;
        }

        property string tooltipText: hoveredButton ? hoveredButton.tooltipText : ""

        visible: hoveredButton !== null && tooltipText !== ""
        width: tooltipLabel.implicitWidth + 24
        height: tooltipLabel.implicitHeight + 12

        color: Theme.surfaceContainer
        radius: Theme.cornerRadius
        border.width: 0
        border.color: Theme.outlineMedium

        x: hoveredButton ? hoveredButton.mapToItem(aboutTab, hoveredButton.width / 2, 0).x - width / 2 : 0
        y: hoveredButton ? communityIcons.mapToItem(aboutTab, 0, 0).y - height - 8 : 0

        ElevationShadow {
            anchors.fill: parent
            z: -1
            level: Theme.elevationLevel1
            fallbackOffset: 1
            targetRadius: communityTooltip.radius
            targetColor: communityTooltip.color
            borderColor: communityTooltip.border.color
            borderWidth: communityTooltip.border.width
            shadowOpacity: Theme.elevationLevel1 && Theme.elevationLevel1.alpha !== undefined ? Theme.elevationLevel1.alpha : 0.2
            shadowEnabled: Theme.elevationEnabled
        }

        StyledText {
            id: tooltipLabel
            anchors.centerIn: parent
            text: communityTooltip.tooltipText
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceText
        }
    }
}
