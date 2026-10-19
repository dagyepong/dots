import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common

// The utility keys themselves, one list for both places they show up: inside the
// bar's long pill (UtilButtons.qml, a row or a column) and inside the flyout card
// of a short standing bar (UtilPopup.qml, a small keypad). What each key DOES and
// what state it shows lives in UtilButtons (`src`); this file is only the list,
// so the two can't drift apart. Every key still follows its Settings -> Bar
// switch (`util.*`).
//
//   UtilKeys { src: utilButtons; columns: 100 }   // one row
//   UtilKeys { src: utilButtons; columns: 1 }     // one column
//   UtilKeys { src: utilButtons; columns: 4; keyWidth: 44; keyHeight: 36; iconSize: 24 }
GridLayout {
    id: grid

    // The UtilButtons that owns the actions and the state (mic, profile, recording...).
    property var src: null

    // Key size (design px) and glyph size; the bar's own pill uses the defaults.
    property real keyWidth: 30
    property real keyHeight: 24
    property int iconSize: 20

    // A key that starts something (a picker, the recorder, the wallpapers) asks the
    // flyout to go away; a key that only flips a state (mic, dark mode...) does not,
    // so you can see it change.
    signal closeRequested()

    // The name of the key under the pointer ("" when none), for the flyout's caption.
    readonly property string hint: {
        for (let i = 0; i < grid.children.length; i++) {
            const k = grid.children[i]
            if (k.visible && k.hovered)
                return k.label
        }
        return ""
    }

    columnSpacing: 0
    rowSpacing: 0

    UtilKey {
        visible: SettingsService.flag("util.screenshot")
        label: "Screen snip"
        icon: "screenshot_region"
        keyWidth: grid.keyWidth; keyHeight: grid.keyHeight; iconSize: grid.iconSize
        onClicked: {
            grid.src.screenshotRegion()
            grid.closeRequested()
        }
    }

    UtilKey {
        visible: SettingsService.flag("util.colorPicker")
        label: "Color picker"
        icon: "colorize"
        keyWidth: grid.keyWidth; keyHeight: grid.keyHeight; iconSize: grid.iconSize
        onClicked: {
            grid.src.pickColor()
            grid.closeRequested()
        }
    }

    UtilKey {
        visible: SettingsService.flag("util.keyboard")
        label: "On-screen keyboard"
        icon: "keyboard"
        active: KeyboardService.running
        keyWidth: grid.keyWidth; keyHeight: grid.keyHeight; iconSize: grid.iconSize
        onClicked: KeyboardService.toggle()
    }

    UtilKey {
        visible: SettingsService.flag("util.mic")
        label: grid.src && grid.src.micMuted ? "Unmute mic" : "Mute mic"
        icon: grid.src && grid.src.micMuted ? "mic_off" : "mic"
        active: grid.src ? grid.src.micMuted : false
        keyWidth: grid.keyWidth; keyHeight: grid.keyHeight; iconSize: grid.iconSize
        onClicked: grid.src.toggleMic()
    }

    UtilKey {
        visible: SettingsService.flag("util.darkMode")
        label: "Dark / light"
        icon: ThemeService.mode === "light" ? "light_mode" : (ThemeService.darker ? "bedtime" : "dark_mode")
        keyWidth: grid.keyWidth; keyHeight: grid.keyHeight; iconSize: grid.iconSize
        onClicked: grid.src.toggleDarkMode()
    }

    UtilKey {
        visible: SettingsService.flag("util.profile")
        label: "Power profile"
        icon: grid.src ? grid.src.profileIcon : "balance"
        active: grid.src ? grid.src.performanceOn : false
        keyWidth: grid.keyWidth; keyHeight: grid.keyHeight; iconSize: grid.iconSize
        onClicked: grid.src.cycleProfile()
    }

    UtilKey {
        visible: SettingsService.flag("util.record")
        label: grid.src && grid.src.recording ? "Stop recording" : "Record screen"
        icon: grid.src && grid.src.recording ? "stop" : "screen_record"
        active: grid.src ? grid.src.recording : false
        activeFill: "#ff8fb3"
        keyWidth: grid.keyWidth; keyHeight: grid.keyHeight; iconSize: grid.iconSize
        onClicked: {
            grid.src.toggleRecording()
            grid.closeRequested()
        }
    }

    UtilKey {
        visible: SettingsService.flag("util.wallpapers")
        label: "Wallpapers"
        icon: "wallpaper"
        keyWidth: grid.keyWidth; keyHeight: grid.keyHeight; iconSize: grid.iconSize
        onClicked: {
            grid.src.wallpapersRequested()
            grid.closeRequested()
        }
    }
}
