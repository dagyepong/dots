import "../../core"
import "../../services"
import "../../widgets"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

/**
 * Shows the active window as a single adaptive title so the status bar does not
 * collapse into two unreadable clipped lines near the center island.
 */
Item {
    id: root
    property HyprlandMonitor monitor
    property color color: Appearance.colors.colStatusBarText
    property color subtextColor: Appearance.colors.colStatusBarSubtext
    property real maxWidth: 400 * Appearance.effectiveScale
    
    readonly property Toplevel activeWindow: ToplevelManager.activeToplevel
    readonly property bool focusingThisMonitor: HyprlandData.activeWorkspace?.monitor == monitor?.name

    property string appClassText: root.focusingThisMonitor && root.activeWindow?.activated ?
                (root.activeWindow?.appId ?? "Desktop") : (HyprlandData.activeWindow?.class ?? "Desktop")

    property string appTitleText: root.focusingThisMonitor && root.activeWindow?.activated ?
                (root.activeWindow?.title ?? "Overview") : (HyprlandData.activeWindow?.title ?? `Workspace ${monitor?.activeWorkspace?.id ?? 1}`)

    function cleanAppName(name) {
        const raw = (name || "Desktop").toString()
        if (raw === "org.gnome.Nautilus") return "Files"
        if (raw === "org.gnome.Loupe") return "Image Viewer"
        if (raw === "org.kde.ark") return "Extract"
        return raw
            .replace(/^org\.(gnome|kde)\./, "")
            .replace(/[-_.]+/g, " ")
            .replace(/\b\w/g, c => c.toUpperCase())
    }

    readonly property string compactAppText: cleanAppName(root.appClassText)
    readonly property string compactTitleText: (root.appTitleText || "").toString()
    readonly property bool titleAddsInfo: compactTitleText !== "" && compactTitleText.toLowerCase() !== compactAppText.toLowerCase()
    readonly property string displayText: titleAddsInfo ? compactAppText + " - " + compactTitleText : compactAppText

    implicitWidth: root.maxWidth
    implicitHeight: activeTitle.implicitHeight
    width: implicitWidth
    height: implicitHeight
    clip: true

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Easing.OutCubic
        }
    }

    StyledText {
        id: activeTitle
        anchors.verticalCenter: parent.verticalCenter
        width: root.width
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: root.color
        elide: Text.ElideRight
        maximumLineCount: 1
        wrapMode: Text.NoWrap
        text: root.displayText
    }
}
