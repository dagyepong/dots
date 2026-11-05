pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.theme

// The welcome tour: a card in the middle of the screen with steps. It opens by itself the first time the shell
// starts (until you finish or skip it) and can be reopened from Settings > About.
Singleton {
    id: root

    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/quickshell"

    property bool open: false
    property string screenName: ""
    property int step: 0
    property int dir: 1                 // 1 forward, -1 back (for the slide of the steps)
    property bool hidden: false         // out of the way while a menu opened with "Try" is on screen
    property bool done: false

    readonly property var steps: [
        { id: "hello",   label: "Welcome",       file: "WStepHello.qml" },
        { id: "style",   label: "Style",         file: "WStepStyle.qml" },
        { id: "colors",  label: "Colors",        file: "WStepColors.qml" },
        { id: "basics",  label: "Clock",         file: "WStepBasics.qml" },
        { id: "connect", label: "Wi-Fi",         file: "WStepConnect.qml" },
        { id: "screens", label: "Monitors",      file: "WStepScreens.qml" },
        { id: "keys",    label: "Shortcuts",     file: "WStepKeys.qml" },
        { id: "how",     label: "How it works",  file: "WStepHow.qml" },
        { id: "done",    label: "Ready",         file: "WStepDone.qml" }
    ]
    readonly property bool first: step === 0
    readonly property bool last: step === steps.length - 1

    FileView {
        id: store
        path: root.stateDir + "/welcome.json"
        blockLoading: true
        printErrors: false
    }

    function save() {
        try { store.setText(JSON.stringify({ done: done })) } catch (e) { console.log("welcome: save:", e) }
    }

    function show() {
        step = 0
        dir = 1
        hidden = false
        Settings.open = false
        screenName = Compositor.focusedMonitor
        if (screenName === "" && Quickshell.screens.length > 0) screenName = Quickshell.screens[0].name
        open = true
    }

    // Closes the tour and remembers it, so it does not open by itself again
    function finish() {
        open = false
        if (!done) { done = true; save() }
    }

    function go(i) {
        if (i < 0 || i >= steps.length || i === step) return
        dir = i > step ? 1 : -1
        step = i
    }
    function next() { if (last) finish(); else go(step + 1) }
    function back() { go(step - 1) }

    // True while any menu of the shell is open (a menu opened with "Try")
    readonly property bool menuOpen: UiState.launcherOpen || UiState.wallpaperOpen || UiState.powerOpen
        || UiState.captureOpen || UiState.recMenuOpen || Style.pickerOpen || Style.variantOpen || Appearance.pickerOpen

    // "Try" button: runs a shell command (qs ipc call ...). If it opens a menu, the tour steps aside until it closes.
    function run(args, opensMenu) {
        Quickshell.execDetached(["qs", "ipc", "call"].concat(args))
        if (opensMenu) {
            hidden = true
            backTimer.ticks = 0
            backTimer.restart()
        }
    }

    Timer {
        id: backTimer
        property int ticks: 0
        interval: 300
        repeat: true
        onTriggered: {
            ticks++
            if (ticks < 3) return           // give the menu time to open
            if (!root.menuOpen || ticks > 400) { root.hidden = false; stop() }
        }
    }

    // First start: opens after the "hello" quote has finished, and never over the lock screen
    Timer {
        id: firstRun
        interval: 11000
        repeat: true
        onTriggered: {
            if (UiState.locked) return
            stop()
            if (!root.done) root.show()
        }
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", stateDir])
        let seen = false
        try { seen = JSON.parse(store.text()).done === true } catch (e) {}
        done = seen
        if (!seen) firstRun.start()
    }
}
