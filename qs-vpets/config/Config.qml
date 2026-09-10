pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var pets: [
        {
            name: "Mochi",
            sprite: "charizard",
            personality: "energetic",
            scale: 2,
            monitor: "",
            actions: {}
        }
    ]

    property int idleTimeout: 300
    property real walkSpeed: 120

    readonly property string configDir: Quickshell.env("HOME") + "/.config/qs-vpets"
    readonly property string configPath: configDir + "/config.json"
    property bool _recentlySaved: false
    property string _pendingJson: ""

    signal configReady

    function save(): void { saveTimer.restart(); }

    function load(): void {
        try {
            var data = JSON.parse(configFile.text());
            if (data.pets) root.pets = data.pets;
            if (data.behavior) {
                var b = data.behavior;
                if (b.idleTimeout !== undefined) root.idleTimeout = b.idleTimeout;
                if (b.walkSpeed !== undefined) root.walkSpeed = b.walkSpeed;
            }
        } catch (e) {
            console.warn("qs-vpets: failed to load config:", e);
        }
    }

    function _serialize(): string {
        return JSON.stringify({
            pets: root.pets,
            behavior: {
                idleTimeout: root.idleTimeout,
                walkSpeed: root.walkSpeed,
            },
        }, null, 2);
    }

    Timer {
        id: saveTimer
        interval: 500
        onTriggered: {
            root._pendingJson = root._serialize();
            mkdirProcess.running = true;
        }
    }

    Timer { id: saveFlagReset; interval: 1500; onTriggered: root._recentlySaved = false }

    Process {
        id: mkdirProcess
        command: ["mkdir", "-p", root.configDir]
        onExited: {
            configFile.setText(root._pendingJson);
            root._recentlySaved = true;
            saveFlagReset.restart();
        }
    }

    FileView {
        id: configFile
        path: root.configPath
        watchChanges: true
        onFileChanged: {
            if (root._recentlySaved) return;
            root.load();
            root.configReady();
        }
        onLoaded: {
            if (root._recentlySaved) return;
            root.load();
            root.configReady();
        }
        onLoadFailed: err => {
            if (err !== FileViewError.FileNotFound)
                console.warn("qs-vpets: config read failed:", err);
            root.save();
            root.configReady();
        }
    }
}
