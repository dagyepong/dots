// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   A C C O U N T   S E R V I C E                                          │
// │   current user · name and avatar                                         │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Name and picture for the lock screen. Empty settings fall back to the
// system: the passwd full name, and `~/.face` or AccountsService. The settings
// field shows the system value as a placeholder instead of copying it in, so
// the override stays empty until actually set. Read once at startup.
Singleton {
    id: root

    readonly property string script: Quickshell.shellPath("scripts/account.py")

    property string user: ""
    property string systemName: ""
    property string systemAvatar: ""

    readonly property string name: SettingsService.userName !== ""
        ? SettingsService.userName
        : (root.systemName !== "" ? root.systemName : root.user)

    readonly property string avatar: SettingsService.userAvatar !== ""
        ? SettingsService.userAvatar
        : root.systemAvatar

    // Drawn when there is no picture: at most two initials.
    readonly property string initials: {
        const words = root.name.trim().split(/\s+/).filter(word => word !== "")
        if (words.length === 0)
            return "?"
        if (words.length === 1)
            return words[0].slice(0, 1).toUpperCase()
        return (words[0].slice(0, 1) + words[words.length - 1].slice(0, 1)).toUpperCase()
    }

    readonly property Process reader: Process {
        command: [root.script, "get"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text || text.trim() === "")
                    return
                try {
                    const report = JSON.parse(text)
                    root.user = report.user ?? ""
                    root.systemName = report.name ?? ""
                    root.systemAvatar = report.avatar ?? ""
                } catch (error) {
                    console.warn("Cannot parse the account:", error)
                }
            }
        }
    }
}
