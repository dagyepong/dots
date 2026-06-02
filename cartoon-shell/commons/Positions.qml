pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.commons

Singleton {
    function anchorsBar() {
        return {
            left: (Settings.bar.position === "left" || Settings.bar.position === "top" || Settings.bar.position === "bottom") ? true : false,
            right: (Settings.bar.position === "right" || Settings.bar.position === "top" || Settings.bar.position === "bottom") ? true : false,
            top: (Settings.bar.position === "top" || Settings.bar.position === "left" || Settings.bar.position === "right") ? true : false,
            bottom: (Settings.bar.position === "bottom" || Settings.bar.position === "left" || Settings.bar.position === "right") ? true : false
        };
    }
}
