// The Quick Panel's Wi-Fi and Bluetooth popups have an "Advanced" button that opens the full
// settings app. Node cannot load QML, so this reads the source for each link of the chain.
const fs = require("fs")
const path = require("path")
const assert = require("assert")
const root = path.join(__dirname, "..", "..")
const read = f => fs.readFileSync(path.join(root, f), "utf8")
const qp = "modules/sekai/quickPanel/"

for (const d of ["NetworkDialog", "BluetoothDialog"]) {
    const s = read(qp + d + ".qml")
    assert.ok(/signal advancedRequested\(\)/.test(s), d + " declares advancedRequested")
    assert.ok(/text: "Advanced"/.test(s) && /onClicked: root\.advancedRequested\(\)/.test(s), d + " has the button")
}
const face = read(qp + "QuickPanelFace.qml")
assert.ok(/signal wifiAdvancedRequested\(\)/.test(face) && /onAdvancedRequested: face\.wifiAdvancedRequested\(\)/.test(face), "Face passes the Wi-Fi signal up")
assert.ok(/signal bluetoothAdvancedRequested\(\)/.test(face) && /onAdvancedRequested: face\.bluetoothAdvancedRequested\(\)/.test(face), "Face passes the Bluetooth signal up")
const panel = read(qp + "QuickPanel.qml")
assert.ok(/onWifiAdvancedRequested:[\s\S]{0,120}openNetworkSettings\(\)/.test(panel), "QuickPanel opens the Wi-Fi app")
assert.ok(/onBluetoothAdvancedRequested:[\s\S]{0,120}openBluetoothSettings\(\)/.test(panel), "QuickPanel opens the Bluetooth app")
const src = read("services/QuickSource.qml")
assert.ok(/function openNetworkSettings\(\)[\s\S]{0,160}open-settings-app\.sh[\s\S]{0,20}"wifi"/.test(src), "QuickSource runs the script for wifi")
assert.ok(/function openBluetoothSettings\(\)[\s\S]{0,160}open-settings-app\.sh[\s\S]{0,20}"bluetooth"/.test(src), "QuickSource runs the script for bluetooth")
const sh = read("scripts/system/open-settings-app.sh")
assert.ok(sh.includes("kcmshell6 kcm_networkmanagement"), "Wi-Fi tries KDE's page first")
assert.ok(sh.indexOf("kcm_networkmanagement") < sh.indexOf("exec nm-connection-editor"), "nm-connection-editor is only the fallback")
assert.ok(sh.includes("exec blueman-manager"), "Bluetooth starts blueman first")
console.log("advanced_buttons_test: ok")
