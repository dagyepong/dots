// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C A R D   H E A D I N G                                                │
// │   a group's title on a card, in the height of a row                      │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../theme"

// Small capitals over a group of rows, sat on the row's baseline so the gap
// above it reads as the break between groups.
Text {
    Layout.fillWidth: true
    Layout.preferredHeight: Theme.cardRow
    verticalAlignment: Text.AlignBottom
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSizeLabel
    font.weight: Font.DemiBold
    font.letterSpacing: 0.8
    font.capitalization: Font.AllUppercase
    color: Theme.textMuted
}
