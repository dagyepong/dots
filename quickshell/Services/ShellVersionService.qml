pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string shellVersion: ""
    property string shellCodename: ""
    property string semverVersion: ""
    property string installFingerprint: ""
    property string installedCommit: ""
    property string latestCommit: ""
    property string updateStatus: "idle"
    property string updateError: ""
    property bool updateChecked: false

    function getParsedShellVersion() {
        return parseVersion(semverVersion);
    }

    function shortCommit(commit) {
        if (!commit)
            return "";
        return commit.length > 12 ? commit.substring(0, 12) : commit;
    }

    function parseInstallFingerprint(text) {
        installFingerprint = text.trim();
        installedCommit = "";
        const lines = installFingerprint.split("\n");
        for (var i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            if (!line.startsWith("source_commit="))
                continue;
            const value = line.substring("source_commit=".length).trim();
            if (value && value !== "unknown" && !value.startsWith("failed:"))
                installedCommit = shortCommit(value);
            break;
        }
    }

    function refreshInstallFingerprint() {
        if (!fingerprintDetection.running)
            fingerprintDetection.running = true;
    }

    function checkForUpdates() {
        updateChecked = true;
        updateError = "";
        latestCommit = "";

        if (!installedCommit) {
            updateStatus = "checking";
            refreshInstallFingerprint();
            return;
        }

        updateStatus = "checking";
        latestCommitDetection.running = true;
    }

    function isUpdateAvailable() {
        return updateStatus === "available";
    }

    function installerUpdateCommand(extraArgs) {
        const args = extraArgs && extraArgs.length > 0 ? " " + extraArgs : "";
        return 'curl -fsSL "https://raw.githubusercontent.com/acarlton5/HypeShell/main/install.sh?cache=$(date +%s)" | bash -s -- --update' + args;
    }

    Process {
        id: fingerprintDetection
        running: true
        command: ["sh", "-c", `for f in /usr/local/share/hypeshell/install-fingerprint /usr/share/hypeshell/install-fingerprint; do if [ -r "$f" ]; then cat "$f"; exit 0; fi; done; exit 1`]

        stdout: StdioCollector {
            onStreamFinished: root.parseInstallFingerprint(text)
        }

        onExited: exitCode => {
            if (root.updateStatus !== "checking")
                return;
            if (exitCode !== 0 || !root.installedCommit) {
                root.updateStatus = "error";
                root.updateError = "Install fingerprint not found";
                return;
            }
            latestCommitDetection.running = true;
        }
    }

    Process {
        id: latestCommitDetection
        running: false
        command: ["sh", "-c", `git ls-remote https://github.com/acarlton5/HypeShell.git refs/heads/main 2>/dev/null | awk '{print substr($1,1,12)}'`]

        stdout: StdioCollector {
            onStreamFinished: root.latestCommit = root.shortCommit(text.trim())
        }

        onExited: exitCode => {
            if (exitCode !== 0 || !root.latestCommit) {
                root.updateStatus = "error";
                root.updateError = "Could not reach GitHub";
                return;
            }

            root.updateStatus = root.latestCommit === root.installedCommit ? "current" : "available";
        }
    }

    Process {
        id: versionDetection
        running: true
        command: ["sh", "-c", `cd "${Quickshell.shellDir}" && if [ -d .git ]; then echo "(git) $(git rev-parse --short HEAD)"; elif [ -f VERSION ]; then cat VERSION; fi`]

        stdout: StdioCollector {
            onStreamFinished: shellVersion = text.trim()
        }
    }

    Process {
        id: semverDetection
        running: true
        command: ["sh", "-c", `cd "${Quickshell.shellDir}" && if [ -f VERSION ]; then cat VERSION; fi`]

        stdout: StdioCollector {
            onStreamFinished: semverVersion = text.trim()
        }
    }

    Process {
        id: codenameDetection
        running: true
        command: ["sh", "-c", `cd "${Quickshell.shellDir}" && if [ -f CODENAME ]; then cat CODENAME; fi`]

        stdout: StdioCollector {
            onStreamFinished: shellCodename = text.trim()
        }
    }

    function parseVersion(versionStr) {
        if (!versionStr || typeof versionStr !== "string") {
            return {
                major: 0,
                minor: 0,
                patch: 0
            };
        }
        let v = versionStr.trim();
        if (v.startsWith("v")) {
            v = v.substring(1);
        }
        const dashIdx = v.indexOf("-");
        if (dashIdx !== -1) {
            v = v.substring(0, dashIdx);
        }
        const plusIdx = v.indexOf("+");
        if (plusIdx !== -1) {
            v = v.substring(0, plusIdx);
        }
        const parts = v.split(".");
        return {
            major: parseInt(parts[0], 10) || 0,
            minor: parseInt(parts[1], 10) || 0,
            patch: parseInt(parts[2], 10) || 0
        };
    }

    function compareVersions(v1, v2) {
        if (v1.major !== v2.major) {
            return v1.major - v2.major;
        }
        if (v1.minor !== v2.minor) {
            return v1.minor - v2.minor;
        }
        return v1.patch - v2.patch;
    }

    function checkVersionRequirement(requirementStr, currentVersion) {
        if (!requirementStr || typeof requirementStr !== "string") {
            return true;
        }
        const req = requirementStr.trim();
        let operator = ">=";
        let versionPart = req;
        switch (true) {
        case req.startsWith(">="):
            operator = ">=";
            versionPart = req.substring(2);
            break;
        case req.startsWith("<="):
            operator = "<=";
            versionPart = req.substring(2);
            break;
        case req.startsWith(">"):
            operator = ">";
            versionPart = req.substring(1);
            break;
        case req.startsWith("<"):
            operator = "<";
            versionPart = req.substring(1);
            break;
        case req.startsWith("="):
            operator = "=";
            versionPart = req.substring(1);
            break;
        }

        const reqVersion = parseVersion(versionPart);
        const cmp = compareVersions(currentVersion, reqVersion);
        switch (operator) {
        case ">=":
            return cmp >= 0;
        case ">":
            return cmp > 0;
        case "<=":
            return cmp <= 0;
        case "<":
            return cmp < 0;
        case "=":
            return cmp === 0;
        default:
            return cmp >= 0;
        }
    }
}
