pragma Singleton
import QtQuick

QtObject {
    id: theme
    readonly property color background: '#0F0F1E'
    readonly property color border: '#22223B'
    readonly property color borderFocused: Qt.lighter(primary, 1.2)
    readonly property color foreground: '#F2E9E4'
    readonly property color foregroundMuted: Qt.darker(foreground, 2.5)
    readonly property color primary: '#9A8C98'
    readonly property color primaryMuted: Qt.darker(primary, 2.5)
    readonly property color secondary: '#C9ADA7'
    readonly property color secondaryMuted: Qt.darker(secondary, 2.5)

    readonly property color warning: '#D4C87D'
    readonly property color success: '#7EC87E'
    readonly property color error: '#D16C8B'

    readonly property color surfaceBase: '#1A1A2E'
    readonly property color surfaceContainer: '#22223B'
    readonly property color surfaceText: foreground
    readonly property color surfaceTextVariant: '#C9ADA7'
    readonly property color surfaceBorder: Qt.lighter(surfaceBase, 1.2)
    readonly property color surfaceAccent: primaryMuted

    readonly property string fontMono: "JetBrainsMono Nerd Font"
    readonly property string fontUI: "Inter"
    readonly property string fontIcon: "JetBrainsMono Nerd Font"
    readonly property int fontSize: 13
    readonly property int fontSizeHeading: 18
    readonly property int fontSizeSubheading: 14
    readonly property int fontSizeCaption: 11
    readonly property int radius: 6
    readonly property int radiusSm: Math.round(radius * 0.5)
    readonly property int radiusLg: radius * 2
    readonly property int radiusPanel: 12
    readonly property int spacingXs: 4
    readonly property int spacingSm: 8
    readonly property int spacingMd: 12
    readonly property int spacingLg: 16
    readonly property int spacingXl: 20
    readonly property real dividerOpacity: 0.4
    readonly property real popupShadowBlur: 1.0
    readonly property real popupShadowOffset: 10
    readonly property real popupShadowOpacity: 0.28
}






