import QtQuick
import "../../common/functions/Extras.js" as X
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sekai.phone

// Web search, made for the phone: a mobile browser's look instead of a desktop
// window. An address pill on top shows the real URL Enter will open, the
// "page" under it shows what you are searching for (with live suggestions when
// they are on), and the search engines sit along the bottom like the favourites
// of a phone's browser: six round icons, the one in use lifted.
//
//   Enter          opens it in your default browser (xdg-open); a URL like
//                  github.com/foo is opened directly instead of searched
//   Up / Down      pick a suggestion instead of what you typed
//   Tab / click    switch search engine
//
// Triggers: "web foo", "? foo", "g foo" (Google), "ddg", "yt", "gh", "wiki",
// "arch". Pure UI; ExtrasSource.qml fetches suggestions and opens the URL.
PhoneCard {
    id: root

    property string arg: ""
    property int engine: 0
    property var engines: X.ENGINES
    property var suggestions: []

    // -1 = what you typed; 0.. = a suggestion
    property int sel: -1

    signal openRequested(string url)
    signal engineChosen(int index)

    readonly property string q: arg.trim()
    readonly property bool isUrl: q !== "" && X.looksLikeUrl(q)
    readonly property var eng: engines[engine]
    readonly property var accents: ["#de5833", "#4285f4", "#ff0033", "#24292f", "#555473", "#1793d1"]
    readonly property color accent: accents[engine % accents.length]
    readonly property color darkInk: Theme.colBorder

    // ===== the room =====
    readonly property real addrH: 64
    readonly property real favH: 96
    readonly property real rowH: 56
    // As many suggestions as the page has room for (the first row is what you typed).
    readonly property int maxRows: Math.max(1, Math.floor((pageH - addrH - favH - 28 + 8) / (rowH + 8)))
    readonly property var shown: suggestions.slice(0, Math.min(5, maxRows - 1))

    // what Enter would open right now
    readonly property string queryToOpen: sel >= 0 && sel < shown.length ? shown[sel] : q
    readonly property string targetUrl: {
        if (q === "")
            return eng.home
        if (isUrl && sel < 0)
            return X.urlFor(q)
        return X.searchUrl(engine, queryToOpen)
    }

    onSuggestionsChanged: sel = -1
    onArgChanged: sel = -1

    function nav(dx, dy) {
        if (dy === 0 && dx !== 0)
            return
        sel = Math.max(-1, Math.min(shown.length - 1, sel + dy))
    }

    function activate() {
        openRequested(targetUrl)
    }

    // ===== the address pill =====
    PhonePlate {
        id: address

        width: root.pageW
        height: root.addrH
        radius: (height - shadow) / 2

        // the engine's round icon
        Rectangle {
            id: favicon
            x: 11
            anchors.verticalCenter: parent.verticalCenter
            width: 42
            height: 42
            radius: 21
            color: root.accent

            Text {
                anchors.centerIn: parent
                text: root.eng.name.charAt(0)
                color: "#ffffff"
                font.family: Theme.fontFamily
                font.pixelSize: 24
                font.weight: Font.ExtraBold
            }
        }

        // host in full ink, the rest softer, like a real address bar
        Text {
            anchors.left: favicon.right
            anchors.leftMargin: 14
            anchors.right: openIcon.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            textFormat: Text.StyledText
            color: Theme.pInkSub
            font.family: Theme.fontFamily
            font.pixelSize: 22
            font.weight: Font.Bold
            text: {
                const u = root.targetUrl.replace(/^https?:\/\//, "")
                const slash = u.indexOf("/")
                const host = slash < 0 ? u : u.slice(0, slash)
                const rest = slash < 0 ? "" : u.slice(slash)
                const esc = s => s.replace(/&/g, "&amp;").replace(/</g, "&lt;")
                return "<font color='" + Theme.pInk + "'>" + esc(host) + "</font>" + esc(rest)
            }
        }

        MaterialIcon {
            id: openIcon
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            name: "arrow_forward"
            size: 28
            weight: 700
            color: Theme.pInk
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.activate()
        }
    }

    // ===== the page: what you typed, then suggestions =====
    Column {
        id: results

        y: root.addrH + 14
        width: root.pageW
        spacing: 8
        visible: root.q !== ""

        Repeater {
            model: [{ text: root.q, main: true }].concat(root.shown.map(s => ({ text: s, main: false })))

            delegate: Item {
                id: resRow

                required property var modelData
                required property int index

                readonly property bool on: root.sel === index - 1

                width: results.width
                height: root.rowH

                PhonePlate {
                    anchors.fill: parent
                    radius: (height - shadow) / 2
                    borderW: resRow.on ? 5 : 3
                    fill: resRow.on ? Theme.accentMint : (resArea.containsMouse ? Theme.pSurfaceHover : Theme.pSurface)

                    MaterialIcon {
                        id: rowIcon
                        x: 20
                        anchors.verticalCenter: parent.verticalCenter
                        name: resRow.modelData.main ? (root.isUrl ? "language" : "search") : "north_west"
                        size: 26
                        weight: 700
                        color: resRow.modelData.main ? (resRow.on ? root.darkInk : root.accent) : (resRow.on ? root.darkInk : Theme.pInkSub)
                    }

                    Text {
                        anchors.left: rowIcon.right
                        anchors.leftMargin: 14
                        anchors.right: parent.right
                        anchors.rightMargin: 24
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        textFormat: Text.StyledText
                        color: resRow.on ? root.darkInk : Theme.pInk
                        font.family: Theme.fontFamily
                        font.pixelSize: 20
                        font.weight: Font.Bold
                        text: {
                            const esc = s => s.replace(/&/g, "&amp;").replace(/</g, "&lt;")
                            if (resRow.modelData.main)
                                return root.isUrl ? "Go to <b>" + esc(root.q) + "</b>"
                                                  : "Search " + esc(root.eng.name) + " for <b>" + esc(root.q) + "</b>"
                            return esc(resRow.modelData.text)
                        }
                    }
                }

                MouseArea {
                    id: resArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.sel = resRow.index - 1
                        root.activate()
                    }
                }
            }
        }
    }

    // nothing typed yet: the engine's name, big, and how this works
    Column {
        visible: root.q === ""
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.addrH + Math.max(14, (root.pageH - root.addrH - root.favH - height) / 2.4)
        spacing: 18

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 96
            height: 96
            radius: 48
            color: root.accent
            border.width: 4
            border.color: Theme.pLine

            Text {
                anchors.centerIn: parent
                text: root.eng.name.charAt(0)
                color: "#ffffff"
                font.family: Theme.fontFamily
                font.pixelSize: 54
                font.weight: Font.ExtraBold
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.eng.name
            color: Theme.pInk
            font.family: Theme.fontFamily
            font.pixelSize: 36
            font.weight: Font.ExtraBold
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            color: Theme.pInkSub
            font.family: Theme.fontFamily
            font.pixelSize: 20
            font.weight: Font.Bold
            lineHeight: 1.3
            text: "Type what to search for.\nTab switches search engine \u00b7 a web address opens directly."
        }
    }

    // ===== the favourites: the engines =====
    Row {
        id: favs

        y: root.pageH - root.favH
        width: root.pageW

        Repeater {
            model: root.engines

            delegate: Item {
                id: fav

                required property var modelData
                required property int index

                readonly property bool on: index === root.engine
                readonly property bool hot: favArea.containsMouse || on

                width: root.pageW / root.engines.length
                height: root.favH

                Item {
                    id: disc

                    x: (parent.width - 60) / 2
                    y: 8 - (fav.hot ? 4 : 0)
                    width: 60
                    height: 60
                    scale: favArea.pressed ? 0.93 : 1

                    Behavior on y {
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: 110
                            easing.type: Easing.OutCubic
                        }
                    }

                    // The hard shadow the phone's buttons all have.
                    Rectangle {
                        x: 4
                        y: 4 + (fav.hot ? 4 : 0)
                        width: 60
                        height: 60
                        radius: 30
                        color: Theme.pLineShadow
                        antialiasing: true
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 30
                        color: root.accents[fav.index % root.accents.length]
                        border.width: fav.on ? 5 : 3
                        border.color: Theme.pLine
                        antialiasing: true

                        Text {
                            anchors.centerIn: parent
                            text: fav.modelData.name.charAt(0)
                            color: "#ffffff"
                            font.family: Theme.fontFamily
                            font.pixelSize: 30
                            font.weight: Font.ExtraBold
                        }
                    }
                }

                Text {
                    x: -4
                    y: 8 + 60 + 12
                    width: parent.width + 8
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: fav.modelData.name
                    color: Theme.pInk
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.weight: fav.on ? Font.ExtraBold : Font.Bold
                    opacity: fav.on ? 1 : 0.75
                }

                MouseArea {
                    id: favArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.engineChosen(fav.index)
                }
            }
        }
    }
}
