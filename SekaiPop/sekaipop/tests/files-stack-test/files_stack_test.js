// The dock's Files stack (DockFilesCard.qml, FilesStackService.qml). The QML can't be run here,
// so the wiring is read from source and the service's plain functions are run on their own.
// Run: node files_stack_test.js
const fs = require('fs'), assert = require('assert')
const root = __dirname + '/../../'
const rd = p => fs.readFileSync(root + p, 'utf8')
const SVC = rd('services/FilesStackService.qml'), CARD = rd('modules/sekai/dock/DockFilesCard.qml')
const ICON = rd('modules/sekai/dock/DockFilesIcon.qml'), DOCK = rd('modules/sekai/dock/Dock.qml')
const SET = rd('services/SettingsService.qml'), PRE = rd('services/DesktopPresetService.qml')
const PAGE = rd('modules/sekai/settings/SettingsPageDesktop.qml'), SHELL = rd('shell.qml')

// --- the service's functions, run with the few things they lean on stubbed ---
function grab(name) {
    const m = SVC.match(new RegExp('    function ' + name + '\\(([^)]*)\\) \\{\\n([\\s\\S]*?)\\n    \\}\\n'))
    assert.ok(m, 'function ' + name + ' exists')
    return m[0].replace(/root\./g, 'R.')
}
const R = { home: '/home/miku', userDirs: { DOWNLOAD: '/home/miku/Downloads', PICTURES: '/data/pics' },
    placeNames: { DOWNLOAD: 'Downloads', DOCUMENTS: 'Documents', PICTURES: 'Pictures', VIDEOS: 'Videos', MUSIC: 'Music', DESKTOP: 'Desktop' },
    kinds: { pdf: ['PDF', 'application-pdf'], png: ['Image', 'image-x-generic'] }, folderIcons: { Downloads: 'folder-download' },
    imageSuffixes: ['png', 'jpg', 'jpeg', 'webp', 'bmp', 'gif', 'svg'] }
const F = new Function('R', ['placePath', 'resolve', 'titleFor', 'suffixOf', 'isImage', 'iconNameFor', 'typeLabel', 'sizeText', 'oneLine']
    .map(n => grab(n).replace('function ' + n, 'R.' + n + ' = function')).join('\n') + '; return R')(R)

assert.strictEqual(F.resolve(''), '/home/miku/Downloads', 'empty = Downloads')
assert.strictEqual(F.resolve('pictures'), '/data/pics', 'a place name follows user-dirs.dirs')
assert.strictEqual(F.resolve('Documents'), '/home/miku/Documents', 'a place with no entry falls back to $HOME/<name>')
assert.strictEqual(F.resolve('~/Projects/'), '/home/miku/Projects')
assert.strictEqual(F.resolve('/mnt//data/'), '/mnt/data')
assert.strictEqual(F.resolve('notes'), '/home/miku/notes', 'a relative path is under $HOME')
assert.strictEqual(F.resolve('/'), '/')
assert.strictEqual(F.titleFor('/home/miku'), 'Home')
assert.strictEqual(F.titleFor('/home/miku/My Docs'), 'My Docs')
assert.strictEqual(F.suffixOf('a.tar.gz'), 'gz'); assert.strictEqual(F.suffixOf('.bashrc'), ''); assert.strictEqual(F.suffixOf('x.JPG'), 'jpg')
assert.ok(F.isImage('png') && !F.isImage('pdf') && !F.isImage(''))
assert.strictEqual(F.iconNameFor(true, '', 'Downloads'), 'folder-download')
assert.strictEqual(F.iconNameFor(true, '', 'stuff'), 'folder')
assert.strictEqual(F.iconNameFor(false, 'weird', 'x.weird'), 'text-x-generic')
assert.strictEqual(F.typeLabel(false, 'pdf'), 'PDF'); assert.strictEqual(F.typeLabel(false, 'xyz'), 'XYZ file'); assert.strictEqual(F.typeLabel(true, ''), 'Folder')
assert.deepStrictEqual([0, 999, 15400, 999499, 999500, 2.4e6].map(F.sizeText), ['0 B', '999 B', '15.4 kB', '999 kB', '1.0 MB', '2.4 MB'])
assert.strictEqual(F.oneLine('a\nb\tc'), 'a b c', 'a newline in a name stays on one line')

// --- safe by construction: a path is an argument, never part of a shell string ---
assert.ok(!/execDetached\(\[[^\]]*\+\s*(path|dir)/.test(SVC), 'no path is concatenated into a command')
assert.ok(/"xdg-open", path\]/.test(SVC) && /"wl-copy", "--", path\]/.test(SVC), 'argv form, with -- before the path')
assert.ok(/"sh", root\.fileUrl\(path\), dir\]/.test(SVC) && /"sh", root\.fileUrl\(path\)\]/.test(SVC), 'paths reach sh as $1 / $2')
assert.ok(/"sh", root\.path\]\)/.test(CARD), 'the folder check gets its path as $1')
// names are shown as plain text (a file called "<b>x</b>" must stay that)
const blocks = []
for (let i = CARD.indexOf('Text {'); i >= 0; i = CARD.indexOf('Text {', i + 1)) {
    if (/\w$/.test(CARD.slice(0, i))) continue   // MaterialIcon etc. do not end in a bare "Text"
    let d = 0, j = i + 5
    do { d += CARD[j] === '{' ? 1 : CARD[j] === '}' ? -1 : 0; j++ } while (d > 0)
    blocks.push(CARD.slice(i, j))
}
const nameTexts = blocks.filter(t => /cell\.fileName|row\.fileName|titleFor|hoverInfo|root\.path/.test(t))
assert.ok(nameTexts.length >= 5 && nameTexts.every(t => /textFormat: Text\.PlainText/.test(t)), 'every text that shows a file or folder name is PlainText')

// --- nothing runs in the background ---
assert.ok(/active: root\.visible \|\| keep\.running/.test(CARD) && /interval: 20000/.test(CARD), 'the listing only exists while shown (+20 s)')
assert.ok(!/Timer \{[^}]*repeat: true/.test(CARD + SVC), 'no repeating timer')
assert.ok(/pictures|thumbMaxBytes/.test(SVC) && /thumbMaxBytes/.test(ICON), 'big pictures are not decoded')
assert.ok(/sourceSize: Qt\.size\(root\.iconSize \* 2/.test(ICON) && /asynchronous: true/.test(ICON), 'thumbnails are decoded small and off the UI thread')

// --- wired into the dock ---
assert.ok(/DockFilesCard \{\s*\n\s*id: filesCard/.test(DOCK) && /open: dockWindow\.toolOpen === "files"/.test(DOCK))
assert.ok(/filesCard\.visible \? filesCard/.test(DOCK), 'its input area is in the dock mask')
assert.ok(/r\.tool === "files" && FilesStackService\.stackOn/.test(DOCK), 'the key opens the stack; "manager" mode keeps the old launch')
assert.ok(/toolOpen === "files"\) \? WlrKeyboardFocus\.OnDemand/.test(DOCK), 'Esc can reach the card')
assert.ok(/function toggleFiles\(\)/.test(DOCK) && /d\.toggleFiles\(\)/.test(SHELL), 'ipc call dock files')
assert.ok(/openFiles\(\)/.test(DOCK.split('MiddleButton) {')[1].slice(0, 600)), 'middle-click still opens the file manager')

// --- settings: each key has a default, is kept by presets, and has a control ---
for (const k of ['dock.filesMode', 'dock.files.folder', 'dock.files.view', 'dock.files.sort', 'dock.files.reverse', 'dock.files.hidden']) {
    assert.ok(new RegExp('"' + k.replace(/\./g, '\\.') + '":').test(SET), k + ' has a default')
    assert.ok(PRE.includes('"' + k + '"'), k + ' is left alone by presets')
    assert.ok(PAGE.includes('"' + k + '"'), k + ' is in the settings page')
}
assert.ok(/"dock\.filesCommand"/.test(SET), 'the old file-manager command is still there')
console.log('files stack: ok')
