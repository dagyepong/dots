pragma Singleton
import QtQuick
import Quickshell

// The motion of wearing a desktop preset (services/DesktopPresetService.qml).
//
// When a preset is going to change the bar or the dock, or switch a desktop
// widget to another variant (the clock's design; the visualizer's style, colours,
// size or direction), they don't just jump:
//   1. begin()    the bar / dock slide off their edge (barOut / dockOut true); a
//                 widget that is changing variant or being switched off shrinks
//                 away (clockOut, visualizerOut, usercardOut ... true),
//   2. the preset is put on while they are away,
//   3. release()  they slide back in, in their new look or on their new edge.
// A bar or dock that has to be built from scratch (a new edge builds a fresh
// window, see shell.qml) is created while `barBusy` / `dockBusy` is still true;
// it starts away from its edge and slides in by itself.
//
// Bar.qml, Dock.qml, ClockWidget.qml and VisualizerWidget.qml read these. The
// widgets also glide to a new spot on their own (see `follow` in each widget).
Singleton {
    id: root

    // True while the bar / dock should be off their edge.
    property bool barOut: false
    property bool dockOut: false

    // True while a desktop widget's card should be shrunk away because the
    // preset changes its variant or switches it off.
    property bool clockOut: false
    property bool visualizerOut: false
    property bool usercardOut: false
    property bool weathercardOut: false
    property bool todoOut: false

    // True from begin() until a little after release(): a window created in this
    // span arrives sliding in instead of just appearing.
    property bool barBusy: false
    property bool dockBusy: false

    // How long the slide away takes; DesktopPresetService waits this long before
    // it puts the preset on.
    readonly property int outMs: 190
    readonly property int inMs: 380

    // plan: { bar, dock, clock, visualizer, usercard, weathercard, todo }, each true for
    // what is going to change.
    function begin(plan) {
        busyTimer.stop()
        root.barOut = plan.bar === true
        root.barBusy = root.barOut
        root.dockOut = plan.dock === true
        root.dockBusy = root.dockOut
        root.clockOut = plan.clock === true
        root.visualizerOut = plan.visualizer === true
        root.usercardOut = plan.usercard === true
        root.weathercardOut = plan.weathercard === true
        root.todoOut = plan.todo === true
    }

    function release() {
        root.barOut = false
        root.dockOut = false
        root.clockOut = false
        root.visualizerOut = false
        root.usercardOut = false
        root.weathercardOut = false
        root.todoOut = false
        busyTimer.restart()
    }

    Timer {
        id: busyTimer
        interval: 2000
        onTriggered: {
            root.barBusy = false
            root.dockBusy = false
        }
    }
}
