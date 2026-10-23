import QtQuick

// The chat window as a small terminal: a line whose first word is one of
// these commands runs here instead of going to the AI. No "aibou" in front,
// and without a figure it is the first one (the one in the chat). A figure
// is named by name (shiro) or number (2); pair commands take one or two.
//   kiss · kiss shiro · kiss shiro kuro · angry 3 · angry 3 shiro · sleep all
// A line that does not fit a command (unknown words after it) is not one:
// "happy birthday" goes to the AI, "happy 3" is a command.
// run() returns null for "not a command", else { ok, out }.
Item {
    id: cmds
    required property var shell
    required property var world
    readonly property var brains: shell.brains
    readonly property bool de: world.lang === "de"
    function t(deText, enText, jaText) { return world.tr(deText, enText, jaText) }

    // ── figures ───────────────────────────────────────────────────
    function active() { return brains.filter(b => b.st.active) }
    function figure(tok) {
        if (/^[1-5]$/.test(tok)) {
            const b = brains[parseInt(tok) - 1]
            return b && b.st.active ? b : null
        }
        for (const b of active()) if (b.st.skin === tok || b.st.name.toLowerCase() === tok) return b
        return null
    }
    function isAll(tok) { return tok === "all" || tok === "alle" }
    function listNames() { return active().map((b, i) => (i + 1) + " " + b.st.name).join(", ") }
    // the nearest other figure, for a pair command with one name only
    function nearest(b) {
        let best = null, d = 1e9
        for (const o of active()) if (o !== b) {
            const dd = Math.abs(o.st.x0 - b.st.x0)
            if (dd < d) { d = dd; best = o }
        }
        return best
    }

    // ── doing it where it can be seen ─────────────────────────────
    // A figure in the chat window jumps out for anything that needs walking
    // and back in afterwards; one in the frame comes out first (in front of
    // the windows, so the command can be seen).
    function out(b, f) {
        if (b.st.place === "chat" && world.chatOpen) { b.leaveChatFor(f); return }
        // behind the windows with nothing in front of him: he is visible
        // already, so he just steps forward instead of diving under the frame
        if (b.st.place === "home" && b.doing === "idle" && !b.st.moving && !world.windowOver(b.st.x0, b.st.size * 0.5)) {
            b.st.place = "stage"
            b.st.restX = b.st.x0
            f()
            return
        }
        b.whenFree(f, true)
    }
    // both on the floor in front, then f
    property var waiting: []
    Timer {
        interval: 150; repeat: true
        running: cmds.waiting.length > 0
        onTriggered: {
            const now = Date.now()
            const keep = []
            for (const w of cmds.waiting) {
                // a figure that left the chat for this waits with going back
                for (const b of w.hold) b.chatHold = now + 2500
                if (w.ready()) w.f()
                else if (now < w.until) keep.push(w)
            }
            cmds.waiting = keep
        }
    }
    function when(ready, f, ms, hold) {
        for (const b of hold || []) b.chatHold = Date.now() + 2500
        waiting = waiting.concat([{ ready: ready, f: f, until: Date.now() + (ms || 15000), hold: hold || [] }])
    }
    function onFloor(b) { return (b.st.place === "stage" || b.st.place === "home") && b.doing === "idle" && !b.st.moving }
    function pair(a, o, f) {
        out(a, () => {})
        out(o, () => {})
        // both in front of the windows: whoever is behind them comes forward
        when(() => {
            for (const b of [a, o]) if (b.st.place === "home" && b.doing === "idle" && !b.st.moving) b.whenFree(() => {}, true)
            return onFloor(a) && onFloor(o) && a.st.place === o.st.place
        }, () => f(), 20000, [a, o])
    }

    // ── the commands ──────────────────────────────────────────────
    // kind: one (a figure or all), pair (one or two), mood (level and a figure), none
    readonly property var moodNames: ({
        angry: "angry", wütend: "angry", wuetend: "angry", böse: "angry", boese: "angry", sauer: "angry",
        sad: "sad", traurig: "sad", happy: "happy", froh: "happy", fröhlich: "happy",
        scared: "scared", angst: "scared", blush: "blush", rot: "blush", verliebt: "blush",
        shy: "shy", schüchtern: "shy", surprised: "surprised", überrascht: "surprised",
        sleepy: "sleepy", müde: "sleepy", smug: "smug", frech: "smug", proud: "proud", stolz: "proud",
        curious: "curious", neugierig: "curious", neutral: "neutral", ruhig: "neutral"
    })
    readonly property var table: [
        { group: "pair", label: ["Kuss", "Kiss", "キス"], names: ["kiss", "kuss", "küss", "kuess"], kind: "pair", meet: "kiss",
          de: "Kuss (kiss · kiss shiro · kiss shiro kuro)", en: "a kiss (kiss · kiss shiro · kiss shiro kuro)", ja: "キス (kiss · kiss shiro · kiss shiro kuro)" },
        { group: "pair", label: ["Umarmen", "Hug", "ハグ"], names: ["hug", "umarmen", "drück"], kind: "pair", meet: "hug", de: "Umarmung", en: "a hug", ja: "ハグ" },
        { group: "pair", label: ["High Five", "High five", "ハイタッチ"], names: ["five", "highfive", "abklatschen"], kind: "pair", meet: "five", de: "High Five", en: "a high five", ja: "ハイタッチ" },
        { group: "pair", label: ["Hallo sagen", "Say hello", "あいさつ"], names: ["greet", "hallo", "hello", "hi"], kind: "pair", meet: "wave", de: "hingehen und winken", en: "go over and wave", ja: "そばに行って手をふる" },
        { group: "play", label: ["Tanzen", "Dance", "ダンス"], names: ["dance", "tanz", "tanzen"], kind: "one", fn: "dance", de: "tanzen (ohne Musik zu eigenem Takt)", en: "dance (to a beat of its own without music)", ja: "ダンス (音楽がないときは自分のリズムで)" },
        { group: "pair", label: ["Paartanz", "Dance together", "ペアダンス"], names: ["duet", "duett", "paartanz"], kind: "pair", fn: "duet", de: "zu zweit tanzen", en: "dance as a pair", ja: "ふたりでダンス" },
        { group: "pair", label: ["Streiten", "Quarrel", "けんか"], names: ["quarrel", "streit", "streiten"], kind: "pair", fn: "quarrel", de: "Streit anfangen", en: "start a quarrel", ja: "けんかを始める" },
        { group: "pair", label: ["Anstupsen", "Poke", "つつく"], names: ["poke", "stups", "necken"], kind: "pair", fn: "tease", de: "anstupsen", en: "poke", ja: "つつく" },
        { group: "move", label: ["Springen", "Jump", "ジャンプ"], names: ["jump", "hüpf", "hüpfen", "spring"], kind: "one", fn: "jump", de: "Sprung", en: "jump", ja: "ジャンプ" },
        { group: "move", label: ["Drehen", "Spin", "くるっと回る"], names: ["spin", "dreh", "drehen"], kind: "one", fn: "spin", de: "Drehung", en: "spin", ja: "くるっと回る" },
        { group: "move", label: ["Winken", "Wave", "手をふる"], names: ["wave", "wink", "winken"], kind: "one", fn: "wave", de: "winken", en: "wave", ja: "手をふる" },
        { group: "move", label: ["Jubeln", "Cheer", "ばんざい"], names: ["cheer", "jubel", "jubeln"], kind: "one", fn: "cheer", de: "jubeln", en: "cheer", ja: "ばんざい" },
        { group: "move", label: ["Boxen", "Punch", "パンチ"], names: ["box", "boxen", "punch"], kind: "one", fn: "box", de: "boxen", en: "punch", ja: "パンチ" },
        { group: "move", label: ["In die Knie", "Squat", "しゃがむ"], names: ["squat", "knie", "ducken"], kind: "one", fn: "squat", de: "in die Knie", en: "squat", ja: "しゃがむ" },
        { group: "move", label: ["Kitzeln", "Tickle", "くすぐる"], names: ["tickle", "kitzel", "kitzeln"], kind: "one", fn: "tickle", de: "kitzeln", en: "tickle", ja: "くすぐる" },
        { group: "place", label: ["Schlafen", "Sleep", "ねる"], names: ["sleep", "schlaf", "schlafen"], kind: "one", fn: "sleep", de: "schlafen legen", en: "go to sleep", ja: "ねかせる" },
        { group: "place", label: ["Aufwecken", "Wake", "おきる"], names: ["wake", "wach", "aufwachen"], kind: "one", fn: "wake", de: "aufwecken", en: "wake up", ja: "おこす" },
        { group: "place", label: ["In den Rahmen", "Into the frame", "フレームへ"], names: ["dock", "rahmen"], kind: "one", fn: "dock", de: "in den Rahmen", en: "into the frame", ja: "フレームにとけこむ" },
        { group: "place", label: ["Aus dem Rahmen", "Out of the frame", "フレームから出る"], names: ["out", "raus"], kind: "one", fn: "outOf", de: "aus dem Rahmen holen", en: "out of the frame", ja: "フレームから出てくる" },
        { group: "place", label: ["Nach vorne", "To the front", "前へ"], names: ["front", "vorne", "vor"], kind: "one", fn: "front", de: "vor die Fenster", en: "in front of the windows", ja: "ウィンドウの前へ" },
        { group: "place", label: ["Nach hinten", "To the back", "うしろへ"], names: ["back", "hinten", "zurück"], kind: "one", fn: "back", de: "zurück hinter die Fenster", en: "back behind the windows", ja: "ウィンドウのうしろへ戻る" },
        { group: "move", label: ["Seilpistole", "Grapple", "ロープガン"], names: ["grapple", "seil", "seilpistole", "hook"], kind: "one", fn: "grapple", de: "mit der Seilpistole nach oben, von überall", en: "up with the grappling gun, from anywhere", ja: "どこからでもロープガンで上へ" },
        { group: "move", label: ["Affe", "Monkey", "おさる"], names: ["monkey", "affe", "hangeln"], kind: "one", fn: "monkey", de: "hoch und lange an der Oberkante herumturnen", en: "up, and a long monkey act at the top edge", ja: "上へのぼって、上の端で長めのおさる芸" },
        { group: "play", label: ["Wettrennen", "Race", "かけっこ"], names: ["race", "rennen", "wettrennen"], kind: "pair", fn: "race", de: "Wettrennen zum Rand", en: "a race to the edge", ja: "端までかけっこ" },
        { group: "play", label: ["Bockspringen", "Leapfrog", "馬とび"], names: ["frog", "leapfrog", "bock", "bockspringen"], kind: "group", fn: "frog", de: "Bockspringen in der Reihe, alle", en: "leapfrog in a row, everybody", ja: "みんなで一列に馬とび" },
        { group: "play", label: ["Seilspringen", "Jump rope", "なわとび"], names: ["rope", "jumprope", "seil", "seilspringen"], kind: "group", fn: "rope", de: "Seilspringen (zu zweit: ein Ende am Rand)", en: "jump rope (two of them: one end tied to the edge)", ja: "なわとび (ふたりのときは片方を端に結ぶ)" },
        { group: "play", label: ["Schnick-Schnack-Schnuck", "Rock paper scissors", "じゃんけん"], names: ["rps", "schnick", "ssp"], kind: "pair", fn: "rpsCmd", de: "Stein, Schere, Papier", en: "rock, paper, scissors", ja: "じゃんけん" },
        { group: "play", label: ["Jonglieren", "Juggle", "ジャグリング"], names: ["juggle", "jonglieren"], kind: "one", fn: "juggleCmd", de: "jonglieren (Shiros Hobby)", en: "juggle (Shiro's hobby)", ja: "ジャグリング (Shiro の趣味)" },
        { group: "play", label: ["Yoga", "Yoga", "ヨガ"], names: ["yoga"], kind: "one", fn: "yogaCmd", de: "Yoga (Momos Hobby)", en: "yoga (Momo's hobby)", ja: "ヨガ (Momo の趣味)" },
        { group: "play", label: ["Polieren", "Polish", "みがく"], names: ["polish", "polieren"], kind: "one", fn: "polishCmd", de: "sich blank polieren (Kuros Hobby)", en: "polish himself (Kuro's hobby)", ja: "自分をみがく (Kuro の趣味)" },
        { group: "play", label: ["Imbiss", "Snack", "おやつ"], names: ["snack", "essen", "imbiss"], kind: "one", fn: "snackCmd", de: "etwas essen (Bao am liebsten)", en: "a snack (Bao's favourite)", ja: "おやつ (Bao の大好物)" },
        { group: "play", label: ["Reparieren", "Repair", "しゅうり"], names: ["repair", "reparieren", "werkeln"], kind: "one", fn: "repairCmd", de: "am Rahmen werkeln (Robos Hobby)", en: "tinker with the frame (Robo's hobby)", ja: "フレームをいじる (Robo の趣味)" },
        { group: "place", label: ["Nickerchen oben", "Nap up top", "上でおひるね"], names: ["nap", "nickerchen"], kind: "one", fn: "napCmd", de: "hochklettern und oben im Rahmen schlafen", en: "climb up and sleep in the top frame", ja: "上にのぼって上のフレームでねる" },
        { group: "move", label: ["Banane", "Banana", "バナナ"], names: ["banana", "banane"], kind: "one", fn: "bananaCmd", de: "hoch, oben eine Banane essen, die Schale fällt", en: "up, eat a banana at the top, the peel drops", ja: "上でバナナを食べる、皮が落ちてくる" },
        { group: "play", label: ["Fangen", "Tag", "おにごっこ"], names: ["tag", "fangen", "fang"], kind: "pair", fn: "tag", de: "Fangen spielen", en: "play tag", ja: "おにごっこをする" },
        { group: "play", label: ["Verstecken", "Hide and seek", "かくれんぼ"], names: ["hide", "verstecken", "seek"], kind: "pair", fn: "hideSeek", de: "Verstecken (die erste sucht)", en: "hide and seek (the first one seeks)", ja: "かくれんぼ (最初の子がオニ)" },
        { group: "pair", label: ["Abklatschen oben", "High five up there", "上でハイタッチ"], names: ["airfive", "luftfive", "oben"], kind: "pair", fn: "airFive", de: "beide hoch, in der Luft abklatschen", en: "both up, a high five in the air", ja: "ふたりで上へ、空中でハイタッチ" },
        { group: "move", label: ["Schaukeln", "Swing", "ブランコ"], names: ["swing", "schaukeln", "schaukel"], kind: "one", fn: "swingCmd", de: "hoch, schaukeln und mit Salto abspringen", en: "up, swing and jump off with a flip", ja: "上でブランコして、宙返りで飛びおりる" },
        { group: "move", label: ["Klettern", "Climb", "のぼる"], names: ["climb", "klettern", "kletter"], kind: "one", fn: "climb", de: "klettern", en: "climb", ja: "のぼる" },
        { group: "move", label: ["Laufen", "Walk", "おさんぽ"], names: ["walk", "lauf", "laufen"], kind: "one", fn: "walk", de: "ein Stück laufen", en: "walk a bit", ja: "すこし歩く" },
        { group: "move", label: ["Rollen", "Roll", "ころがる"], names: ["roll", "rollen", "roll"], kind: "one", fn: "roll", de: "ein Stück rollen", en: "roll a bit", ja: "すこし転がる" },
        { group: "play", label: ["Ballspiel", "Play ball", "ボール遊び"], names: ["play", "ball", "spielen"], kind: "one", fn: "play", de: "Ballspiel", en: "play ball", ja: "ボール遊び" },
        { group: "play", label: ["Stopp", "Stop", "やめる"], names: ["stop", "halt"], kind: "none", fn: "stop", de: "Spiel und Tanz beenden", en: "stop playing", ja: "遊びをやめる" },
        { group: "chat", label: ["Figur dazu", "Add a figure", "仲間を呼ぶ"], names: ["more", "mehr", "+"], kind: "none", fn: "more", de: "eine Figur mehr", en: "one more figure", ja: "仲間をひとり呼ぶ" },
        { group: "chat", label: ["Figur weg", "Remove a figure", "仲間を減らす"], names: ["fewer", "weniger", "-"], kind: "none", fn: "fewer", de: "eine Figur weniger", en: "one figure less", ja: "仲間をひとり減らす" },
        { group: "chat", label: ["Wer ist da", "Who is there", "だれがいる?"], names: ["who", "wer", "status"], kind: "none", fn: "who", de: "wer ist da, was macht wer", en: "who is there, doing what", ja: "だれがいて、なにをしているか" },
        { group: "none", label: ["Modell", "Model", "モデル"], names: ["model", "modell"], kind: "word", fn: "model", de: "Modell oder Anbieter wählen (model sonnet)", en: "choose the model or provider (model sonnet)", ja: "モデルかプロバイダーを選ぶ (model sonnet)" },
        { group: "chat", label: ["Modelle", "Models", "モデル一覧"], names: ["models", "modelle"], kind: "none", fn: "models", de: "alle Modelle und Anbieter", en: "all models and providers", ja: "すべてのモデルとプロバイダー" },
        { group: "chat", label: ["Fenster leeren", "Clear window", "画面をきれいに"], names: ["clear", "cls", "leeren"], kind: "none", fn: "clear", de: "Fenster leeren", en: "clear the window", ja: "画面をきれいにする" },
        { group: "chat", label: ["Vergessen", "Forget", "わすれる"], names: ["forget", "vergessen"], kind: "none", fn: "forget", de: "Gespräch vergessen", en: "forget the conversation", ja: "会話をわすれる" },
        { group: "chat", label: ["Hilfe", "Help", "ヘルプ"], names: ["help", "hilfe", "?"], kind: "none", fn: "help", de: "diese Liste", en: "this list", ja: "この一覧" }
    ]
    // ── the legend in the chat window (ChatWindow.qml) ────────────
    readonly property var groupNames: [
        ["pair", "Zu zweit", "Together", "ふたりで"], ["move", "Bewegen", "Moves", "うごき"], ["play", "Spiel und Tanz", "Play and dance", "遊びとダンス"],
        ["place", "Wo und wach", "Where and awake", "場所とねおき"], ["chat", "Fenster und Figuren", "Window and figures", "画面と仲間"]
    ]
    // the moods once each, in a sensible order, with their names
    readonly property var moodList: [
        ["happy", "froh", "happy", "うれしい"], ["angry", "wütend", "angry", "おこ"], ["sad", "traurig", "sad", "かなしい"], ["scared", "Angst", "scared", "こわい"],
        ["blush", "verlegen", "blushing", "てれてれ"], ["shy", "schüchtern", "shy", "もじもじ"], ["surprised", "überrascht", "surprised", "びっくり"],
        ["sleepy", "müde", "sleepy", "ねむい"], ["smug", "frech", "smug", "どや"], ["proud", "stolz", "proud", "えっへん"], ["curious", "neugierig", "curious", "きょうみしんしん"],
        ["neutral", "ruhig", "calm", "おだやか"]
    ]
    // [{ key, title, items: [{ cmd, label, desc, kind }] }]
    function legend() {
        const out = []
        for (const g of groupNames) {
            const items = table.filter(c => c.group === g[0]).map(c => ({
                cmd: c.names[0], label: t(c.label[0], c.label[1], c.label[2]), desc: t(c.de, c.en, c.ja), kind: c.kind }))
            if (items.length) out.push({ key: g[0], title: t(g[1], g[2], g[3]), items: items })
        }
        return out
    }

    readonly property var allNames: {
        const n = []
        for (const c of table) for (const x of c.names) n.push(x)
        for (const m in moodNames) n.push(m)
        return n
    }

    function run(text) {
        let words = text.trim().toLowerCase().split(/\s+/)
        if (words[0] === "aibou" && words.length > 1) words = words.slice(1)   // out of habit
        const name = words[0], args = words.slice(1)
        if (moodNames[name] !== undefined) return mood(moodNames[name], args)
        const c = table.find(x => x.names.indexOf(name) >= 0)
        if (!c) return null
        world.commandAt = Date.now()           // do not disturb lets it run
        if (c.kind === "none" || c.kind === "group") return args.length ? null : cmds[c.fn]()
        if (c.kind === "word") return args.length ? cmds[c.fn](args.join(" ")) : null
        if (c.kind === "one") {
            if (args.length > 1) return null
            if (args.length === 1 && isAll(args[0])) {
                const r = active().map(b => cmds[c.fn](b))
                return { ok: r.every(x => x.ok), out: r.map(x => x.out).join("\n") }
            }
            const b = args.length ? figure(args[0]) : brains[0]
            if (!b) return knownName(args[0]) ? nobody(args[0]) : null
            return cmds[c.fn](b)
        }
        // pair
        if (args.length > 2) return null
        let a = brains[0], o = null
        if (args.length === 2) { a = figure(args[0]); o = figure(args[1]) }
        else if (args.length === 1) { o = figure(args[0]); if (o === a) o = nearest(a) }
        else o = nearest(a)
        if (args.length && (!a || !o)) {
            // "kiss me" or "hug the cat": a sentence, not a command
            const bad = args.find(x => !figure(x))
            return knownName(bad) ? nobody(bad) : null
        }
        if (!o) return { ok: false, out: t("Dafür braucht es zwei Figuren (more holt eine dazu).", "That needs two figures (more brings one).", "それにはふたり必要だよ (more でひとり呼べる)。") }
        if (a === o) return { ok: false, out: t("Mit sich selbst geht das nicht.", "Not with itself.", "自分とはできないよ。") }
        return c.meet ? meetUp(a, o, c.meet) : cmds[c.fn](a, o)
    }
    // a figure's name or number that is just not there right now (else: a sentence)
    function knownName(tok) { return /^[1-5]$/.test(tok) || ["kuro", "shiro", "mochi", "momo", "robo", "bao", "neko", "kumo", "tako", "hiyoko", "arai"].indexOf(tok) >= 0 }
    function nobody(tok) {
        return { ok: false, out: t("Keine Figur „" + tok + "“. Da sind: " + listNames() + ".", "No figure \"" + tok + "\". There are: " + listNames() + ".", "「" + tok + "」という子はいないよ。いるのは: " + listNames() + "。") }
    }

    // ── what they do ──────────────────────────────────────────────
    readonly property var meetWords: ({
        kiss: ["gibt %2 einen Kuss.", "gives %2 a kiss.", "が %2 にキス。"], hug: ["umarmt %2.", "hugs %2.", "が %2 をハグ。"],
        five: ["klatscht mit %2 ab.", "high-fives %2.", "が %2 とハイタッチ。"], wave: ["geht zu %2 und winkt.", "goes over to %2 and waves.", "が %2 のところへ行って手をふる。"]
    })
    function meetUp(a, o, kind) {
        pair(a, o, () => a.meet(o.st, kind))
        const w = meetWords[kind]
        return { ok: true, out: a.st.name + " " + t(w[0], w[1], w[2]).replace("%2", o.st.name) }
    }
    function duet(a, o) {
        pair(a, o, () => { a.startDuet(o.st); beatsFor(44) })
        return { ok: true, out: a.st.name + t(" holt " + o.st.name + " zum Tanzen.", " asks " + o.st.name + " to dance.", " が " + o.st.name + " をダンスにさそう。") }
    }
    function dance(b) {
        out(b, () => {})
        beatsFor(16)
        return { ok: true, out: b.st.name + t(" tanzt", " dances", " がダンス") + (world.music && !fakeOn ? t(".", ".", "。") : t(" zu einem eigenen Takt.", " to a beat of its own.", " (自分のリズムで)。")) }
    }
    // without music: a beat of their own, 120 a minute; real music takes over
    property bool fakeOn: false
    property int fakeBeats: 0
    function beatsFor(n) {
        if (world.music && !fakeOn) return
        fakeOn = true
        world.music = true
        fakeBeats = Math.max(fakeBeats, n)
    }
    function stopFake() { fakeBeats = 0; fakeOn = false }
    Timer {
        interval: 500; repeat: true
        running: cmds.fakeBeats > 0
        onTriggered: {
            cmds.fakeBeats--
            cmds.world.bpm = 120
            cmds.world.beat(0.8)
            if (cmds.fakeBeats === 0 && cmds.fakeOn) { cmds.fakeOn = false; cmds.world.music = false }
        }
    }
    function quarrel(a, o) {
        pair(a, o, () => {
            a.quarrelTarget = o.st
            a.doing = "toQuarrel"
            const side = o.st.x0 > a.st.x0 ? -1 : 1
            a.walkTarget = Math.max(a.st.minX, Math.min(a.st.maxX, o.st.x0 + side * (o.st.size + a.st.size) * 0.55))
            a.nextHop()
        })
        return { ok: true, out: a.st.name + t(" sucht Streit mit " + o.st.name + ".", " picks a fight with " + o.st.name + ".", " が " + o.st.name + " にけんかを売る。") }
    }
    function tease(a, o) {
        pair(a, o, () => {
            a.friend = o.st
            a.doing = "tease"
            const side = o.st.x0 > a.st.x0 ? -1 : 1
            a.walkTarget = Math.max(a.st.minX, Math.min(a.st.maxX, o.st.x0 + side * (o.st.size + a.st.size) * 0.55))
            a.nextHop()
        })
        return { ok: true, out: a.st.name + t(" stupst " + o.st.name + " an.", " pokes " + o.st.name + ".", " が " + o.st.name + " をつつく。") }
    }
    // a gesture: in the frame the dome does what it can, in the chat window the face
    function gesture(b, inDock, onFloor, word) {
        if (b.st.place === "dock") inDock()
        else if (b.st.place === "chat") { b.st.mood = "happy"; b.moodBackLater() }
        else out(b, onFloor)
        return { ok: true, out: b.st.name + " " + word }
    }
    function jump(b) { return gesture(b, () => b.st.dockMove("peek", 1, 1, 1), () => b.st.jump(34), t("springt.", "jumps.", "がジャンプ。")) }
    function spin(b) { return gesture(b, () => b.st.dockMove("spin", 1, 1, 0), () => b.st.spin(1), t("dreht sich.", "spins.", "がくるっと回る。")) }
    function wave(b) { return gesture(b, () => b.st.dockMove("wave", 1, 1, 0), () => b.st.wave(), t("winkt.", "waves.", "が手をふる。")) }
    function cheer(b) { return gesture(b, () => b.st.dockMove("up", 1, 1, 0), () => { b.st.mood = "happy"; b.st.cheer() }, t("jubelt.", "cheers.", "がばんざい。")) }
    function box(b) { return gesture(b, () => b.st.dockMove("box", 1, 1, 0), () => b.st.punch(b.st.gazeX < 0 ? -1 : 1), t("boxt.", "punches.", "がパンチ。")) }
    function squat(b) { return gesture(b, () => b.st.jolt(), () => b.st.squat(), t("geht in die Knie.", "squats.", "がしゃがむ。")) }
    function tickle(b) { b.tickle(); return { ok: true, out: b.st.name + t(" wird gekitzelt.", " gets tickled.", " をくすぐった。") } }
    function sleep(b) { b.goSleep(true); return { ok: true, out: b.st.name + t(" legt sich schlafen.", " goes to sleep.", " はおやすみ。") } }
    function wake(b) { b.wake(false); return { ok: true, out: b.st.name + t(" ist wach.", " is awake.", " は起きてるよ。") } }
    function dock(b) {
        if (b.st.place === "dock") return { ok: true, out: b.st.name + t(" ist schon im Rahmen.", " is in the frame already.", " はもうフレームの中だよ。") }
        b.setFront(false)
        out(b, () => b.goDock())
        return { ok: true, out: b.st.name + t(" schmilzt in den Rahmen.", " melts into the frame.", " がフレームにとけこむ。") }
    }
    function outOf(b) {
        if (b.st.place !== "dock") return { ok: true, out: b.st.name + t(" ist nicht im Rahmen.", " is not in the frame.", " はフレームの中にいないよ。") }
        b.wake(true); b.fetchOut()
        return { ok: true, out: b.st.name + t(" kommt raus.", " comes out.", " が出てくる。") }
    }
    function front(b) { b.wake(true); b.setFront(true); return { ok: true, out: b.st.name + t(" bleibt vorne.", " stays in front.", " は前にいるね。") } }
    function back(b) { b.setFront(false); return { ok: true, out: b.st.name + t(" geht zurück.", " goes back.", " はうしろへ戻る。") } }
    // these go up anyway: no detour to the front of the windows first
    function up(b, f) {
        if (b.st.place === "chat" && world.chatOpen) { b.leaveChatFor(f); return }
        b.whenFree(f, false)
    }
    function grapple(b) { up(b, () => b.grapple()); return { ok: true, out: b.st.name + t(" zieht die Seilpistole.", " draws the grappling gun.", " がロープガンを取り出す。") } }
    function monkey(b) {
        up(b, () => b.grapple(["brachiate", "scratch", "brachiate", "swing", "sway", "brachiate", "dismount"]))
        return { ok: true, out: b.st.name + t(" macht den Affen.", " goes full monkey.", " がおさるになる。") }
    }
    function tag(a, o) {
        pair(a, o, () => a.startTag(o.st))
        return { ok: true, out: a.st.name + t(" und " + o.st.name + " spielen Fangen.", " and " + o.st.name + " play tag.", " と " + o.st.name + " がおにごっこ。") }
    }
    function hideSeek(a, o) {
        pair(a, o, () => a.startHide(o.st))
        return { ok: true, out: a.st.name + t(" zählt, " + o.st.name + " versteckt sich.", " counts, " + o.st.name + " hides.", " が数えて、" + o.st.name + " がかくれる。") }
    }
    function race(a, o) { pair(a, o, () => a.startRace(o.st)); return { ok: true, out: a.st.name + t(" und " + o.st.name + " rennen um die Wette.", " and " + o.st.name + " race.", " と " + o.st.name + " がかけっこ。") } }
    // everybody (awake) in front of the windows, then f with them
    function group(f) {
        const bs = brains.filter(b => b.st.active && !b.st.sleeping)
        if (bs.length < 2) return false
        for (const b of bs) out(b, () => {})
        when(() => {
            for (const b of bs) {
                if (b.st.moving) continue
                // behind the windows, or got up into the frame meanwhile: out and in front
                if (b.st.place === "home" && b.doing === "idle" || b.st.place === "dock" && (b.doing === "dock" || b.doing === "topDock"))
                    b.whenFree(() => {}, true)
            }
            return bs.every(b => onFloor(b) && b.st.place === bs[0].st.place)
        }, () => f(bs), 25000, bs)
        return true
    }
    function frog() {
        if (!group(bs => bs[0].startFrog(bs.map(b => b.st)))) return { ok: false, out: t("Dafür braucht es mindestens zwei wache Figuren.", "That takes at least two figures awake.", "起きている仲間がふたり以上必要だよ。") }
        return { ok: true, out: t("Bockspringen!", "Leapfrog!", "馬とびしよう!") }
    }
    function rope() {
        if (!group(bs => bs[0].startRope(bs.map(b => b.st)))) return { ok: false, out: t("Dafür braucht es mindestens zwei wache Figuren.", "That takes at least two figures awake.", "起きている仲間がふたり以上必要だよ。") }
        return { ok: true, out: t("Seilspringen!", "Jump rope!", "なわとびしよう!") }
    }
    function rpsCmd(a, o) { pair(a, o, () => a.startRps(o.st)); return { ok: true, out: a.st.name + t(" gegen " + o.st.name + ": Schnick, Schnack, Schnuck!", " vs " + o.st.name + ": rock, paper, scissors!", " 対 " + o.st.name + ": じゃんけんぽん!") } }
    function juggleCmd(b) { out(b, () => b.doHobby("juggle")); return { ok: true, out: b.st.name + t(" jongliert.", " juggles.", " がジャグリング。") } }
    function yogaCmd(b) { out(b, () => b.doHobby("yoga")); return { ok: true, out: b.st.name + t(" macht Yoga.", " does yoga.", " がヨガ。") } }
    function polishCmd(b) { out(b, () => b.doHobby("polish")); return { ok: true, out: b.st.name + t(" poliert sich.", " polishes himself.", " が自分をみがく。") } }
    function snackCmd(b) { out(b, () => b.eatSnack()); return { ok: true, out: b.st.name + t(" holt sich einen Imbiss.", " has a snack.", " がおやつタイム。") } }
    function repairCmd(b) { out(b, () => b.doRepair()); return { ok: true, out: b.st.name + t(" werkelt.", " tinkers.", " がしゅうり中。") } }
    function napCmd(b) { up(b, () => b.napOrSleep(true)); return { ok: true, out: b.st.name + t(" macht oben ein Nickerchen.", " naps up top.", " は上でおひるね。") } }
    function bananaCmd(b) {
        up(b, () => b.grapple(["banana", "sway", "brachiate", "drop"]))
        return { ok: true, out: b.st.name + t(" holt sich eine Banane.", " goes for a banana.", " がバナナを取りに行く。") }
    }
    function airFive(a, o) {
        a.fivePartner = o.st
        out(a, () => a.grapple(["callFive", "swing", "dismount"]))
        return { ok: true, out: a.st.name + t(" ruft " + o.st.name + " zum Abklatschen nach oben.", " calls " + o.st.name + " up for a high five.", " が " + o.st.name + " を上に呼んでハイタッチ。") }
    }
    function swingCmd(b) {
        up(b, () => b.grapple(["swing", "sway", "dismount"]))
        return { ok: true, out: b.st.name + t(" will schaukeln.", " wants to swing.", " がブランコしたいって。") }
    }
    function climb(b) { up(b, () => b.climb()); return { ok: true, out: b.st.name + t(" klettert.", " climbs.", " がのぼる。") } }
    function walk(b) { out(b, () => b.startWalk(false)); return { ok: true, out: b.st.name + t(" läuft los.", " walks off.", " がおさんぽへ。") } }
    function roll(b) { out(b, () => b.startWalk(true)); return { ok: true, out: b.st.name + t(" rollt los.", " rolls off.", " が転がっていく。") } }
    function play(b) { out(b, () => b.startPlay()); return { ok: true, out: b.st.name + t(" holt den Ball.", " gets the ball.", " がボールを持ってくる。") } }
    function stop() {
        for (const b of brains) b.stopPlay()
        if (fakeOn) { stopFake(); world.music = false }
        return { ok: true, out: t("Schluss mit Spielen.", "Playtime is over.", "遊びの時間はおしまい。") } }
    function more() { shell.tell({ t: "buddies", delta: 1 }); return { ok: true, out: t("Eine Figur mehr.", "One more figure.", "仲間がひとり増えた。") } }
    function fewer() { shell.tell({ t: "buddies", delta: -1 }); return { ok: true, out: t("Eine Figur weniger.", "One figure less.", "仲間がひとり減った。") } }
    function who() {
        const where = { home: t("hinter den Fenstern", "behind the windows", "ウィンドウのうしろ"), stage: t("vorne", "in front", "前"), dock: t("im Rahmen", "in the frame", "フレームの中"),
                        chat: t("im Chat", "in the chat", "チャットの中"), sky: t("unterwegs", "on the way", "移動中") }
        return { ok: true, out: active().map((b, i) => (i + 1) + "  " + b.st.name.padEnd(6) + "  " + (where[b.st.place] || b.st.place)
                                              + (b.st.sleeping ? t(", schläft", ", asleep", "、ねてる") : "") + "  " + b.st.mood
                                              + (b.st.level !== 2 ? " " + b.st.level : "")).join("\n") }
    }
    // Claude Code's models or one of the other providers, by its name
    function model(name) {
        const m = world.modelChoices.find(x => x === name || world.modelLabel(x).toLowerCase() === name)
        if (!m) return null
        world.chatModel = m
        shell.tell({ t: "model", name: m })
        return { ok: true, out: t("Modell: ", "Model: ", "モデル: ") + world.modelLabel(m) }
    }
    function models() {
        return { ok: true, out: world.modelChoices.map(m => (m === world.chatModel ? "● " : "  ") + world.modelLabel(m)).join("\n") }
    }
    function clear() { world.chatLog.clear(); shell.tell({ t: "clearView" }); return { ok: true, out: "", silent: true } }
    function forget() { world.chatLog.clear(); shell.tell({ t: "forget" }); return { ok: true, out: t("Gespräch vergessen.", "Conversation forgotten.", "会話をわすれたよ。"), silent: false } }
    function help() {
        const lines = [t("Befehle (ohne Figur: die erste; Figur per Name oder Nummer, „all“ für alle):", "Commands (no figure: the first one; a figure by name or number, \"all\" for all):", "コマンド (指定なしは最初の子、名前か番号で指定、\"all\" で全員):")]
        for (const c of table) lines.push("  " + c.names[0].padEnd(8) + t(c.de, c.en, c.ja))
        lines.push("  " + "angry".padEnd(8) + t("Stimmung, mit Stufe 1–3: angry 3 shiro. Auch sad happy scared blush shy surprised sleepy smug proud curious neutral", "a mood, with level 1–3: angry 3 shiro. Also sad happy scared blush shy surprised sleepy smug proud curious neutral", "気分、レベル 1–3 つき: angry 3 shiro。ほかに sad happy scared blush shy surprised sleepy smug proud curious neutral"))
        lines.push("  " + "!".padEnd(8) + t("Shell-Befehl: !ls ~/Bilder", "shell command: !ls ~/Pictures", "シェルコマンド: !ls ~/Pictures"))
        lines.push(t("Alles andere geht an die KI. Tab ergänzt, ↑ ↓ blättern.", "Anything else goes to the AI. Tab completes, ↑ ↓ browse.", "それ以外は AI に送られます。Tab で補完、↑ ↓ で履歴。"))
        return { ok: true, out: lines.join("\n") }
    }
    // a mood: a level 1–3 and a figure, in any order ("angry 3 shiro", "angry shiro")
    function mood(m, args) {
        let level = 2, gotLevel = false, b = brains[0]
        for (const a of args) {
            if (!gotLevel && /^[123]$/.test(a)) { level = parseInt(a); gotLevel = true; continue }
            const f = isAll(a) ? "all" : figure(a)
            if (!f) return knownName(a) ? nobody(a) : null
            b = f
        }
        const targets = b === "all" ? active() : [b]
        for (const x of targets) {
            const st = x.st
            st.feeling = true; st.mood = m; st.level = level; st.feeling = false
            st.react()
            x.moodBackLater()
        }
        return { ok: true, out: (b === "all" ? t("Alle", "All", "みんな") : b.st.name) + ": " + m + (level !== 2 ? " " + level : "") }
    }

    // ── completing a word (Tab) ───────────────────────────────────
    function complete(text) {
        const parts = text.split(" ")
        const last = parts[parts.length - 1].toLowerCase()
        if (last === "") return text
        const pool = parts.length === 1 ? allNames : active().map(b => b.st.name.toLowerCase()).concat(["all"])
        const hits = pool.filter(n => n.indexOf(last) === 0)
        if (hits.length === 0) return text
        // the common beginning of all hits
        let common = hits[0]
        for (const h of hits) while (h.indexOf(common) !== 0) common = common.slice(0, -1)
        parts[parts.length - 1] = hits.length === 1 ? hits[0] + " " : common
        return parts.join(" ")
    }
}
