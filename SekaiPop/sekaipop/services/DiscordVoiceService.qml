pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.modules.common

// Your Discord voice call, for the bar's Discord pill (DiscordPill.qml).
//
// A port of illogical-impulse (p3dro's fork) services/DiscordVoice.qml: it
// runs scripts/discordVoice/discord_voice_bridge.py, a small Python program
// that talks to Discord's local RPC socket (or to the Vencord companion, for
// Vesktop / Equibop / Discord with Vencord) and prints one JSON object per
// line, and turns what it says into properties.
//
// What it exposes:
//   inVoice / channel         in a voice channel? { id, name, ... }
//   participants              [{ id, nick, avatar, speaking, mute, deaf }]
//   participantCount
//   muted / deafened          your own mic / headphones
//   status                    starting | connected | auth_required |
//                             authorizing | authenticated | unavailable | ...
//   needsAuth                 Discord has to be linked once (one click)
//
//   DiscordVoiceService.setMuted(true)  /  setDeafened(true)
//   DiscordVoiceService.authorizeAfterFocusRelease()
//
// The bridge retries Discord's socket every few seconds, so it is not started
// for someone who never runs Discord: nothing happens until a Discord client
// has had a window this session (`clientSeen`, latched: a client closed to the
// tray is still running).
//
// From a keybind or a script:
//   qs -c sekaipop ipc call discord mute          (toggle)
//   qs -c sekaipop ipc call discord deafen        (toggle)
//   qs -c sekaipop ipc call discord authorize
//   qs -c sekaipop ipc call discord focus         (bring the Discord window forward)
//   qs -c sekaipop ipc call discord get
Singleton {
    id: root

    // ===== when to start =====
    property bool clientSeen: false
    readonly property var clientClasses: ["discord", "discord-canary", "discordcanary", "discord-ptb",
        "discordptb", "vesktop", "equibop", "webcord", "legcord", "armcord"]
    // Written as a block that always returns a real boolean: while Hyprland's
    // toplevel list isn't there yet (startup, a config reload) the one-line
    // `&& list.some(...)` form came out undefined, and Qt logged
    // "Unable to assign [undefined] to bool".
    readonly property bool clientWindowOpen: {
        if (root.clientSeen)
            return false
        const list = Hyprland.toplevels?.values
        if (!list)
            return false
        for (const t of list) {
            const cls = String(t?.lastIpcObject?.class ?? "").toLowerCase()
            if (root.clientClasses.indexOf(cls) !== -1)
                return true
        }
        return false
    }
    // Latched a turn later: setting it here would re-evaluate the binding
    // above, which reads it, from inside its own change notification.
    onClientWindowOpenChanged: if (root.clientWindowOpen) Qt.callLater(() => root.clientSeen = true)
    onClientSeenChanged: if (root.clientSeen) root.start(false)

    // ===== state =====
    property string status: "idle"
    // Which client is driving the state ("discord" or "vencord").
    property string backend: ""
    readonly property string backendLabel: backend === "vencord" ? "Vesktop"
        : (backend === "discord" ? "Discord" : "")
    property string errorMessage: ""
    property var currentUser: ({})
    property var channel: null
    property var participants: []
    readonly property int participantCount: participants.length
    property bool muted: false
    property bool deafened: false
    property int restartAttempts: 0
    property var pendingMessages: []
    readonly property int maxRestartAttempts: 5

    readonly property bool inVoice: channel !== null
    // Your own Discord id (the panel puts you first in the list).
    readonly property string selfId: currentUser && currentUser.id ? String(currentUser.id) : ""
    readonly property bool needsAuth: clientSeen && (status === "auth_required" || status === "authorizing")

    function avatarUrl(user, size) {
        if (!user || !user.id || !user.avatar)
            return ""
        return "https://cdn.discordapp.com/avatars/" + user.id + "/" + user.avatar + ".png?size=" + (size || 64)
    }

    // ===== talking to the bridge =====
    function send(message) {
        if (!bridge.running) {
            if (!root.clientSeen)
                return
            root.pendingMessages = root.pendingMessages.concat([message])
            root.start(true)
            return
        }
        bridge.write(JSON.stringify(message) + "\n")
    }

    function connect() {
        root.errorMessage = ""
        root.send({ cmd: "connect" })
    }
    function authorize() { root.send({ cmd: "authorize" }) }
    // Discord's "allow this app?" prompt needs the keyboard focus, which the
    // bar still has for a moment after the click that asked for it.
    function authorizeAfterFocusRelease() { focusReleaseDelay.restart() }
    function setMuted(value) { root.send({ cmd: "set_voice_settings", mute: value }) }
    function setDeafened(value) { root.send({ cmd: "set_voice_settings", deaf: value }) }

    readonly property bool usingLua: Hyprland.usingLua !== false

    // Bring the Discord window forward (the panel's "open Discord" button).
    // False when no client window is open (Discord closed to the tray).
    function focusClient() {
        const toplevel = (Hyprland.toplevels.values ?? []).find(t =>
            root.clientClasses.indexOf(String(t?.lastIpcObject?.class ?? "").toLowerCase()) !== -1)
        let address = toplevel ? String(toplevel.lastIpcObject?.address ?? "") : ""
        if (address === "")
            return false
        if (address.indexOf("0x") !== 0)
            address = "0x" + address
        Hyprland.dispatch(root.usingLua
            ? "hl.dsp.focus({ window = \"address:" + address + "\" })"
            : "focuswindow address:" + address)
        return true
    }

    function start(manual) {
        if (bridge.running || !root.clientSeen)
            return
        if (manual)
            root.restartAttempts = 0
        root.status = "starting"
        bridge.running = true
    }

    function flushPendingMessages() {
        const queued = root.pendingMessages
        root.pendingMessages = []
        for (const message of queued)
            bridge.write(JSON.stringify(message) + "\n")
    }

    function setParticipants(users) {
        root.participants = users || []
    }

    function handleLine(line) {
        let message
        try { message = JSON.parse(line) } catch (error) { return }
        switch (message.type) {
        case "ready": root.connect(); break
        case "backend": root.backend = message.backend || ""; break
        case "connected": root.status = "connected"; reconnectTimer.stop(); break
        case "auth_required": root.status = "auth_required"; break
        case "authorizing": root.status = "authorizing"; break
        case "authenticated":
            root.status = "authenticated"
            root.currentUser = message.user || {}
            root.restartAttempts = 0
            break
        case "voice_channel":
            root.channel = message.channel || null
            root.setParticipants(message.users)
            break
        case "voice_state": root.setParticipants(message.users); break
        case "voice_settings":
            root.muted = message.mute === true
            root.deafened = message.deaf === true
            break
        case "unavailable":
            root.status = "unavailable"
            root.errorMessage = message.message || ""
            reconnectTimer.restart()
            break
        // The Vencord companion failing leaves Discord's own RPC usable, so
        // this only reports the reason.
        case "companion_error": root.errorMessage = message.message || ""; break
        case "disconnected":
            root.status = "disconnected"
            root.backend = ""
            root.channel = null
            root.setParticipants([])
            reconnectTimer.restart()
            break
        case "error":
            root.status = "auth_required"
            root.errorMessage = message.message || "Discord RPC error"
            break
        }
    }

    // The bridge stays alive after Discord drops the socket (a Discord
    // restart, say) but will not reconnect on its own: ask again every few
    // seconds until it is back. connect() does nothing once linked.
    Timer {
        id: reconnectTimer
        interval: 3000
        repeat: true
        onTriggered: root.connect()
    }

    Timer {
        id: focusReleaseDelay
        interval: 220
        onTriggered: root.authorize()
    }

    Timer {
        id: restartTimer
        onTriggered: root.start(false)
    }

    readonly property string bridgeScript: Directories.script("discordVoice/discord_voice_bridge.py")

    Process {
        id: bridge
        command: ["python3", root.bridgeScript]
        stdinEnabled: true
        onStarted: root.flushPendingMessages()
        stdout: SplitParser { onRead: data => root.handleLine(data) }
        stderr: SplitParser { onRead: data => console.warn("[DiscordVoice]", data) }
        onExited: (code, exitStatus) => {
            root.channel = null
            root.setParticipants([])
            if (root.restartAttempts >= root.maxRestartAttempts) {
                root.status = "stopped"
                root.errorMessage = "Discord bridge stopped after repeated failures"
                return
            }
            root.restartAttempts++
            root.status = "restarting"
            // 1s, 2s, 4s ... capped at 30s.
            restartTimer.interval = Math.min(30000, 1000 * Math.pow(2, root.restartAttempts - 1))
            restartTimer.restart()
        }
    }

    IpcHandler {
        target: "discord"

        function mute(): void { root.setMuted(!root.muted) }
        function deafen(): void { root.setDeafened(!root.deafened) }
        function authorize(): void { root.authorizeAfterFocusRelease() }
        function reconnect(): void { root.connect() }
        function focus(): void { root.focusClient() }

        function get(): string {
            return root.status + (root.backendLabel ? " (" + root.backendLabel + ")" : "")
                + (root.inVoice ? " in #" + (root.channel.name || "?") + " with " + root.participantCount : "")
                + (root.muted ? " muted" : "") + (root.deafened ? " deafened" : "")
        }
    }
}
