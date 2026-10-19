import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import QtQuick

// The system side of notifications — with MediaSource.qml and
// QuickSource.qml, one of the files that talk to the system. It makes the
// shell itself the notification daemon (the thing that receives what apps
// send with `notify-send`, Discord, Firefox, ...) and hands the UI plain
// data, so the files that draw it stay pure UI:
//
//   entries   the notification history, newest first — the Quick Panel's
//             list. Every notification that arrives is kept here (and
//             saved to ~/.local/state/sekaipop/notifications.json), so the
//             list survives a shell restart or reboot and still shows
//             ones the app itself closed or replaced afterwards, like the
//             sidebar list in end-4's "ii". Nothing expires on its own:
//             an entry goes when you dismiss it (click / swipe it in the
//             panel), when you clear them all (the "Notifications" tag),
//             or when it's the oldest past `maxEntries`.
//   toast     the notification that just arrived. There's no popup of its
//             own any more: the Quick Panel (QuickPanel.qml) is the alert.
//             When something arrives the phone comes up if it isn't
//             already, buzzes, and shows this one as a card at the top of
//             its screen (QuickPanelFace.qml's heads-up) for a few
//             seconds. toastActive says whether that card is showing right
//             now; toast itself stays put after so the card can keep its
//             text while it slides away. `alerted` is the one-shot signal
//             the phone listens to for its buzz.
//
//   popups    the stack of cards on screen (NotificationPopup.qml), newest
//             first. Which of the two alerts a new notification gets is
//             `alertStyle` (Settings > General, "notify.style"): "phone"
//             (the default) does what the toast paragraph above describes
//             and shows no popups; "popups" pushes it onto this stack and
//             leaves the phone alone. A popup is only the announcement: its
//             notification stays in `entries` (the Quick Panel's list) when
//             the popup times out or is closed, and goes from there only
//             when you dismiss it (right click or swipe on the popup, the
//             same as in the list). The timing lives here, not in the cards:
//             one 200 ms tick, which skips a popup while the pointer is on
//             it and gives it a moment more after the pointer leaves.
//             `popupsSuppressed` (the phone is up: its list already shows
//             everything) keeps new ones off the stack.
//
// Clicking: `activate(key)` runs the notification's "default" action (the app
// decides what that is: Discord opens the message) and removes it from the
// history; it returns false, changing nothing, when there is no live action.
// The cards call it on a left click and fall back to their old click when it
// says false. Middle click hides a popup / heads-up card but keeps the
// notification in the list; right click removes it.
//
// Do not disturb: shell.qml ties doNotDisturb to the Quick Panel's
// Notifications tile — OFF means nothing announces itself (no popup, or no
// rising / buzz / card in phone style). Notifications still arrive in the
// panel's list, and "critical" ones (the app says it's urgent: low battery,
// ...) always break through.
//
// Quiet while fullscreen: with Settings > General > "Quiet while fullscreen"
// on (`quietWhenFullscreen`), the same hold-back applies for as long as the
// focused monitor's active workspace has a fullscreen window (a game, a
// video, a presentation) — and only then: leave fullscreen and the next
// one announces itself again. Nothing is lost: they still land in the list.
//
// Only one program on the system can be the notification daemon at a
// time. If dunst, mako or swaync is running, stop it (and stop it from
// starting) or notifications will keep going there instead.
Scope {
    id: root

    property bool doNotDisturb: false

    // shell.qml binds this to the "notify.quietFullscreen" setting.
    property bool quietWhenFullscreen: false

    // A fullscreen window is on the focused monitor's active workspace right
    // now (what Hyprland says in `hasfullscreen`, the same field the video
    // wallpaper reads). Quickshell refreshes a workspace's data on workspace
    // events but not when a window goes fullscreen, so `fullscreenWatch` below
    // asks again on those events — only while the setting is on.
    readonly property var focusedWorkspace: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.activeWorkspace : null
    readonly property bool fullscreenNow: !!(root.focusedWorkspace && root.focusedWorkspace.lastIpcObject
                                             && root.focusedWorkspace.lastIpcObject.hasfullscreen)
    // Holds announcements back right now, apart from critical ones.
    readonly property bool held: root.doNotDisturb || (root.quietWhenFullscreen && root.fullscreenNow)

    // Each entry: { key (unique, stable across restarts), nid (the
    //               daemon's id while that notification is still live,
    //               else -1), seq, app, title, body, time (ms since epoch),
    //               urgency (0 low, 1 normal, 2 critical), appIcon, image,
    //               desktopEntry, icon }
    property var entries: []
    readonly property int count: entries.length

    property var toast: null
    property bool toastActive: false

    // "phone" | "popups": how a new notification announces itself (see the
    // header). shell.qml binds it to the "notify.style" setting.
    property string alertStyle: "phone"
    property bool popupsSuppressed: false

    // The popup stack: entries (the same objects as in `entries`), newest
    // first, at most maxPopups. popupMonitor is the monitor it shows on,
    // decided when the stack goes from empty to not empty (the focused one),
    // like the OSD's. popupLeft (key -> ms still to show) and popupHeld
    // (key -> true while the pointer is on it) are plain bookkeeping.
    property var popups: []
    property string popupMonitor: ""
    property int maxPopups: 4
    property var popupLeft: ({})
    property var popupHeld: ({})

    // Fired once for every notification that's allowed to alert (not held
    // back by do-not-disturb) — QuickPanel.qml raises and buzzes the
    // phone on it. Sent after toast / toastActive are already updated.
    signal alerted(var entry)

    // The history keeps at most this many; the oldest are dropped first.
    property int maxEntries: 100

    // False until the saved history has been read. Nothing is written
    // before then (or a fresh start would overwrite what's on disk with
    // an empty list), and notifications that arrive in the meantime wait
    // in `pending` and are added right after.
    property bool loaded: false
    property var pending: []
    property int seqCounter: 0

    // Apps sometimes send a little HTML even though we say we don't take
    // markup; strip the tags and undo the usual escapes.
    function clean(s) {
        return String(s === undefined || s === null ? "" : s)
            .replace(/<[^>]*>/g, "")
            .replace(/&lt;/g, "<")
            .replace(/&gt;/g, ">")
            .replace(/&quot;/g, "\"")
            .replace(/&#39;|&apos;/g, "'")
            .replace(/&amp;/g, "&")
            .replace(/\s+/g, " ")
            .trim()
    }

    // An icon-theme name needs resolving to something Image/IconImage can
    // load; a path, file:// URL or embedded image is already usable.
    // Resolves an icon the way Image/IconImage need it, done once here
    // so the Quick Panel's list and heads-up card — pure UI, no Quickshell imports —
    // can just take `icon` and hand it straight to a plain Image.
    function resolveIconName(s, check) {
        // "material:<name>" is this shell's own convention for "draw this
        // Material Symbols glyph" (e.g. `notify-send -i material:music_cast`).
        // It marks a notification the shell (or one of its scripts) sent
        // itself, as opposed to an app or a browser: the cards draw it as a
        // ShellBadge (a pastel attribute badge with a white outlined glyph,
        // the colour picked from the glyph by NotifyKinds.js) instead of an
        // Image. Any glyph name works, so your own scripts can use it too.
        if (s.startsWith("material:"))
            return s
        // Paths, URLs (file://, http(s)://, and image://qsimage/... for
        // pictures embedded in the notification, like a chat avatar) and
        // data: URIs are already loadable. Anything else is a theme name.
        if (s.startsWith("/") || s.startsWith("data:") || s.includes("://"))
            return s
        return Quickshell.iconPath(s, check)
    }

    // "material:<name>" out of a string that contains it ("" if it doesn't).
    function materialIcon(raw) {
        const t = String(raw || "")
        const i = t.indexOf("material:")
        return i >= 0 ? t.substring(i) : ""
    }

    // Whatever icon/image the notification itself sent (image, a chat
    // app's profile picture, wins over appIcon when both are present).
    // A theme name that can't be found comes back "" (check = true), so
    // the app's .desktop icon below still gets its turn instead of a
    // generic placeholder blocking it.
    function hintedIcon(image, appIcon) {
        // A "material:<name>" icon wins over everything. Look in `image` too:
        // Quickshell can hand a theme-style app icon back as an
        // image://icon/<name> URL there, which would otherwise load as the
        // magenta/black "missing icon" checkerboard.
        const mat = materialIcon(appIcon) || materialIcon(image)
        if (mat !== "")
            return mat
        for (const raw of [image, appIcon]) {
            if (raw === "")
                continue
            const r = resolveIconName(raw, true)
            if (r !== "")
                return r
        }
        return ""
    }

    // Plenty of apps (Discord, Firefox...) don't send a usable icon with
    // every notification. Guess it from the app's .desktop file: first
    // the desktop-entry hint the app sent, then its app name.
    // heuristicLookup only ever guesses, so this can still come back
    // empty for something with no matching .desktop file.
    function appIconFallback(appName, desktopEntry) {
        for (const key of [desktopEntry, appName]) {
            if (!key)
                continue
            try {
                const entry = DesktopEntries.heuristicLookup(key)
                if (entry && entry.icon) {
                    const r = resolveIconName(entry.icon, true)
                    if (r !== "")
                        return r
                }
            } catch (e) {}
        }
        return ""
    }

    // A stored picture (image://qsimage/..., a chat avatar embedded in
    // the notification) only exists while the daemon holds it, so it
    // isn't saved; on the way back from disk such an entry gets its
    // app's own icon instead (appIconFallback).
    function savable(s) {
        return String(s || "").startsWith("image://") ? "" : String(s || "")
    }

    function entryFor(n) {
        const app = clean(n.appName)
        const title = clean(n.summary)
        const appIcon = n.appIcon || ""
        const image = n.image || ""
        const desktopEntry = n.desktopEntry || ""
        let urgency = 1
        if (n.urgency === NotificationUrgency.Critical)
            urgency = 2
        else if (n.urgency === NotificationUrgency.Low)
            urgency = 0
        const hinted = hintedIcon(image, appIcon)
        const now = Date.now()
        seqCounter++
        return {
            key: "n" + now + "-" + seqCounter,
            nid: n.id,
            seq: seqCounter,
            app: app,
            title: title !== "" ? title : app,
            body: clean(n.body),
            time: now,
            urgency: urgency,
            // Raw strings straight off the notification — an icon-theme
            // name, a file path, or "" if the app didn't send one.
            appIcon: appIcon,
            image: image,
            desktopEntry: desktopEntry,
            // Resolved once here rather than per-consumer, for the Quick
            // Panel's list: the notification's own hint if it sent one,
            // else a guess at the app's own .desktop icon, else "" (the
            // list falls back to a generic glyph).
            icon: hinted !== "" ? hinted : appIconFallback(app, desktopEntry)
        }
    }

    // Newest first (ties: the later arrival).
    function sorted(list) {
        return list.slice().sort((a, b) => b.time !== a.time ? b.time - a.time : b.seq - a.seq)
    }

    function indexOfKey(list, key) {
        for (let i = 0; i < list.length; i++) {
            if (list[i].key === key)
                return i
        }
        return -1
    }

    // The history changed: publish it and (once loaded) save it.
    function commit(list) {
        entries = list
        if (loaded)
            saveTimer.restart()
    }

    function find(nid) {
        const vals = server.trackedNotifications.values
        for (let i = 0; i < vals.length; i++) {
            if (vals[i].id === nid)
                return vals[i]
        }
        return null
    }

    // The "default" action of a live notification: what an app wants to happen when you
    // click the notification itself (Discord: go to that message, a mail client: open the
    // mail). Apps only send it when the daemon says it supports actions (see the
    // NotificationServer at the bottom). Other actions (the apps' own "Reply" / "Mark as
    // read" buttons) are not offered anywhere: a click only ever runs this one, so an app
    // with several buttons never has to be chosen between. null when there is none, the
    // notification is gone (closed by the app, or from before a restart) or has no id.
    function defaultAction(entry) {
        if (!entry || entry.nid < 0)
            return null
        const n = find(entry.nid)
        if (n === null)
            return null
        const acts = n.actions
        for (let i = 0; i < acts.length; i++) {
            if (acts[i].identifier === "default")
                return acts[i]
        }
        return null
    }

    // True when clicking this notification can do something (it has a live default action).
    function canActivate(key) {
        const i = indexOfKey(entries, key)
        return i >= 0 && defaultAction(entries[i]) !== null
    }

    // A click on the notification. Runs its default action and, since it has been dealt
    // with, takes it out of the history (and off the screen). Returns whether an action was
    // run; false means there was nothing to run and NOTHING was changed, so the caller does
    // what a click did before (hide the popup, dismiss the card).
    function activate(key) {
        const i = indexOfKey(entries, key)
        if (i < 0)
            return false
        const action = defaultAction(entries[i])
        if (action === null)
            return false
        action.invoke()
        dismiss(key)
        return true
    }

    // Closes the app's side of a notification, if it's still live.
    function closeLive(entry) {
        if (entry.nid < 0)
            return
        const n = find(entry.nid)
        if (n !== null)
            n.dismiss()
    }

    function received(n) {
        // Untracked notifications are thrown away as soon as this handler
        // returns, so tracking is what keeps it.
        n.tracked = true

        // The saved history hasn't been read yet: hold it a moment.
        if (!loaded) {
            pending.push(n)
            return
        }
        ingest(n)
    }

    function ingest(n) {
        const list = entries.slice()

        // After a shell reload (a file change, or the Refresh button)
        // the NotificationServer hands back every notification still
        // waiting, through this same handler, with lastGeneration set
        // (keepOnReload, on by default). They're old news: if the history
        // already has it (matched by the daemon's id), leave it be; don't
        // raise the phone, buzz, or show the heads-up card for it again.
        if (n.lastGeneration) {
            if (list.some(e => e.nid === n.id))
                return
            list.unshift(entryFor(n))
            commit(pruned(sorted(list)))
            return
        }

        // A genuinely new one. The daemon's ids start over from 1 after a
        // full restart, so any older entry still carrying this id is from
        // an earlier run and no longer live.
        for (let i = 0; i < list.length; i++) {
            if (list[i].nid === n.id)
                list[i] = Object.assign({}, list[i], { nid: -1 })
        }
        const e = entryFor(n)
        list.unshift(e)
        commit(pruned(sorted(list)))

        // Silent: still in the list, but nothing announces it. A screenshot's
        // own "copied" / "saved" note (the preview card already says so), and
        // everything while Edit Desktop is open (it would sit on the board).
        const quiet = EditMode.active || isScreenshotNote(e)
        if (!quiet && (!root.held || e.urgency === 2)) {
            if (alertStyle === "popups") {
                if (!popupsSuppressed)
                    pushPopup(e)
            } else {
                showToast(e)
            }
        }
    }

    // The shell's own screenshot confirmations (scripts/system/region-action.sh).
    // Errors ("wl-clipboard is not installed") are not matched, so they still show.
    function isScreenshotNote(e) {
        if (String(e.app).toLowerCase() !== "sekaipop")
            return false
        return e.title === "Copied to the clipboard" && e.body === "Region screenshot"
            || e.title === "Screenshot saved"
    }

    // Over the limit: the oldest go (and are closed on the app's side too).
    function pruned(list) {
        while (list.length > maxEntries)
            closeLive(list.pop())
        return list
    }

    function dismiss(key) {
        closePopup(key)
        const list = entries.slice()
        const i = indexOfKey(list, key)
        if (i < 0)
            return
        closeLive(list[i])
        list.splice(i, 1)
        commit(list)
        if (toastActive && toast !== null && toast.key === key)
            hideToast()
    }

    // A whole group (everything from one source) at once.
    function dismissMany(keys) {
        closePopups(keys)
        const gone = {}
        for (let i = 0; i < keys.length; i++)
            gone[keys[i]] = true
        const list = []
        for (let i = 0; i < entries.length; i++) {
            if (gone[entries[i].key])
                closeLive(entries[i])
            else
                list.push(entries[i])
        }
        commit(list)
        if (toastActive && toast !== null && gone[toast.key])
            hideToast()
    }

    function clearAll() {
        for (let i = 0; i < entries.length; i++)
            closeLive(entries[i])
        commit([])
        hideToast()
        clearPopups()
    }

    // ===== saved history =====
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/sekaipop"

    function snapshot() {
        return JSON.stringify(entries.map(e => ({
            key: e.key,
            nid: e.nid,
            seq: e.seq,
            app: e.app,
            title: e.title,
            body: e.body,
            time: e.time,
            urgency: e.urgency,
            appIcon: savable(e.appIcon),
            image: savable(e.image),
            desktopEntry: e.desktopEntry,
            icon: savable(e.icon)
        })))
    }

    function restore(text) {
        const list = []
        try {
            const saved = JSON.parse(text)
            for (const it of (Array.isArray(saved) ? saved : [])) {
                if (!it || typeof it.key !== "string" || typeof it.time !== "number")
                    continue
                const app = typeof it.app === "string" ? it.app : ""
                const desktopEntry = typeof it.desktopEntry === "string" ? it.desktopEntry : ""
                // (a "material:" icon saved as an image://icon/ URL by an
                // earlier build comes back as the plain "material:<name>")
                const savedIcon = typeof it.icon === "string" ? it.icon : ""
                const icon = materialIcon(savedIcon) || savedIcon
                seqCounter = Math.max(seqCounter, typeof it.seq === "number" ? it.seq : 0)
                list.push({
                    key: it.key,
                    nid: typeof it.nid === "number" ? it.nid : -1,
                    seq: typeof it.seq === "number" ? it.seq : 0,
                    app: app,
                    title: typeof it.title === "string" ? it.title : app,
                    body: typeof it.body === "string" ? it.body : "",
                    time: it.time,
                    urgency: (it.urgency === 0 || it.urgency === 2) ? it.urgency : 1,
                    appIcon: typeof it.appIcon === "string" ? it.appIcon : "",
                    image: typeof it.image === "string" ? it.image : "",
                    desktopEntry: desktopEntry,
                    icon: icon !== "" ? icon : appIconFallback(app, desktopEntry)
                })
            }
        } catch (e) {
            // No file yet (first run) or an unreadable one: start empty.
        }
        entries = pruned(sorted(list))
        loaded = true

        // Whatever arrived while the file was being read.
        const waiting = pending
        pending = []
        for (let i = 0; i < waiting.length; i++)
            ingest(waiting[i])
    }

    // Make the folder first (a fresh install has no state dir yet), then
    // point the FileView at the file, which loads it.
    Process {
        running: true
        command: ["mkdir", "-p", "-m", "700", root.stateDir]
        onExited: history.path = root.stateDir + "/notifications.json"
    }

    FileView {
        id: history

        atomicWrites: true
        watchChanges: false

        onLoaded: root.restore(history.text())
        // The file doesn't exist yet (first run).
        onLoadFailed: root.restore("")
    }

    // Debounced, so a burst of notifications is one write.
    Timer {
        id: saveTimer
        interval: 400
        onTriggered: {
            if (root.loaded && history.path !== "")
                history.setText(root.snapshot())
        }
    }

    // ===== the toast =====
    function showToast(entry) {
        toast = entry
        toastActive = true
        alerted(entry)
        toastTimer.interval = readMs(entry)
        toastTimer.restart()
    }

    // How long an announcement stays (toast or popup): long ones a little
    // longer, critical ones longer still.
    function readMs(entry) {
        const ms = 3500 + (entry.title.length + entry.body.length) * 45 + (entry.urgency === 2 ? 4000 : 0)
        return Math.min(12000, Math.max(4500, ms))
    }

    function hideToast() {
        toastActive = false
        toastTimer.stop()
    }

    Timer {
        id: toastTimer
        onTriggered: root.hideToast()
    }

    // ===== the popups =====
    function pushPopup(entry) {
        if (popups.length === 0)
            popupMonitor = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name
                : (Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "")
        const list = [entry].concat(popups)
        while (list.length > maxPopups) {
            const old = list.pop()
            delete popupLeft[old.key]
            delete popupHeld[old.key]
        }
        popupLeft[entry.key] = readMs(entry)
        popups = list
    }

    // Closes popups only: the notifications stay in the history.
    function closePopups(keys) {
        if (popups.length === 0)
            return
        const gone = {}
        for (let i = 0; i < keys.length; i++) {
            gone[keys[i]] = true
            delete popupLeft[keys[i]]
            delete popupHeld[keys[i]]
        }
        const list = popups.filter(e => !gone[e.key])
        if (list.length !== popups.length)
            popups = list
    }

    function closePopup(key) {
        closePopups([key])
    }

    function clearPopups() {
        popupLeft = ({})
        popupHeld = ({})
        if (popups.length > 0)
            popups = []
    }

    // The pointer is on a popup (stop its clock) or has left it (a moment
    // more, so it doesn't vanish the instant you move away).
    function holdPopup(key, held) {
        if (popupLeft[key] === undefined)
            return
        if (held) {
            popupHeld[key] = true
        } else {
            delete popupHeld[key]
            popupLeft[key] = Math.max(popupLeft[key], 1500)
        }
    }

    function tickPopups() {
        const expired = []
        for (let i = 0; i < popups.length; i++) {
            const key = popups[i].key
            if (popupHeld[key])
                continue
            const left = (popupLeft[key] === undefined ? 0 : popupLeft[key]) - popupTick.interval
            popupLeft[key] = left
            if (left <= 0)
                expired.push(key)
        }
        if (expired.length > 0)
            closePopups(expired)
    }

    // Only ticks while there is something on the stack.
    Timer {
        id: popupTick
        interval: 200
        repeat: true
        running: root.popups.length > 0
        onTriggered: root.tickPopups()
    }

    // Switched from one style to the other in Settings: put the other
    // one's leftovers away.
    onAlertStyleChanged: {
        if (alertStyle === "popups")
            hideToast()
        else
            clearPopups()
    }

    // Keeps `fullscreenNow` fresh. Hyprland says "fullscreen" when a window goes in
    // or out of it, and the others when the active workspace or the focused monitor
    // changes; the 150 ms beat collapses a burst of them into one refresh. Nothing
    // here runs while the setting is off.
    Connections {
        target: Hyprland
        enabled: root.quietWhenFullscreen

        function onRawEvent(event) {
            if (event.name === "fullscreen" || event.name === "workspace" || event.name === "workspacev2"
                    || event.name === "focusedmon" || event.name === "focusedmonv2"
                    || event.name === "openwindow" || event.name === "closewindow"
                    || event.name === "movewindow" || event.name === "movewindowv2")
                fullscreenWatch.restart()
        }
    }

    Timer {
        id: fullscreenWatch
        interval: 150
        onTriggered: Hyprland.refreshWorkspaces()
    }

    // Switched on while a window is already fullscreen: look once now.
    onQuietWhenFullscreenChanged: {
        if (quietWhenFullscreen)
            Hyprland.refreshWorkspaces()
    }

    // Quickshell's defaults for what we tell apps we can display are what this needs —
    // plain text, no pictures, no markup — and notifications are kept across a shell
    // reload. The one thing switched on is `actionsSupported`: apps (Discord, Firefox,
    // mail clients...) only attach a "default" action to a notification when the daemon
    // advertises actions, and that is what a click on the notification runs (see
    // `activate`). It only advertises: no action buttons are drawn.
    NotificationServer {
        id: server

        actionsSupported: true

        onNotification: notification => root.received(notification)
    }

}
