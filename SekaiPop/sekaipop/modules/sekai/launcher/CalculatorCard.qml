import QtQuick
import "Calc.js" as Calc
import qs.modules.common
import qs.modules.sekai.phone

// The calculator of the Apps screen, made for the phone: it is drawn at the
// page's own size (550 wide, as tall as the page is), with big round keys
// like a phone's calculator, and nothing around it. It pops up when you type
// "calc" / "calculator" (or just a sum like 2+2) in the search box. It is a
// real one: press the keys, or type in the search box above -- both edit the
// same line (the text after "calc "), so mixing them just works.
//
// Pure UI. It shows `expr`, evaluates it live with Calc.js, and reports key
// presses as signals; LauncherExtras.qml applies them to the search box and
// keeps the history.
//
//   =       works the sum out and leaves the answer in the line, so you can
//           carry on with it; Enter / = again copies it and closes.
//   copy    the round key in the display's corner: the answer to the clipboard
//           (and closes).
//   history the faded lines at the top of the display; tap one to bring it back.
//           The taller the page, the more of them show.
PhoneCard {
    id: root

    property string expr: ""
    // Newest last: [{ expr: "12*3", result: "36" }, ...]
    property var history: []

    signal insert(string text)
    signal backspace()
    signal clearAll()
    signal equals()
    signal copyResult()
    signal useHistory(int index)

    readonly property var res: Calc.evaluate(root.expr)
    readonly property bool hasAnswer: root.res.ok

    // Enter is not a key on the pad: LauncherExtras asks for it here.
    function activate() {
        root.equals()
    }

    // ===== the room =====
    readonly property real gap: 12
    readonly property real vgap: 8
    readonly property real keyW: (pageW - 3 * gap) / 4
    readonly property real fnH: 48
    // The keys grow with the page, up to a point; the display takes the rest.
    readonly property real keyH: Math.max(50, Math.min(92, (pageH - 170 - 12 - fnH - 5 * vgap) / 5))
    readonly property real padH: fnH + 5 * keyH + 5 * vgap
    readonly property real displayH: pageH - padH - 12

    // pale key, operator key (cyan), pink key, "=" (cyan -> mint like an ON tile)
    readonly property color fnFill: Theme.pSurfaceHover
    readonly property color opFill: Theme.accentCyan
    readonly property color clearFill: ScrapbookTheme.tapePink
    readonly property color darkInk: Theme.colBorder

    Gradient {
        id: equalsGradient
        GradientStop { position: 0.0; color: Theme.accentCyan }
        GradientStop { position: 1.0; color: Theme.accentMint }
    }

    // ===== the display =====
    PhonePlate {
        id: display

        width: root.pageW
        height: root.displayH
        radius: 34

        // How many of the last sums fit above the line being typed.
        readonly property int histRows: Math.max(0, Math.min(6, Math.floor((root.displayH - 134) / 30)))
        readonly property var histShown: root.history.slice(-Math.max(1, histRows))

        // the last sums, faded; tap one to bring it back
        Column {
            visible: display.histRows > 0
            anchors.top: parent.top
            anchors.topMargin: 16
            anchors.left: parent.left
            anchors.leftMargin: 84
            anchors.right: parent.right
            anchors.rightMargin: 26
            spacing: 2

            Repeater {
                model: display.histRows > 0 ? display.histShown : []
                delegate: Item {
                    required property var modelData
                    required property int index

                    width: parent.width
                    height: 28

                    Text {
                        anchors.fill: parent
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideLeft
                        text: Calc.pretty(modelData.expr) + "  =  " + Calc.group(modelData.result)
                        color: Theme.pInkSub
                        font.family: Theme.fontFamily
                        font.pixelSize: 20
                        font.weight: Font.Bold
                        opacity: histArea.containsMouse ? 1 : 0.8
                    }

                    MouseArea {
                        id: histArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.useHistory(root.history.length - display.histShown.length + index)
                    }
                }
            }
        }

        // copy the answer
        PhoneKey {
            x: 14
            y: 14
            width: 58
            height: 52
            icon: "content_copy"
            iconSize: 24
            fill: Theme.accentMint
            ink: root.darkInk
            enabled: root.hasAnswer
            onClicked: root.copyResult()
        }

        // the line being typed
        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 26
            anchors.rightMargin: 26
            y: parent.height - 4 - 14 - 64 - 40
            height: 40
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideLeft
            text: root.expr === "" ? "0" : Calc.pretty(root.expr)
            color: root.expr === "" ? Theme.pInkSub : Theme.pInk
            font.family: Theme.fontFamily
            font.pixelSize: 32
            font.weight: Font.DemiBold
        }

        // the live answer
        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 26
            anchors.rightMargin: 26
            y: parent.height - 4 - 14 - 64
            height: 64
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 26
            text: root.res.ok ? "= " + Calc.group(root.res.text) : (root.res.error !== "" && root.expr !== "" ? root.res.error : "")
            color: root.res.ok ? Theme.pInk : ScrapbookTheme.accentPink
            font.family: Theme.fontFamily
            font.pixelSize: root.res.ok ? 58 : 22
            font.weight: Font.ExtraBold
        }
    }

    // ===== small function row: ( ) ^ sqrt pi =====
    Row {
        x: 0
        y: display.height + 12
        spacing: root.gap

        Repeater {
            model: [
                { l: "(", v: "(" }, { l: ")", v: ")" }, { l: "x\u207f", v: "^" },
                { l: "\u221a", v: "sqrt(" }, { l: "\u03c0", v: "pi" }
            ]
            delegate: PhoneKey {
                required property var modelData
                width: (root.pageW - 4 * root.gap) / 5
                height: root.fnH
                fill: root.fnFill
                fontSize: 24
                label: modelData.l
                onClicked: root.insert(modelData.v)
            }
        }
    }

    // ===== the keys =====
    // col, row, span (columns it covers), kind, and what it does.
    readonly property var keys: [
        { l: "C", kind: "clear", col: 0, row: 0, act: "clear" },
        { l: "", icon: "backspace", kind: "fn", col: 1, row: 0, act: "back" },
        { l: "%", kind: "fn", col: 2, row: 0, v: "%" },
        { l: "\u00f7", kind: "op", col: 3, row: 0, v: "/" },

        { l: "7", col: 0, row: 1, v: "7" }, { l: "8", col: 1, row: 1, v: "8" },
        { l: "9", col: 2, row: 1, v: "9" }, { l: "\u00d7", kind: "op", col: 3, row: 1, v: "*" },

        { l: "4", col: 0, row: 2, v: "4" }, { l: "5", col: 1, row: 2, v: "5" },
        { l: "6", col: 2, row: 2, v: "6" }, { l: "\u2212", kind: "op", col: 3, row: 2, v: "-" },

        { l: "1", col: 0, row: 3, v: "1" }, { l: "2", col: 1, row: 3, v: "2" },
        { l: "3", col: 2, row: 3, v: "3" }, { l: "+", kind: "op", col: 3, row: 3, v: "+" },

        { l: "0", col: 0, row: 4, span: 2, v: "0" },
        { l: ".", col: 2, row: 4, v: "." },
        { l: "=", kind: "go", col: 3, row: 4, act: "equals" }
    ]

    Repeater {
        model: root.keys

        delegate: PhoneKey {
            id: k

            required property var modelData

            readonly property string kind: modelData.kind || ""

            x: modelData.col * (root.keyW + root.gap)
            y: display.height + 12 + root.fnH + root.vgap + modelData.row * (root.keyH + root.vgap)
            width: (modelData.span || 1) * root.keyW + ((modelData.span || 1) - 1) * root.gap
            height: root.keyH

            label: modelData.l
            icon: modelData.icon || ""
            fontSize: kind === "op" || kind === "go" ? 40 : 34
            iconSize: 32
            autoRepeat: modelData.act === "back"
            borderW: kind === "go" ? 4 : 3
            fill: kind === "op" ? root.opFill
                : kind === "clear" ? root.clearFill
                : kind === "fn" ? root.fnFill
                : Theme.pSurface
            fillGradient: kind === "go" ? equalsGradient : null
            ink: kind === "op" || kind === "clear" || kind === "go" ? root.darkInk : Theme.pInk

            onClicked: {
                switch (modelData.act) {
                case "clear": root.clearAll(); break
                case "back": root.backspace(); break
                case "equals": root.equals(); break
                default: root.insert(modelData.v)
                }
            }
        }
    }
}
