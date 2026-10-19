pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Polkit

// The polkit agent — state only, same role as LockState.qml: no window,
// no UI. PolkitPrompt.qml turns this into the actual dialog.
//
// "Polkit agent" = the little program that asks for your password when
// something needs admin rights (installing a package from a GUI, mounting
// a disk, a settings app changing the system...). Only ONE agent can be
// registered per login session, so any other one you run
// (hyprpolkitagent, polkit-gnome, lxqt-policykit...) has to be stopped
// first — otherwise Quickshell's agent silently never receives anything.
// See the README's Polkit section.
//
// The flow of one prompt:
//
//   active                 true from the moment an app asks for
//                          authentication until it's approved/cancelled
//   message                "Authentication is required to ..." (cleaned)
//   prompt                 what the text field is asking for ("Password")
//   interactionAvailable   true while the field may be typed into. False
//                          right after you submit (PAM is thinking), true
//                          again if the password was wrong.
//   failed                 the last try was rejected
//
//   submit(text)  /  cancel()
Singleton {
    id: root

    readonly property bool active: agent.isActive
    readonly property var flow: agent.flow

    property bool interactionAvailable: false
    property bool failed: false

    // polkit messages end with a full stop, which looks odd as a subtitle.
    readonly property string message: {
        if (!root.flow || !root.flow.message)
            return ""
        const m = root.flow.message
        return m.endsWith(".") ? m.slice(0, -1) : m
    }

    // The field's hint text. PAM asks "Password: " — drop the colon.
    readonly property bool passwordMode: root.flow ? !root.flow.responseVisible : true
    readonly property string prompt: {
        const raw = root.flow && root.flow.inputPrompt ? root.flow.inputPrompt.trim() : ""
        const clean = raw.endsWith(":") ? raw.slice(0, -1).trim() : raw
        return clean !== "" ? clean : (root.passwordMode ? "Password" : "Input")
    }

    function submit(text) {
        if (!root.flow)
            return
        root.failed = false
        root.interactionAvailable = false
        root.flow.submit(text)
    }

    function cancel() {
        if (root.flow)
            root.flow.cancelAuthenticationRequest()
    }

    Connections {
        target: root.flow

        // Wrong password: PAM immediately asks again, so the same flow
        // just becomes typeable again.
        function onAuthenticationFailed() {
            root.failed = true
            root.interactionAvailable = true
        }
    }

    PolkitAgent {
        id: agent

        onAuthenticationRequestStarted: {
            root.failed = false
            root.interactionAvailable = true
        }
    }
}
