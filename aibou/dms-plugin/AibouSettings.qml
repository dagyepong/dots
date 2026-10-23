// Aibou reads these keys from plugin_settings.json itself. Defaults here must
// match Aibou's own fallbacks, because DMS only saves values that were changed.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root

    // where Aibou itself lives: found over its helper `aibou` (a link into
    // the repository), so this page works however the plugin was installed
    property string repoDir: ""
    property Process repoProc: Process {
        running: true
        command: ["sh", "-c", "p=$(command -v aibou || echo \"$HOME/.local/bin/aibou\"); [ -e \"$p\" ] && dirname \"$(dirname \"$(readlink -f \"$p\")\")\""]
        stdout: StdioCollector { onStreamFinished: root.repoDir = text.trim() }
    }
    pluginId: "aibou"

    // What was changed in the chat (activity, figures more or fewer) Aibou keeps
    // in its own state instead of writing DMS's file. Opening this page takes it
    // over into DMS's settings, so the page and DMS show it too.
    property var chosen: null
    property FileView chosenFile: FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/aibou/chosen.json"
        onLoaded: {
            try {
                root.chosen = JSON.parse(text());
            } catch (e) {
                root.chosen = null;
            }
            root.takeChosen();
        }
    }
    onPluginServiceChanged: Qt.callLater(takeChosen)
    function takeChosen() {
        if (!root.chosen || !root.pluginService)
            return;
        const c = root.chosen;
        root.chosen = null;
        for (const k in c) {
            if (c[k] && c[k].value !== undefined)
                root.saveValue(k, c[k].value);
        }
    }

    readonly property var skinOptions: [
        { label: "Kuro", value: "kuro" },
        { label: "Mochi", value: "mochi" },
        { label: "Shiro", value: "shiro" },
        { label: "Momo", value: "momo" },
        { label: "Robo", value: "robo" },
        { label: "Bao", value: "bao" },
        { label: "Neko", value: "neko" },
        { label: "Kumo", value: "kumo" },
        { label: "Tako", value: "tako" },
        { label: "Hiyoko", value: "hiyoko" },
        { label: "Arai", value: "arai" }
    ]

    readonly property var tintOptions: [
        { label: I18n.trFor("aibou", "His own"), value: "own" },
        { label: I18n.trFor("aibou", "Accent colour"), value: "accent" },
        { label: I18n.trFor("aibou", "Fixed colour"), value: "custom" }
    ]

    readonly property var extraSkinOptions: [{ label: I18n.trFor("aibou", "None"), value: "none" }].concat(skinOptions)

    // a row of pictures of the chosen figure (made by shell/thumbs.qml in Aibou's repository)
    component Preview: Flow {
        id: pv
        property string key: "skin1"
        readonly property string skin: {
            SettingsData.pluginSettings;
            return String(SettingsData.getPluginSetting("aibou", key, key === "skin1" ? "kuro" : "none"));
        }
        readonly property string dir: root.repoDir ? "file://" + root.repoDir + "/shell/thumbs/" + skin + "/" : ""
        visible: skin !== "none" && skin !== "" && dir !== ""
        width: parent ? parent.width : 400
        spacing: Theme.spacingS
        Repeater {
            model: [["neutral", "Calm"], ["happy3", "Happy"], ["angry3", "Angry"], ["scared2", "Scared"],
                    ["blush3", "Blushing"], ["grapple", "Grappling gun"], ["banana", "Banana"], ["dock", "In the frame"]]
            Rectangle {
                required property var modelData
                width: Theme.iconSize * 3.8; height: Theme.iconSize * 3.5; radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                Image {
                    x: 2; y: 2; width: parent.width - 4; height: parent.height - 20
                    source: pv.dir + parent.modelData[0] + ".png"
                    sourceClipRect: Qt.rect(30, 40, 280, 202)
                    fillMode: Image.PreserveAspectFit
                    smooth: true; asynchronous: true
                }
                StyledText {
                    width: parent.width; y: parent.height - 18
                    horizontalAlignment: Text.AlignHCenter
                    text: I18n.trFor("aibou", parent.modelData[1])
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    elide: Text.ElideRight
                }
            }
        }
    }

    StyledText {
        width: parent ? parent.width : implicitWidth
        text: I18n.trFor("aibou", "Usage")
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    StyledText {
        width: parent ? parent.width : implicitWidth
        text: I18n.trFor("aibou", "At rest Aibou needs under 1 % CPU and about 130 MB of memory. Costs come almost only from movement: every drawn frame costs CPU in Qt and the graphics driver, so they rise with the refresh rate. Figures below were measured at 2560×1600 and 165 Hz on Intel Iris Xe.")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StyledText {
        width: parent ? parent.width : implicitWidth
        bottomPadding: Theme.spacingM
        text: I18n.trFor("aibou", "Shortcuts: Mod+Alt+M bring to front, Mod+Alt+C chat window, Mod+Alt+Z sleep or wake, Mod+Alt+B ball, Mod+Alt+Shift+M on or off.")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StyledText {
        visible: root.repoDir === ""
        width: parent ? parent.width : implicitWidth
        bottomPadding: Theme.spacingM
        text: I18n.trFor("aibou", "Aibou itself is not installed: this plugin is only its switch and settings. Install it from github.com/satoshoe-dev/aibou (see the README there).")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.error
        wrapMode: Text.WordWrap
    }

    StringSetting {
        settingKey: "userName"
        label: I18n.trFor("aibou", "Your name")
        description: I18n.trFor("aibou", "How the figures greet you and talk to you. Empty: the first name of your account.")
        placeholder: I18n.trFor("aibou", "First name")
        defaultValue: ""
    }

    SelectionSetting {
        settingKey: "skin1"
        label: I18n.trFor("aibou", "Main figure")
        description: I18n.trFor("aibou", "Kuro is a dark glass ball with two long eyes, in the colour of the frame. Mochi is a rice cake with a face, Shiro a light ball with long eyes, Momo a peach, Robo a small robot with glowing eyes, Bao a steamed bun, Neko a cat, Kumo a cloud, Tako an octopus, Hiyoko a chick, Arai a raccoon. All cost the same.")
        defaultValue: "kuro"
        options: root.skinOptions
    }

    Preview { key: "skin1" }

    SelectionSetting {
        settingKey: "tint1"
        label: I18n.trFor("aibou", "Colour")
        description: I18n.trFor("aibou", "His own colour, the accent colour (changes along with it) or a fixed colour of your choice. Kuro stays glass and takes the colour as a tint.")
        defaultValue: "own"
        options: root.tintOptions
    }

    ColorSetting {
        settingKey: "tintColor1"
        label: I18n.trFor("aibou", "Fixed colour")
        description: I18n.trFor("aibou", "Used when Colour is set to Fixed colour.")
        defaultValue: "#7aa2f7"
    }

    SelectionSetting {
        settingKey: "skin2"
        label: I18n.trFor("aibou", "Second figure")
        description: I18n.trFor("aibou", "Joins the playground and plays with the others. Each extra figure adds about 2–3 % CPU on average, three awake figures measured about 8.5 %. Mod+Alt+Plus / Minus adds or removes one.")
        defaultValue: "none"
        options: root.extraSkinOptions
    }

    Preview { key: "skin2" }

    SelectionSetting {
        settingKey: "tint2"
        label: I18n.trFor("aibou", "Colour")
        description: I18n.trFor("aibou", "His own colour, the accent colour (changes along with it) or a fixed colour of your choice. Kuro stays glass and takes the colour as a tint.")
        defaultValue: "own"
        options: root.tintOptions
    }

    ColorSetting {
        settingKey: "tintColor2"
        label: I18n.trFor("aibou", "Fixed colour")
        description: I18n.trFor("aibou", "Used when Colour is set to Fixed colour.")
        defaultValue: "#7aa2f7"
    }

    SelectionSetting {
        settingKey: "skin3"
        label: I18n.trFor("aibou", "Third figure")
        description: I18n.trFor("aibou", "Joins the playground and plays with the others. Each extra figure adds about 2–3 % CPU on average, three awake figures measured about 8.5 %. Mod+Alt+Plus / Minus adds or removes one.")
        defaultValue: "none"
        options: root.extraSkinOptions
    }

    Preview { key: "skin3" }

    SelectionSetting {
        settingKey: "tint3"
        label: I18n.trFor("aibou", "Colour")
        description: I18n.trFor("aibou", "His own colour, the accent colour (changes along with it) or a fixed colour of your choice. Kuro stays glass and takes the colour as a tint.")
        defaultValue: "own"
        options: root.tintOptions
    }

    ColorSetting {
        settingKey: "tintColor3"
        label: I18n.trFor("aibou", "Fixed colour")
        description: I18n.trFor("aibou", "Used when Colour is set to Fixed colour.")
        defaultValue: "#7aa2f7"
    }

    SelectionSetting {
        settingKey: "skin4"
        label: I18n.trFor("aibou", "Fourth figure")
        description: I18n.trFor("aibou", "Joins the playground and plays with the others. Each extra figure adds about 2–3 % CPU on average, three awake figures measured about 8.5 %. Mod+Alt+Plus / Minus adds or removes one.")
        defaultValue: "none"
        options: root.extraSkinOptions
    }

    Preview { key: "skin4" }

    SelectionSetting {
        settingKey: "tint4"
        label: I18n.trFor("aibou", "Colour")
        description: I18n.trFor("aibou", "His own colour, the accent colour (changes along with it) or a fixed colour of your choice. Kuro stays glass and takes the colour as a tint.")
        defaultValue: "own"
        options: root.tintOptions
    }

    ColorSetting {
        settingKey: "tintColor4"
        label: I18n.trFor("aibou", "Fixed colour")
        description: I18n.trFor("aibou", "Used when Colour is set to Fixed colour.")
        defaultValue: "#7aa2f7"
    }

    SelectionSetting {
        settingKey: "skin5"
        label: I18n.trFor("aibou", "Fifth figure")
        description: I18n.trFor("aibou", "Joins the playground and plays with the others. Each extra figure adds about 2–3 % CPU on average, three awake figures measured about 8.5 %. Mod+Alt+Plus / Minus adds or removes one.")
        defaultValue: "none"
        options: root.extraSkinOptions
    }

    Preview { key: "skin5" }

    SelectionSetting {
        settingKey: "tint5"
        label: I18n.trFor("aibou", "Colour")
        description: I18n.trFor("aibou", "His own colour, the accent colour (changes along with it) or a fixed colour of your choice. Kuro stays glass and takes the colour as a tint.")
        defaultValue: "own"
        options: root.tintOptions
    }

    ColorSetting {
        settingKey: "tintColor5"
        label: I18n.trFor("aibou", "Fixed colour")
        description: I18n.trFor("aibou", "Used when Colour is set to Fixed colour.")
        defaultValue: "#7aa2f7"
    }

    SelectionSetting {
        settingKey: "outline"
        label: I18n.trFor("aibou", "Outline")
        description: I18n.trFor("aibou", "A thin ring around him and his hands. Also drawn over the dome when he melts into the frame.")
        defaultValue: "off"
        options: [
            { label: I18n.trFor("aibou", "None"), value: "off" },
            { label: I18n.trFor("aibou", "Accent colour"), value: "accent" }
        ]
    }

    ToggleSetting {
        settingKey: "hands"
        label: I18n.trFor("aibou", "Hands")
        description: I18n.trFor("aibou", "Small balls as hands. Barely measurable.")
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "gaze"
        label: I18n.trFor("aibou", "Eyes follow the pointer")
        description: I18n.trFor("aibou", "Up to about 1–2 % CPU while the pointer moves near him, otherwise 0.")
        defaultValue: true
    }

    SelectionSetting {
        settingKey: "activity"
        label: I18n.trFor("aibou", "Activity")
        description: I18n.trFor("aibou", "How often he sets off on his own. Minimal: he melts into the frame and mostly just watches, so he does not get in the way while you work. Maximal: always out and about, never melts in by himself, and calls a friend over for a few minutes when he is alone. Measured with one figure: normal about 3 % CPU on average, calm about 1 %, lively about 5 %.")
        defaultValue: "normal"
        options: [
            { label: I18n.trFor("aibou", "Minimal"), value: "minimal" },
            { label: I18n.trFor("aibou", "Calm"), value: "calm" },
            { label: I18n.trFor("aibou", "Normal"), value: "normal" },
            { label: I18n.trFor("aibou", "Lively"), value: "lively" },
            { label: I18n.trFor("aibou", "Maximal"), value: "max" }
        ]
    }

    ToggleSetting {
        settingKey: "games"
        label: I18n.trFor("aibou", "Ball game")
        description: I18n.trFor("aibou", "About 20 % CPU during a game. A game lasts a little over a minute at most and comes only now and then.")
        defaultValue: true
    }

    SliderSetting {
        settingKey: "sleepAfter"
        label: I18n.trFor("aibou", "Fall asleep after")
        description: I18n.trFor("aibou", "Minutes without activity.")
        defaultValue: 8
        minimum: 2
        maximum: 60
        unit: "min"
    }

    ToggleSetting {
        settingKey: "sleepAnim"
        label: I18n.trFor("aibou", "Sleep animation")
        description: I18n.trFor("aibou", "Breathing and a \"z\" while asleep. About 0.5 % CPU per figure. Off, he sleeps without moving at 0 %.")
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "notifications"
        label: I18n.trFor("aibou", "Notifications")
        description: I18n.trFor("aibou", "Shows notifications as a speech bubble. For this Aibou reads the title and text of every notification on the session bus; they stay on this computer. Practically 0.")
        defaultValue: false
    }

    SelectionSetting {
        settingKey: "dock"
        label: I18n.trFor("aibou", "Frame")
        description: I18n.trFor("aibou", "While you work he melts into the bottom of the screen frame, only a dome with eyes shows. While busy: after about 45 s of steady activity, out again after 2.5 min of quiet. Always: the frame is his home. Saves CPU, because he stays still.")
        defaultValue: "auto"
        options: [
            { label: I18n.trFor("aibou", "While busy"), value: "auto" },
            { label: I18n.trFor("aibou", "Always"), value: "always" },
            { label: I18n.trFor("aibou", "Never"), value: "off" }
        ]
    }

    SelectionSetting {
        settingKey: "dockAt"
        label: I18n.trFor("aibou", "Where in the frame")
        description: I18n.trFor("aibou", "Bottom frame: he sinks in where he stands. Bar: he rolls over and bulges out of the bar's inner edge (bar on the left or right). Nearest: the bar when he is close to it, otherwise the bottom frame.")
        defaultValue: "both"
        options: [
            { label: I18n.trFor("aibou", "Nearest"), value: "both" },
            { label: I18n.trFor("aibou", "Bottom frame"), value: "frame" },
            { label: I18n.trFor("aibou", "Bar"), value: "bar" }
        ]
    }

    SelectionSetting {
        settingKey: "dockTint"
        label: I18n.trFor("aibou", "Colour in the frame")
        description: I18n.trFor("aibou", "Frame colour: the dome takes the colour and transparency of the frame and looks like part of it. His colour: the dome keeps the colour chosen above.")
        defaultValue: "frame"
        options: [
            { label: I18n.trFor("aibou", "Frame colour"), value: "frame" },
            { label: I18n.trFor("aibou", "His colour"), value: "own" }
        ]
    }

    SelectionSetting {
        settingKey: "barStyle"
        label: I18n.trFor("aibou", "In the bar")
        description: I18n.trFor("aibou", "Bulge: a dome with eyes bulges out of the bar's inner edge. Face only: nothing sticks out, only his face shows inside the bar, in a free spot between the icons. If there is no room, he bulges out after all. The free spot is found in a screenshot of the bar (grim) that stays on this computer.")
        defaultValue: "bump"
        options: [
            { label: I18n.trFor("aibou", "Bulge"), value: "bump" },
            { label: I18n.trFor("aibou", "Face only"), value: "flat" }
        ]
    }

    ToggleSetting {
        settingKey: "moods"
        label: I18n.trFor("aibou", "Feels the machine")
        description: I18n.trFor("aibou", "Under high load (CPU over about 60 % for a while, memory over 82 % or a hot processor) he starts to sweat, under very high load he squeezes his eyes shut. When a program crashes or a service fails he gets angry and says what broke; for that he follows the system journal and DMS's log. Checks every 2 s, practically 0.")
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "watchSystem"
        label: I18n.trFor("aibou", "Notices what happens")
        description: I18n.trFor("aibou", "He reacts when a download lands in ~/Downloads, a USB drive is plugged in, a program uses the microphone or records the screen, a long build or package run ends, or updates are waiting. For this he watches ~/Downloads, USB events and the audio streams, looks at the names of the running programs every 15 s and runs checkupdates every 3 hours. Nothing leaves the computer. Practically 0.")
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "dance"
        label: I18n.trFor("aibou", "Dances to music")
        description: I18n.trFor("aibou", "When a player plays music he hops to the beat, in the frame his dome pulses along. The beat comes from cava's bass, a small cava runs only while music plays: about 1 % CPU, plus the hops. With the battery saver on battery he dances to every other beat.")
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "chat"
        label: I18n.trFor("aibou", "Chat")
        description: I18n.trFor("aibou", "Chat through Claude in its own window; he jumps into it. The session keeps running in the background, so answers start after about one second and arrive word by word. What you write goes to Anthropic or the provider chosen below. A line starting with ! runs as a command in bash, like in a terminal. 0 locally; each answer counts against the Claude quota.")
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "desktopHelp"
        label: I18n.trFor("aibou", "Desktop help")
        description: I18n.trFor("aibou", "In the chat he may look things up on the desktop (files, read-only commands like niri msg -j windows and dms ipc get) and knows the desktop skill. He reads only the desktop's config folders (niri, DMS, Quickshell, GTK, Qt, kitty) and folders you add; files named like tokens, passwords or keys are always refused. Changes he only proposes as a card; nothing runs until you click Run. Root rights, restarting DMS or niri and resets are always blocked. What he reads goes to the chat provider along with your message.")
        defaultValue: false
    }

    SelectionSetting {
        settingKey: "model"
        label: I18n.trFor("aibou", "Chat model")
        description: I18n.trFor("aibou", "Haiku answers fastest, Sonnet and Opus think deeper; all three need Claude Code (the claude command). The providers set up below can be chosen here too. Switching in the chat window changes this setting as well.")
        defaultValue: "haiku"
        // Claude Code's three models, then the providers set up below
        options: [
            { label: "Haiku", value: "haiku" },
            { label: "Sonnet", value: "sonnet" },
            { label: "Opus", value: "opus" }
        ].concat(prov.list.map(p => ({ label: p.name || p.id, value: "p:" + p.id })))
    }

    // ── other AI providers ───────────────────────────────────────
    // Saved as the list "providers" (id, name, kind, url, model); the key of each
    // one goes into the keyring (secret-tool, service aibou, provider <id>), never
    // into a file. In the chat window they come after Haiku, Sonnet and Opus.
    Column {
        id: prov
        width: parent ? parent.width : 400
        spacing: Theme.spacingS
        property var list: []
        property var hasKey: ({})
        // DMS hands the page its plugin service only after it is built, and
        // lists come back as Qt lists (Array.isArray does not know them): the
        // stored list is read through a binding and copied once it is there
        readonly property var stored: root.pluginService ? root.pluginService.loadPluginData("aibou", "providers", []) : null
        property bool loaded: false
        onStoredChanged: load()
        Component.onCompleted: Qt.callLater(load)
        function load() {
            if (loaded || stored === null) return
            loaded = true
            const v = stored
            list = v && typeof v === "object" && v.length !== undefined ? Array.from(v).map(p => Object.assign({}, p)) : []
            checkKeys()
        }
        function save() { root.saveValue("providers", list) }
        function change(i, key, value) {
            const l = list.slice()
            l[i] = Object.assign({}, l[i], { [key]: value })
            list = l
            save()
        }
        function add() {
            const id = "p" + Date.now().toString(36)
            list = list.concat([{ id: id, name: I18n.trFor("aibou", "New provider"), kind: "openai",
                                  url: "https://api.openai.com/v1", model: "" }])
            save()
        }
        function remove(i) {
            keyProc.run(["secret-tool", "clear", "service", "aibou", "provider", list[i].id], "")
            const l = list.slice(); l.splice(i, 1); list = l
            save()
        }
        function checkKeys() {
            if (list.length === 0) return
            // the ids as arguments, never as part of the script
            lookProc.command = ["sh", "-c", "for i in \"$@\"; do secret-tool lookup service aibou provider \"$i\" >/dev/null 2>&1 && echo \"$i\"; done",
                                "sh"].concat(list.map(p => String(p.id)))
            lookProc.running = true
        }
        Process {
            id: lookProc
            stdout: StdioCollector {
                id: lookOut
                onStreamFinished: {
                    const h = {}
                    for (const id of lookOut.text.split("\n")) if (id) h[id] = true
                    prov.hasKey = h
                }
            }
        }
        // the key travels in the environment, not on the command line
        Process {
            id: keyProc
            function run(cmd, key) { command = cmd; environment = { AIBOU_KEY: key }; running = true }
            onExited: prov.checkKeys()
        }
        function storeKey(i, key) {
            const p = list[i]
            keyProc.run(["sh", "-c", "printf %s \"$AIBOU_KEY\" | secret-tool store --label=\"Aibou: $1\" service aibou provider \"$2\"",
                         "sh", p.name, p.id], key)
        }

        StyledText {
            width: parent.width
            text: I18n.trFor("aibou", "Other AI providers")
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }
        StyledText {
            width: parent.width
            wrapMode: Text.WordWrap
            text: I18n.trFor("aibou", "Any service with an OpenAI-compatible interface (OpenAI, OpenRouter, Mistral, Groq, Gemini, or local: Ollama http://localhost:11434/v1, LM Studio http://localhost:1234/v1) or the Anthropic API directly. Keys are kept in the system keyring. With desktop help on, they may read files and run read-only commands too (as tools).")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }
        Repeater {
            model: prov.list
            Rectangle {
                id: entry
                required property var modelData
                required property int index
                width: prov.width
                height: entryCol.implicitHeight + Theme.spacingM * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                Column {
                    id: entryCol
                    x: Theme.spacingM; y: Theme.spacingM
                    width: parent.width - Theme.spacingM * 2
                    spacing: Theme.spacingS
                    Row {
                        width: parent.width
                        spacing: Theme.spacingS
                        DankTextField {
                            width: parent.width - kindGroup.width - delBtn.width - Theme.spacingS * 2
                            text: entry.modelData.name
                            placeholderText: I18n.trFor("aibou", "Name in the chat window")
                            onEditingFinished: if (text !== entry.modelData.name) prov.change(entry.index, "name", text)
                        }
                        DankButtonGroup {
                            id: kindGroup
                            size: "small"
                            model: ["OpenAI", "Anthropic"]
                            currentIndex: entry.modelData.kind === "anthropic" ? 1 : 0
                            onSelectionChanged: (i, on) => {
                                if (!on) return
                                const kind = i === 1 ? "anthropic" : "openai"
                                if (kind === entry.modelData.kind) return
                                prov.change(entry.index, "kind", kind)
                                prov.change(entry.index, "url", kind === "anthropic" ? "https://api.anthropic.com" : "https://api.openai.com/v1")
                            }
                        }
                        DankActionButton {
                            id: delBtn
                            iconName: "delete"
                            onClicked: prov.remove(entry.index)
                        }
                    }
                    DankTextField {
                        width: parent.width
                        text: entry.modelData.url || ""
                        placeholderText: I18n.trFor("aibou", "Address (base URL)")
                        onEditingFinished: if (text !== entry.modelData.url) prov.change(entry.index, "url", text.trim())
                    }
                    DankTextField {
                        width: parent.width
                        text: entry.modelData.model || ""
                        placeholderText: entry.modelData.kind === "anthropic" ? "claude-sonnet-5-5" : "gpt-4o-mini · llama3.2 · mistral-small-latest"
                        onEditingFinished: if (text !== entry.modelData.model) prov.change(entry.index, "model", text.trim())
                    }
                    DankTextField {
                        width: parent.width
                        echoMode: TextInput.Password
                        showPasswordToggle: true
                        placeholderText: prov.hasKey[entry.modelData.id]
                            ? I18n.trFor("aibou", "Key saved in the keyring (type a new one to replace it)")
                            : I18n.trFor("aibou", "API key (Enter saves it to the keyring; not needed for local models)")
                        onAccepted: if (text.trim() !== "") { prov.storeKey(entry.index, text.trim()); text = "" }
                    }
                    // one short question, the way the chat asks (aiboud --test-provider)
                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        DankButton {
                            id: testBtn
                            text: testProc.running ? I18n.trFor("aibou", "Testing …") : I18n.trFor("aibou", "Test")
                            iconName: "network_check"
                            buttonHeight: Theme.iconSize + Theme.spacingS
                            onClicked: {
                                if (testProc.running) return
                                entry.result = ""
                                entry.ok = false
                                testProc.running = true
                            }
                        }
                        StyledText {
                            width: parent.width - testBtn.width - Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            text: entry.result
                            wrapMode: Text.WordWrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                            font.pixelSize: Theme.fontSizeSmall
                            color: entry.ok ? Theme.primary : Theme.error
                        }
                    }
                }
                property string result: ""
                property bool ok: false
                Process {
                    id: testProc
                    command: ["sh", "-c", "exec \"$1/daemon/aiboud\" --test-provider \"$2\"", "sh", root.repoDir, entry.modelData.id]
                    stdout: StdioCollector {
                        id: testOut
                        onStreamFinished: {
                            let r = null
                            try { r = JSON.parse(testOut.text.trim().split("\n").pop()) } catch (e) {}
                            if (!r) { entry.ok = false; entry.result = I18n.trFor("aibou", "No answer from the test"); return }
                            entry.ok = r.ok
                            entry.result = r.ok ? "✓ " + (r.total / 1000).toFixed(1) + " s: " + r.text : "✗ " + r.text
                        }
                    }
                }
            }
        }
        DankButton {
            text: I18n.trFor("aibou", "Add provider")
            iconName: "add"
            onClicked: prov.add()
        }
    }

    ToggleSetting {
        settingKey: "batterySaver"
        label: I18n.trFor("aibou", "Battery saver")
        description: I18n.trFor("aibou", "On battery: no ball game, fewer walks, falls asleep sooner.")
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "front"
        label: I18n.trFor("aibou", "Stay in front")
        description: I18n.trFor("aibou", "Stays above the windows instead of behind them. Costs the same, but he is always visible.")
        defaultValue: false
    }
}
