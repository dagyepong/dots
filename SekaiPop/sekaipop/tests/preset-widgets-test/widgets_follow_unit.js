// Every desktop widget has to move itself when a preset hands its service
// another saved spot (DesktopPresetService.restoreWidget -> service.restore, or
// TodoService.setPosition). Quickshell can't be run here, so this reads the
// widgets' source: each one must listen to its service's posX / posY / posScale
// and place itself again, but never while it is being dragged.
const assert = require("assert"), fs = require("fs"), path = require("path")
const root = path.join(__dirname, "..", "..")
const widgets = {
    "ClockWidget.qml": "ClockService",
    "UserCardWidget.qml": "UserCardService",
    "WeatherCardWidget.qml": "WeatherCardService",
    "VisualizerWidget.qml": "VisualizerService",
    "TodoWidget.qml": "TodoService"
}
for (const [file, svc] of Object.entries(widgets)) {
    const src = fs.readFileSync(require("../lib/locate")(file), "utf8")
    const m = src.match(new RegExp("Connections \\{\\s*target: " + svc + "\\s*function onLoadedChanged[\\s\\S]*?\\n    \\}\\n"))
    assert.ok(m, file + ": Connections block for " + svc + " not found")
    for (const h of ["onPosXChanged", "onPosYChanged", "onPosScaleChanged"])
        assert.ok(m[0].includes(h), file + ": " + svc + " " + h + " is not handled")
    const t = src.match(/Timer \{\s*id: follow[\s\S]*?\n    \}\n/)
    assert.ok(t, file + ": follow timer missing")
    assert.ok(t[0].includes("dragArea.drag.active") && t[0].includes("chrome.dragging") && t[0].includes("win.place()"),
        file + ": follow timer must skip while dragging and call place()")
}
// A band-style visualizer sits by bandY / style, not posX / posY.
const viz = fs.readFileSync(require("../lib/locate")("VisualizerWidget.qml"), "utf8")
assert.ok(viz.includes("function onBandYChanged") && viz.includes("function onIsBandChanged"))
console.log("widgets_follow_unit: all checks passed")
