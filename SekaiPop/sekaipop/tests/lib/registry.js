// Reads the REAL widget list out of services/PresetWidgets.qml and evaluates it against
// fakes, so the tests check the file the shell uses, not a copy of it. The list is plain
// JavaScript (object literals and arrow functions), which is the whole point of keeping
// it that way.
//
//   const { ids, services, load } = require("../lib/registry")
//   const list = load({ TodoService: myFake, ... })   // any service not given is a bare stub
const fs = require("fs")
const PP = require("./presetparts")
const text = fs.readFileSync(require("./locate")("services/PresetWidgets.qml"), "utf8")

function listSource() {
    const head = "readonly property var list: ["
    const start = text.indexOf(head)
    if (start < 0) throw new Error("PresetWidgets.qml: `readonly property var list: [` not found")
    let i = start + head.length - 1, depth = 0
    for (; i < text.length; i++) {
        const c = text[i]
        if (c === "[") depth++
        else if (c === "]" && --depth === 0) break
    }
    return text.slice(start + head.length - 1, i + 1)
}

const src = listSource()
// `service: FooService` and `id: "foo"`, in order, straight from the text.
const entries = [...src.matchAll(/\bid:\s*"([^"]+)",\s*service:\s*(\w+)/g)].map(m => ({ id: m[1], service: m[2] }))

function load(fakes) {
    const all = {}
    for (const e of entries) all[e.service] = (fakes && fakes[e.service]) || {}
    const extra = Object.assign({ PP, DesktopPresetService: {} }, fakes || {})
    const scope = Object.assign({}, all, extra)
    const keys = Object.keys(scope)
    return new Function(...keys, "return " + src)(...keys.map(k => scope[k]))
}

module.exports = { text, src, entries, ids: entries.map(e => e.id), services: entries.map(e => e.service), load }
