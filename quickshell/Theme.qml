// Theme.qml
pragma Singleton
import QtQuick

QtObject {
    property bool isDark: true
    
    // Dynamic palette
    property color bg: isDark ? "#1e1e2e" : "#eff1f5"
    property color surface: isDark ? "#313244" : "#e6e9ef"
    property color text: isDark ? "#cdd6f4" : "#4c4f69"
    property color textMuted: isDark ? "#a6adc8" : "#8c8fa1"
    property color accent: isDark ? "#89b4fa" : "#1e66f5"
    property color accentAlt: isDark ? "#a6e3a1" : "#40a02b"
    property color activeBg: isDark ? "#45475a" : "#ccd0da"
    
    function toggle() {
        isDark = !isDark;
    }
}
