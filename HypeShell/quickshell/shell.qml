//@ pragma Env QSG_RENDER_LOOP=threaded
//@ pragma Env QT_MEDIA_BACKEND=ffmpeg
//@ pragma Env QT_FFMPEG_DECODING_HW_DEVICE_TYPES=vaapi
//@ pragma Env QT_FFMPEG_ENCODING_HW_DEVICE_TYPES=vaapi
//@ pragma Env QT_WAYLAND_DISABLE_WINDOWDECORATION=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Material
//@ pragma UseQApplication
//@ pragma AppId com.hypeshell.shell

import QtQuick
import Quickshell

ShellRoot {
    id: entrypoint

    readonly property bool runGreeter: Quickshell.env("HYPE_RUN_GREETER") === "1" || Quickshell.env("HYPE_RUN_GREETER") === "true"
    readonly property bool disableHotReload: Quickshell.env("HYPE_DISABLE_HOT_RELOAD") === "1" || Quickshell.env("HYPE_DISABLE_HOT_RELOAD") === "true"

    Component.onCompleted: {
        Quickshell.watchFiles = !disableHotReload;
    }

    Loader {
        id: hypeShellLoader
        asynchronous: false
        sourceComponent: HYPEShell {}
        active: !entrypoint.runGreeter
    }

    Loader {
        id: hypeGreeterLoader
        asynchronous: false
        sourceComponent: HYPEGreeter {}
        active: entrypoint.runGreeter
    }
}
