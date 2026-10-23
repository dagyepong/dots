import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

// Control Center tile for Aibou. Aibou itself runs as its own Quickshell
// instance (aibou.service); this tile only calls its helper `aibou`.
PluginComponent {
    id: root

    readonly property string cli: "\"$(command -v aibou || echo \"$HOME/.local/bin/aibou\")\""

    // "on", "off" or "" while unknown
    property string aibouState: ""
    readonly property bool isOn: aibouState === "on"
    property bool busy: false

    // Proc debounces by id; tile and detail are separate instances.
    readonly property string procId: "aibou." + Math.random().toString(36).slice(2, 8)

    // Read directly: DMS creates the tile and detail instances with
    // createObject(null), so pluginData is not always set.
    readonly property bool inFront: SettingsData.getPluginSetting("aibou", "front", false) === true
    readonly property string figure: {
        const s = SettingsData.getPluginSetting("aibou", "skin1", "kuro");
        return s === "none" ? "kuro" : s;
    }

    // The tile shows the figure itself where DankIcon can draw images (it
    // then has the property isImage); otherwise a plain symbol.
    DankIcon {
        id: iconProbe
        visible: false
    }
    readonly property bool imageIcons: iconProbe.isImage !== undefined
    readonly property string figureIcon: root.imageIcons ? Qt.resolvedUrl("icons/" + root.figure + ".svg").toString() : "mood"

    // Poll only while the Control Center is open (popout or island).
    readonly property bool ccOpen: (PopoutService.controlCenterPopout?.shouldBeVisible ?? false) || PopoutService.islandControlCenterOpen

    function refresh() {
        if (root.busy)
            return;
        Proc.runCommand(root.procId + ".state", ["sh", "-c", root.cli + " state"], (out, code) => {
            // DMS builds and drops widget copies while it starts; a dropped one has no root any more
            if (!root)
                return;
            const s = (out || "").trim();
            root.aibouState = (s === "on" || s === "off") ? s : "off";
        }, 10);
    }

    function toggle() {
        if (root.busy)
            return;
        root.busy = true;
        root.aibouState = root.isOn ? "off" : "on";
        Proc.runCommand(root.procId + ".toggle", ["sh", "-c", root.cli + " toggle"], (out, code) => {
            root.busy = false;
            if (code !== 0)
                ToastService.showError("Aibou", I18n.trFor("aibou", "Could not switch Aibou"));
            root.refresh();
        }, 10);
    }

    function runAction(fn, closeCc) {
        if (!root.isOn)
            return;
        Proc.runCommand(root.procId + "." + fn, ["sh", "-c", root.cli + " " + fn], (out, code) => {
            if (code !== 0)
                ToastService.showError("Aibou", I18n.trFor("aibou", "Aibou did not respond"));
        }, 10);
        if (closeCc)
            PopoutService.closeControlCenter();
    }

    Timer {
        interval: 4000
        repeat: true
        running: root.ccOpen
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    ccWidgetIcon: root.figureIcon
    ccWidgetPrimaryText: "Aibou"
    ccWidgetSecondaryText: {
        if (root.aibouState === "")
            return "";
        if (!root.isOn)
            return I18n.trFor("aibou", "Off");
        return root.inFront ? I18n.trFor("aibou", "Stays in front of the windows") : I18n.trFor("aibou", "Lives behind the windows");
    }
    ccWidgetIsActive: isOn
    ccDetailHeight: 204

    onCcWidgetToggled: toggle()

    ccDetailContent: Component {
        Rectangle {
            id: detailRoot

            implicitHeight: root.ccDetailHeight
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh

            readonly property var actions: [
                { fn: "front", label: I18n.trFor("aibou", "Bring to front"), icon: "flip_to_front", close: true },
                { fn: "chat", label: I18n.trFor("aibou", "Chat"), icon: "chat", close: true },
                { fn: "dockToggle", label: I18n.trFor("aibou", "Into the frame"), icon: "vertical_align_bottom", close: false },
                { fn: "sleepToggle", label: I18n.trFor("aibou", "Sleep / wake"), icon: "bedtime", close: false },
                { fn: "play", label: I18n.trFor("aibou", "Ball"), icon: "sports_baseball", close: false }
            ]

            Column {
                id: detailColumn
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingS

                StyledText {
                    width: parent.width
                    text: root.isOn ? I18n.trFor("aibou", "Quick actions") : I18n.trFor("aibou", "Switch Aibou on to use these.")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    elide: Text.ElideRight
                }

                Grid {
                    width: parent.width
                    columns: 2
                    columnSpacing: Theme.spacingXS
                    rowSpacing: Theme.spacingXS

                    Repeater {
                        model: detailRoot.actions

                        Rectangle {
                            required property var modelData

                            width: (detailColumn.width - Theme.spacingXS) / 2
                            height: Theme.iconSize + Theme.spacingL + Theme.spacingXS
                            radius: Theme.cornerRadius
                            opacity: root.isOn ? 1 : 0.4
                            color: actionHover.containsMouse && root.isOn ? Theme.surfaceContainerHighest : Theme.surfaceContainer

                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.spacingXS

                                DankIcon {
                                    name: modelData.icon
                                    size: Theme.iconSizeSmall
                                    color: Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: modelData.label
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: actionHover
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: root.isOn
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.runAction(modelData.fn, modelData.close)
                            }
                        }
                    }
                }
            }
        }
    }
}
