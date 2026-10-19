// Finds a source file by path, or by bare file name when it has moved, so the
// tests do not care which folder a file lives in.
const fs = require("fs"), path = require("path")
const top = path.join(__dirname, "..", "..")
let index = null
function build() {
    index = {}
    const walk = dir => {
        for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
            if (e.isDirectory()) walk(path.join(dir, e.name))
            else (index[e.name] = index[e.name] || []).push(path.join(dir, e.name))
        }
    }
    for (const d of ["modules", "services", "scripts"]) walk(path.join(top, d))
}
module.exports = rel => {
    const direct = path.join(top, rel)
    if (fs.existsSync(direct)) return direct
    if (!index) build()
    const hits = index[path.basename(rel)] || []
    if (hits.length !== 1) throw new Error("locate(" + rel + "): " + hits.length + " matches")
    return hits[0]
}
