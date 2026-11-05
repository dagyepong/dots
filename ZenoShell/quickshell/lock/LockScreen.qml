import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs.services
import "."
Scope {
    id: root

    property string password: ""
    property string status: ""
    property bool failed: false
    property bool checking: false
    property int failCount: 0

    function submit(pw) {
        if (checking || pam.active || pw === "") return
        password = pw
        checking = true
        failed = false
        status = ""
        pam.start()
    }

    // Password check with PAM (pam_unix only, see pam/password.conf)
    PamContext {
        id: pam
        configDirectory: Quickshell.shellPath("pam")
        config: "password.conf"

        onPamMessage: {
            if (pam.responseRequired) pam.respond(root.password)
        }

        onCompleted: result => {
            root.checking = false
            root.password = ""

            if (result === PamResult.Success) {
                root.failed = false
                root.status = ""
                UiState.lockTest = false
                UiState.locked = false
            } else {
                root.failed = true
                root.failCount++
                root.status = (result === PamResult.Error) ? "Authentication error" : "Wrong password"
            }
        }
    }

    // Safe test: it unlocks by itself, whatever happens
    Timer {
        interval: 1000
        repeat: true
        running: UiState.locked && UiState.lockTest
        onTriggered: {
            UiState.lockTestLeft--
            if (UiState.lockTestLeft <= 0) {
                UiState.locked = false
                UiState.lockTest = false
            }
        }
    }

    WlSessionLock {
        id: lock
        locked: UiState.locked

        WlSessionLockSurface {
            id: surface
            color: "black"

            LockView {
                anchors.fill: parent
                screenName: surface.screen ? surface.screen.name : ""
                status: root.status
                failed: root.failed
                checking: root.checking
                failCount: root.failCount
                onSubmit: pw => root.submit(pw)
            }
        }
    }
}
