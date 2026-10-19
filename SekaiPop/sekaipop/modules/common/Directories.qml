pragma Singleton
import QtQuick
import Quickshell

// === shell paths ===
// Where the shell's own files live. Every file that points at a script, a
// shader or a bundled asset goes through here, so moving a folder around only
// needs a change in this one place.
Singleton {
    id: root

    readonly property string shell: Quickshell.shellDir
    readonly property string scripts: shell + "/scripts"
    readonly property string shaders: shell + "/shaders"
    readonly property string assets: shell + "/assets"

    // "state/todo-state.sh" -> /path/to/shell/scripts/state/todo-state.sh
    function script(rel) { return scripts + "/" + rel }

    // "images/default-wallpaper.png" -> /path/to/shell/assets/images/default-wallpaper.png
    function asset(rel) { return assets + "/" + rel }

    // "sekai_blocks.frag.qsb" -> file:///path/to/shell/shaders/sekai_blocks.frag.qsb
    function shader(rel) { return Qt.resolvedUrl(shaders + "/" + rel) }
}
