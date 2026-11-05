// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   E M O J I   S E R V I C E                                              │
// │   emoji index · search, groups, skin tone, recent picks and copy         │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../theme"

// The emoji a launcher mode searches. `emoji.py` reads the Unicode and CLDR
// data files the first time the mode is entered, named in the shell's
// language and searchable in it and in English. The recent picks are kept in
// the state directory and shared by every profile, like the clipboard.
Singleton {
    id: root

    // `{ glyph, name, group, keywords, tones? }`, in Unicode's order.
    // `tones` is five glyphs, light to dark, for emoji that take one.
    property var emoji: []

    readonly property string language: SettingsService.language

    // Read the first time the mode is entered after the launcher opens, as
    // the application index is rebuilt on open: the list is two thousand rows
    // nobody needs until then, and data installed since is picked up. The old
    // list stays on screen until the new one lands.
    property bool fresh: false

    function load(): void {
        if (root.fresh || root.indexProcess.running)
            return
        root.fresh = true
        root.indexProcess.running = true
    }

    onLanguageChanged: root.fresh = false

    readonly property Process indexProcess: Process {
        command: [Quickshell.shellPath("scripts/emoji.py"), root.language]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.emoji = JSON.parse(text)
                } catch (error) {
                    console.warn("Cannot parse the emoji list:", error)
                }
            }
        }
    }

    // ── GROUPS ──────────────────────────────────────────────────────────────
    //
    // Unicode's nine, each marked by its first emoji. `""` is every group,
    // with the recent picks first.
    readonly property var groups: [
        { id: "",                  mark: "🕘", label: "Recent" },
        { id: "Smileys & Emotion", mark: "😀", label: "Smileys & Emotion" },
        { id: "People & Body",     mark: "👋", label: "People & Body" },
        { id: "Animals & Nature",  mark: "🐻", label: "Animals & Nature" },
        { id: "Food & Drink",      mark: "🍔", label: "Food & Drink" },
        { id: "Travel & Places",   mark: "✈️", label: "Travel & Places" },
        { id: "Activities",        mark: "⚽", label: "Activities" },
        { id: "Objects",           mark: "💡", label: "Objects" },
        { id: "Symbols",           mark: "❤️", label: "Symbols" },
        { id: "Flags",             mark: "🏁", label: "Flags" }
    ]

    // The group the list is narrowed to. Cleared when the launcher closes.
    property string group: ""

    function stepGroup(delta: int): void {
        const ids = root.groups.map(entry => entry.id)
        const at = ids.indexOf(root.group)
        root.group = ids[(at + delta + ids.length) % ids.length]
    }

    // ── SKIN TONE ───────────────────────────────────────────────────────────
    //
    // One tone for every emoji that takes one, as a keyboard's emoji picker
    // does. The row's mark is the tone itself, drawn on a raised hand.
    readonly property int tone: SettingsService.emojiTone

    readonly property var toneMarks: ["✋", "✋🏻", "✋🏼", "✋🏽", "✋🏾", "✋🏿"]

    function stepTone(): void {
        SettingsService.set("emojiTone", (root.tone + 1) % root.toneMarks.length)
    }

    function glyphOf(item: var): string {
        return root.tone > 0 && item.tones ? item.tones[root.tone - 1] : item.glyph
    }

    // ── RECENT ──────────────────────────────────────────────────────────────
    //
    // Base glyphs, most recent first, so a change of tone applies to them too.
    readonly property int keepRecent: 24

    property var recent: []

    readonly property FileView recentFile: FileView {
        path: `${SettingsService.stateDirectory}/emoji-recent.json`
        watchChanges: true

        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoaded: root.recent = kept.recent ?? []
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter()
        }

        JsonAdapter {
            id: kept

            property var recent: []
        }
    }

    function remember(glyph: string): void {
        const next = [glyph].concat(root.recent.filter(other => other !== glyph))
            .slice(0, root.keepRecent)
        root.recent = next
        kept.recent = next
    }

    // ── SEARCH ──────────────────────────────────────────────────────────────

    // Lowercase without accents, as the script folds the keywords.
    function fold(text: string): string {
        return text.toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "")
    }

    // Group id -> its name in the shell's language, folded.
    readonly property var groupWords: {
        const out = ({})
        for (const entry of root.groups)
            out[entry.id] = root.fold(Tr.t(entry.label))
        return out
    }

    // Every word of the term must appear in the keywords or the group's name
    // in the shell's language. Names starting with the term come first, then
    // Unicode's order, which keeps related emoji together. With no term and
    // no group, the recent picks lead.
    function search(term: string): var {
        const words = root.fold(term).split(/\s+/).filter(word => word !== "")
        const phrase = words.join(" ")

        const lead = []
        const rest = []
        for (const item of root.emoji) {
            if (root.group !== "" && item.group !== root.group)
                continue
            if (words.length > 0) {
                const haystack = `${item.keywords} ${root.groupWords[item.group] ?? ""}`
                if (!words.every(word => haystack.includes(word)))
                    continue
            }
            if (phrase !== "" && root.fold(item.name).startsWith(phrase))
                lead.push(item)
            else
                rest.push(item)
        }

        if (words.length === 0 && root.group === "") {
            const byGlyph = ({})
            for (const item of root.emoji)
                byGlyph[item.glyph] = item
            const recent = root.recent.map(glyph => byGlyph[glyph]).filter(item => !!item)
            return recent.concat(rest.filter(item => recent.indexOf(item) < 0))
        }
        return lead.concat(rest)
    }

    function copy(item: var): void {
        root.remember(item.glyph)
        Quickshell.execDetached(["wl-copy", "--", root.glyphOf(item)])
    }
}
