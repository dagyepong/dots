import QtQuick
import Quickshell
import qs.theme
import qs.services

// The pill that transforms:
// idle -> compact (hover) -> month (click) -> day (click on a day)
// e inoltre: workspaces | toast | launcher | capture | power | auth
Rectangle {
    id: root

    property string screenName: ""

    property bool expanded: false    // hover: big clock + day strip
    property bool monthMode: false   // click: monthly calendar
    property bool dayMode: false     // click on a day: notes editor
    property int dayYear: 2000
    property int dayMonth: 0
    property int dayDay: 1
    property int viewYear: 2000
    property int viewMonth: 0

    readonly property bool hovered: hover.hovered

    // Vertical style: launcher, power menu, capture menu, recording menu and the name prompt are panels attached to the bar (Popouts), not part of this island
    property bool attachedPanels: false

    function onThisScreen(name) { return name === "" || name === screenName }

    readonly property bool authActive:       Auth.active && onThisScreen(Auth.screen)
    readonly property bool powerActive:      !attachedPanels && UiState.powerOpen && onThisScreen(UiState.powerScreen)
    readonly property bool themeActive:      !attachedPanels && Appearance.pickerOpen && onThisScreen(Appearance.pickerScreen)
    readonly property bool variantActive:    !attachedPanels && Style.variantOpen && onThisScreen(Style.variantScreen)
    readonly property bool captureActive:    !attachedPanels && UiState.captureOpen && onThisScreen(UiState.captureScreen)
    readonly property bool launcherActive:   !attachedPanels && UiState.launcherOpen && onThisScreen(UiState.launcherScreen)
    readonly property bool workspacesActive: Workspaces.shown && onThisScreen(Workspaces.screen) && Style.current !== "classic" && Style.current !== "dash"
    readonly property bool toastActive:      Toast.active && onThisScreen(Toast.screen)
    readonly property bool recMenuActive:    !attachedPanels && UiState.recMenuOpen && onThisScreen(UiState.recMenuScreen)
    readonly property bool namingActive:     !attachedPanels && Capture.naming && onThisScreen(Capture.pendingScreen)

    // Priority: auth > power > capture > recording name > launcher > recording menu
    //           > notes editor > workspace > toast > calendar > clock
    // Launcher, power, authentication, recording, toasts...: modes that need this island even in the dashboard style
    readonly property bool special: mode !== "idle" && mode !== "compact" && mode !== "month" && mode !== "workspaces"

    readonly property string mode: {
        if (authActive) return "auth"
        if (powerActive) return "power"
        if (themeActive) return "theme"
        if (variantActive) return "variant"
        if (captureActive) return "capture"
        if (namingActive) return "naming"
        if (launcherActive) return "launcher"
        if (recMenuActive) return "record"
        if (dayMode && monthMode) return "day"
        if (workspacesActive) return "workspaces"
        if (toastActive) return "toast"
        if (monthMode) return "month"
        return expanded ? "compact" : "idle"
    }

    // The bar uses this to grant exclusive keyboard focus
    readonly property bool wantsKeyboard: mode === "auth" || mode === "power" || mode === "launcher" || mode === "theme" || mode === "variant"
                                          || mode === "capture" || mode === "day" || mode === "naming"

    readonly property string monthTitle: {
        const n = Qt.locale("en_US").monthName(viewMonth, Locale.LongFormat)
        return n.charAt(0).toUpperCase() + n.slice(1) + " " + viewYear
    }

    readonly property int collapsedW: tm.advanceWidth + Theme.padding * 2
    readonly property int compactW: 240
    readonly property int monthW: 300
    readonly property int launcherW: 480
    readonly property int launcherH: 380
    readonly property int authW: 420
    readonly property int authH: 270
    readonly property int powerW: 470
    readonly property int powerH: 190
    readonly property int themeW: 700
    readonly property int themeH: 184
    readonly property int variantW: 520
    readonly property int variantH: 190
    readonly property int captureW: 470
    readonly property int captureH: 196
    readonly property int recW: 360
    readonly property int recH: Math.round(recView.implicitHeight)
    readonly property int nameW: 380
    readonly property int nameH: Math.round(nameView.implicitHeight)
    readonly property int dayW: 340
    readonly property int dayH: Math.round(dayView.implicitHeight)
    readonly property int toastW: 380
    readonly property int toastH: Math.round(toastView.implicitHeight)
    readonly property int wsW: Math.round(wsView.implicitWidth)
    readonly property int compactH: 14 + 30 + 10 + strip.implicitHeight + 14
    readonly property int monthH: monthCol.implicitHeight + 28

    readonly property var dims: {
        switch (mode) {
        case "auth":       return [authW, authH]
        case "power":      return [powerW, powerH]
        case "theme":      return [themeW, themeH]
        case "variant":    return [variantW, variantH]
        case "capture":    return [captureW, captureH]
        case "naming":     return [nameW, nameH]
        case "record":     return [recW, recH]
        case "launcher":   return [launcherW, launcherH]
        case "day":        return [dayW, dayH]
        case "workspaces": return [wsW, Math.round(wsView.implicitHeight)]
        case "toast":      return [toastW, toastH]
        case "month":      return [monthW, monthH]
        case "compact":    return [compactW, compactH]
        default:           return [collapsedW, Theme.islandHeight]
        }
    }

    width: dims[0]
    height: dims[1]
    // Dashboard "Attached" version: the menus come out of the top edge with the same shape as the bar
    // (the Bar draws it with AttachedShape, behind this item)
    readonly property bool attachedLook: Style.dashAttached && Style.current === "dash"
    readonly property color edgeColor: mode === "auth" ? Theme.accent
                  : ((mode === "toast" && Toast.current && Toast.current.tone === "danger") ? Theme.danger
                                                                                          : Theme.border)
    readonly property real corner: Math.min(24, Math.max(18, height / 3))

    radius: attachedLook ? corner : Math.min(24, height / 2)
    color: attachedLook ? "transparent" : Theme.island
    border.width: attachedLook ? 0 : 1
    border.color: edgeColor
    clip: true

    Behavior on width  { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
    Behavior on height { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
    Behavior on border.color { ColorAnimation { duration: 200 } }

    function openDay(d) {
        dayYear = d.getFullYear()
        dayMonth = d.getMonth()
        dayDay = d.getDate()
        dayMode = true
    }

    function resetView() {
        viewYear = clock.date.getFullYear()
        viewMonth = clock.date.getMonth()
    }

    function shiftMonth(delta) {
        let m = viewMonth + delta
        let y = viewYear
        if (m < 0) { m = 11; y-- }
        else if (m > 11) { m = 0; y++ }
        viewMonth = m
        viewYear = y
    }

    onMonthModeChanged: {
        if (monthMode) resetView()
        else dayMode = false
    }

    onModeChanged: {
        if (mode === "launcher") launcherView.reset()
        else if (mode === "auth") authView.reset()
        else if (mode === "power") powerView.reset()
        else if (mode === "theme") themeView.reset()
        else if (mode === "variant") variantView.reset()
        else if (mode === "capture") captureView.reset()
        else if (mode === "naming") nameView.reset()
        else if (mode === "day") dayView.reset()

        // The recording menu must not reappear after another view
        if (mode === "auth" || mode === "power" || mode === "capture" || mode === "theme" || mode === "variant"
                || mode === "naming" || mode === "launcher")
            UiState.recMenuOpen = false
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Only used to know the width of the closed pill
    TextMetrics {
        id: tm
        text: "00:00"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        font.bold: true
    }

    HoverHandler {
        id: hover
        onHoveredChanged: {
            if (hovered) {
                collapseTimer.stop()
                root.expanded = true
            } else {
                collapseTimer.restart()
            }
        }
    }

    Timer {
        id: collapseTimer
        interval: 220
        onTriggered: {
            if (root.dayMode) return        // writing a note: don't close
            root.expanded = false
            root.monthMode = false
            UiState.recMenuOpen = false
        }
    }

    // Click on the pill/clock: opens the month (recording continues).
    // Right click: recording menu.
    MouseArea {
        anchors.fill: parent
        enabled: root.mode === "idle" || root.mode === "compact"
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                UiState.recMenuScreen = root.screenName
                UiState.recMenuOpen = true
            } else {
                root.monthMode = true
            }
        }
    }

    // Menu open: right click on an empty spot closes it
    MouseArea {
        anchors.fill: parent
        enabled: root.mode === "record"
        acceptedButtons: Qt.RightButton
        onClicked: UiState.recMenuOpen = false
    }

    // ---------- Ora ----------
    Text {
        id: timeText

        anchors.horizontalCenter: parent.horizontalCenter
        y: root.expanded ? 14 : (Theme.islandHeight - height) / 2

        text: Qt.formatDateTime(clock.date, Settings.timeFormat)
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: root.expanded ? 24 : Theme.fontSize
        font.bold: true
        opacity: ((root.mode === "idle" || root.mode === "compact")
                  && !(Capture.recording && root.mode === "idle")) ? 1 : 0

        Behavior on y { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
        Behavior on font.pixelSize { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    // ---------- Recording in progress (right click: menu with stop and mute) ----------
    Row {
        anchors.centerIn: parent
        spacing: 6
        visible: Capture.recording && root.mode === "idle"

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 8
            height: 8
            radius: 4
            color: Theme.danger
            visible: !Capture.paused

            SequentialAnimation on opacity {
                running: Capture.recording && !Capture.paused
                loops: Animation.Infinite
                NumberAnimation { from: 1; to: 0.25; duration: 600 }
                NumberAnimation { from: 0.25; to: 1; duration: 600 }
            }
        }

        // Paused: the blinking dot becomes the pause symbol
        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            visible: Capture.paused
            kind: "pause"
            size: 10
            color: Theme.muted
        }

        Text {
            text: Capture.timeText
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.bold: true
        }
    }

    // ---------- 5-day strip ----------
    WeekStrip {
        id: strip

        y: 14 + 30 + 10
        anchors.horizontalCenter: parent.horizontalCenter
        width: 210
        today: clock.date

        opacity: root.mode === "compact" ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
    }

    // ---------- Calendario mensile ----------
    Column {
        id: monthCol

        y: 14
        anchors.horizontalCenter: parent.horizontalCenter
        width: 266
        spacing: 10

        opacity: root.mode === "month" ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 180 } }

        Item {
            width: parent.width
            height: 28

            NavButton {
                anchors.left: parent.left
                label: "‹"
                onClicked: root.shiftMonth(-1)
            }

            Text {
                anchors.centerIn: parent
                text: root.monthTitle
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.bold: true

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.monthMode = false
                }
            }

            NavButton {
                anchors.right: parent.right
                label: "›"
                onClicked: root.shiftMonth(1)
            }
        }

        MonthGrid {
            year: root.viewYear
            month: root.viewMonth
            today: clock.date
            onDayClicked: d => root.openDay(d)
        }
    }

    // ---------- Editor for the day's notes ----------
    DayView {
        id: dayView

        width: root.dayW
        height: implicitHeight
        year: root.dayYear
        month: root.dayMonth
        day: root.dayDay
        opacity: root.mode === "day" ? 1 : 0
        visible: root.mode === "day" || opacity > 0
        Behavior on opacity { NumberAnimation { duration: root.mode === "day" ? 220 : 80 } }

        onCloseRequested: root.dayMode = false
    }

    // ---------- Workspace ----------
    WorkspacesView {
        id: wsView

        screenName: root.screenName
        width: implicitWidth
        height: implicitHeight
        opacity: root.mode === "workspaces" ? 1 : 0
        visible: root.mode === "workspaces" || opacity > 0
        Behavior on opacity { NumberAnimation { duration: root.mode === "workspaces" ? 200 : 80 } }
    }

    // ---------- Toast ----------
    ToastView {
        id: toastView

        width: root.toastW
        height: implicitHeight
        opacity: root.mode === "toast" ? 1 : 0
        visible: root.mode === "toast" || opacity > 0
        Behavior on opacity { NumberAnimation { duration: root.mode === "toast" ? 220 : 80 } }
    }

    // ---------- Launcher ----------
    LauncherView {
        id: launcherView

        width: root.launcherW
        height: root.launcherH
        opacity: root.mode === "launcher" ? 1 : 0
        visible: root.mode === "launcher" || opacity > 0
        Behavior on opacity { NumberAnimation { duration: root.mode === "launcher" ? 240 : 80 } }

        onCloseRequested: UiState.launcherOpen = false
    }

    // ---------- Power ----------
    PowerView {
        id: powerView

        width: root.powerW
        height: root.powerH
        opacity: root.mode === "power" ? 1 : 0
        visible: root.mode === "power" || opacity > 0
        Behavior on opacity { NumberAnimation { duration: root.mode === "power" ? 240 : 80 } }
    }

    // ---------- Theme selector ----------
    ThemeView {
        id: themeView

        width: root.themeW
        height: root.themeH
        opacity: root.mode === "theme" ? 1 : 0
        visible: root.mode === "theme" || opacity > 0
        Behavior on opacity { NumberAnimation { duration: root.mode === "theme" ? 240 : 80 } }
    }

    // ---------- Dashboard version selector ----------
    VariantView {
        id: variantView

        width: root.variantW
        height: root.variantH
        opacity: root.mode === "variant" ? 1 : 0
        visible: root.mode === "variant" || opacity > 0
        Behavior on opacity { NumberAnimation { duration: root.mode === "variant" ? 240 : 80 } }
    }

    // ---------- Autenticazione ----------
    AuthView {
        id: authView

        width: root.authW
        height: root.authH
        opacity: root.mode === "auth" ? 1 : 0
        visible: root.mode === "auth" || opacity > 0
        Behavior on opacity { NumberAnimation { duration: root.mode === "auth" ? 240 : 80 } }
    }

    // ---------- Recording menu ----------
    RecordView {
        id: recView

        width: root.recW
        height: implicitHeight
        opacity: root.mode === "record" ? 1 : 0
        visible: root.mode === "record" || opacity > 0
        Behavior on opacity { NumberAnimation { duration: root.mode === "record" ? 240 : 80 } }
    }

    // ---------- Recording name ----------
    NameView {
        id: nameView

        width: root.nameW
        height: implicitHeight
        opacity: root.mode === "naming" ? 1 : 0
        visible: root.mode === "naming" || opacity > 0
        Behavior on opacity { NumberAnimation { duration: root.mode === "naming" ? 240 : 80 } }
    }

    // ---------- Capture ----------
    CaptureView {
        id: captureView

        width: root.captureW
        height: root.captureH
        opacity: root.mode === "capture" ? 1 : 0
        visible: root.mode === "capture" || opacity > 0
        Behavior on opacity { NumberAnimation { duration: root.mode === "capture" ? 240 : 80 } }
    }
}
