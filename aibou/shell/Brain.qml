import QtQuick
import "Persona.js" as Persona

// What one character decides to do. Ticks once a second and otherwise waits
// for its gestures to finish; nothing here runs per frame.
Item {
    id: brain
    required property var st
    readonly property var world: st.world
    property bool main: false            // the one who gets notifications and the chat

    // who he is (Persona.js): his traits and his own lines
    function trait(key) { return Persona.trait(st.skin, key) }
    function voice(key, arg, fallback) { return Persona.line(st.skin, world.lang, key, arg) || fallback || "" }
    property string doing: "idle"       // idle walk roll play sleep visit notify chat meet toDock dock undock back
    property real boredom: 0
    property real energy: 0.8
    property real lastActivity: Date.now()
    property real busySince: Date.now()  // start of the current stretch of work
    property real walkTarget: st.x0
    property bool pinned: false          // stays over the windows (front)
    property real lastMeet: 0

    readonly property var others: world.active.filter(c => c !== st)
    readonly property bool saving: world.saving

    // what the stage shows (main only)
    property string bubbleTitle: ""
    property string bubbleText: ""
    property bool bubbleChat: false
    property bool bubbleShown: false
    property bool stageHeld: false
    signal wantFocus()
    signal chatOpened()

    readonly property var words: ({
        en: {
            hello: ["Ohayō!", "Hi, I'm back!", "Ehehe, there you are!"],
            callFriend: ["Is anybody there? Come and play!", "Hellooo? I'm all alone ne~", "Friends! Come over!"],
            visit: ["Just checking on you ne~", "*peeks*", "Everything okay up there?", "Don't forget to drink something!", "I'm bored ne~", "Psst. Hi."],
            pet: ["Ehehe~", "Hi %n!", "That tickles!", "Yes yes, I'm here!"],
            nochat: ["Ehehe~ (chat is switched off)"],
            front: ["I'll stay up here with you!", "Front row seat!"],
            back: ["Back to my hideout~"],
            error: ["Uh-oh, my head is empty right now.", "I couldn't reach my brain…"],
            crash: ["%1 just crashed! Grr.", "Hey! %1 crashed."],
            recOn: ["Oh, a camera! Hi everyone!", "Are we recording? *waves*", "Hello out there!"],
            recOff: ["Bye bye!", "That's a wrap!"],
            download: ["Download done: %1", "%1 is here!"],
            batLow: ["Battery at %1 % … I'm getting sleepy.", "Only %1 % left. Power, please?"],
            batCrit: ["Battery almost empty! Plug me in, quick!"],
            batOk: ["Ahh, power! Thank you!", "Mmm, electricity."],
            updates: ["%1 updates are waiting.", "There are %1 updates for you."],
            updDone: ["The update is done (%2).", "%1 is finished (%2)."],
            buildDone: ["Build done! (%1, %2)", "%1 finished after %2. Yay!"],
            welcome: ["Welcome back, %n!", "There you are again!", "Hi! I missed you."],
            welcomeShort: ["Back already?", "Hi again!"],
            usb: ["A USB stick! (%1)", "Ooh, something plugged in: %1"],
            micOn: ["Psst, the microphone is on (%1).", "Shh! %1 is listening."],
            unit: ["%1 has failed. Hmpf.", "The service %1 stopped working!"],
            dms: ["The shell reports an error: %1", "DMS is grumbling: %1"]
        },
        de: {
            hello: ["Ohayō!", "Da bin ich wieder!", "Ehehe, da bist du ja!"],
            callFriend: ["Ist da wer? Komm spielen!", "Hallooo? Ich bin ganz allein ne~", "Freunde! Kommt mal her!"],
            visit: ["Ich schau nur mal nach dir ne~", "*lugt hervor*", "Alles gut da oben?", "Vergiss nicht, was zu trinken!", "Mir ist langweilig ne~", "Psst. Hallo."],
            pet: ["Ehehe~", "Hallo %n!", "Das kitzelt!", "Ja ja, ich bin da!"],
            nochat: ["Ehehe~ (der Chat ist ausgeschaltet)"],
            front: ["Ich bleib hier oben bei dir!", "Erste Reihe!"],
            back: ["Zurück in mein Versteck~"],
            error: ["Oje, mein Kopf ist gerade leer.", "Ich komme gerade nicht an mein Hirn …"],
            crash: ["%1 ist gerade abgestürzt! Grr.", "Hey! %1 ist abgestürzt."],
            recOn: ["Oh, eine Kamera! Hallo Leute!", "Wir nehmen auf? *wink*", "Hallo da draußen!"],
            recOff: ["Tschüss!", "Und Schnitt!"],
            download: ["Download fertig: %1", "%1 ist da!"],
            batLow: ["Akku bei %1 % … ich werde müde.", "Nur noch %1 %. Strom bitte?"],
            batCrit: ["Akku fast leer! Schnell an den Strom!"],
            batOk: ["Ahh, Strom! Danke!", "Mmm, Elektrizität."],
            updates: ["%1 Updates warten.", "Es gibt %1 Updates für dich."],
            updDone: ["Das Update ist durch (%2).", "%1 ist fertig (%2)."],
            buildDone: ["Build fertig! (%1, %2)", "%1 ist nach %2 fertig. Juhu!"],
            welcome: ["Willkommen zurück, %n!", "Da bist du ja wieder!", "Hallo! Ich hab dich vermisst."],
            welcomeShort: ["Schon wieder da?", "Hallo nochmal!"],
            usb: ["Ein USB-Stick! (%1)", "Oh, da steckt was: %1"],
            micOn: ["Psst, das Mikrofon ist an (%1).", "Pst! %1 hört mit."],
            unit: ["%1 ist ausgefallen. Hmpf.", "Der Dienst %1 läuft nicht mehr!"],
            dms: ["Die Leiste meldet einen Fehler: %1", "DMS meckert: %1"]
        },
        ja: {
            hello: ["おはよう!", "ただいま!", "えへへ、いたいた!"],
            callFriend: ["だれかいる? 遊ぼうよ!", "おーい? ひとりぼっちだよ~", "みんな、こっちおいで!"],
            visit: ["ちょっと様子を見に来たよ~", "*ちらっ*", "上は大丈夫?", "水分とるの忘れないでね!", "たいくつ~", "ねえねえ、やっほー。"],
            pet: ["えへへ~", "やっほー、%n!", "くすぐったい!", "はいはい、ここにいるよ!"],
            nochat: ["えへへ~ (チャットはオフだよ)"],
            front: ["ここで一緒にいるね!", "特等席!"],
            back: ["かくれがに戻るね~"],
            error: ["あれれ、いま頭がからっぽ。", "頭が働かないみたい…"],
            crash: ["%1 が落ちちゃった! むぅ。", "ねえ! %1 が落ちたよ。"],
            recOn: ["あっ、カメラ! みんな、やっほー!", "録画中? *手をふる*", "見てるみんな、こんにちは!"],
            recOff: ["ばいばい!", "カット!"],
            download: ["ダウンロード完了: %1", "%1 が届いたよ!"],
            batLow: ["バッテリー %1 % … ねむくなってきた。", "あと %1 %。充電して?"],
            batCrit: ["バッテリーがほとんどない! はやく充電して!"],
            batOk: ["ふぅ、電気だ! ありがとう!", "んー、電気おいしい。"],
            updates: ["アップデートが %1 件あるよ。", "%1 件のアップデートが待ってるよ。"],
            updDone: ["アップデートが終わったよ (%2)。", "%1 が終わったよ (%2)。"],
            buildDone: ["ビルド完了! (%1, %2)", "%1 が %2 で終わったよ。やったね!"],
            welcome: ["おかえり、%n!", "あ、戻ってきた!", "やっほー! さみしかったよ。"],
            welcomeShort: ["もう戻ってきたの?", "またまたやっほー!"],
            usb: ["USB メモリだ! (%1)", "おっ、なにか挿さった: %1"],
            micOn: ["しーっ、マイクがオンだよ (%1)。", "しっ! %1 が聞いてるよ。"],
            unit: ["%1 が止まっちゃった。むぅ。", "サービス %1 が動いてないよ!"],
            dms: ["バーがエラーを出してるよ: %1", "DMS がぶつぶつ言ってる: %1"]
        }
    })
    // a line for the moment; %n is the user's name (setting "userName")
    function say(key) {
        const t = (words[world.lang] || words.en)[key] || words.en[key]
        const name = String(world.opt("userName", "") || "")
        const l = t[Math.floor(Math.random() * t.length)]
        return name ? l.replace("%n", name) : l.replace(/[,、]? ?%n/, "")
    }
    function pick(weights) {
        let sum = 0
        for (const k in weights) sum += weights[k]
        let r = Math.random() * sum
        for (const k in weights) { r -= weights[k]; if (r <= 0) return k }
        return Object.keys(weights)[0]
    }
    // where the others stand, so nobody hops into somebody else
    // only those standing on the same level are in the way; a dome in the
    // frame is hopped or rolled over (and does not like it)
    // behind the windows (home) and in front (stage) are the same floor: they
    // meet there and do not hide behind each other
    function onFloor(place) { return place === "home" || place === "stage" }
    function samePlace(o) { return o.place === st.place || onFloor(o.place) && onFloor(st.place) }
    function blocked(x) {
        for (const o of others) if (samePlace(o) && Math.abs(o.x0 - x) < (o.size + st.size) * 0.5) return o
        return null
    }

    // ── how lively he is (setting "activity") ─────────────────────
    // minimal: melts into the frame and watches, rarely does anything;
    // calm, normal, lively; max: always out and about, never melts in by
    // himself, calls a friend over when he is alone
    readonly property string act: world.activity
    readonly property real actPace: ({ minimal: 4, calm: 2.5, normal: 1, lively: 0.45, max: 0.2 })[act] || 1
    // when he melts in while you work, and how long it must be quiet before he comes out again
    readonly property real busyMs: ({ calm: 15000, normal: 45000, lively: 120000 })[act] || 45000
    readonly property real quietMin: ({ calm: 6, normal: 2.5, lively: 1 })[act] || 2.5
    // do not disturb: everybody into the frame, and there nothing more (true: done for this tick)
    function quiet() {
        if (st.held || st.place === "chat" || doing === "chat" || doing === "sleep" || st.place === "sky" || st.moving) return true
        // something you asked for: it may finish first
        if (Date.now() - world.commandAt < 30000 && doing !== "idle" && doing !== "dock") return true
        if (st.place === "dock") { if (doing === "idle") doing = "dock"; return true }
        if (["duet", "toDuet"].indexOf(doing) >= 0) { partner = null; duetLead = false; st.danceRest(); doing = "idle" }
        if (doing === "play") stopPlay()
        if (doing === "grapple" || doing === "hobby" || doing === "snack" || doing === "repair" || doing === "walk" || doing === "visit") { st.stopAll(); doing = "idle" }
        if (doing !== "idle") return true
        if (st.place === "stage") { doing = "back"; st.dive("home"); return true }
        if (st.place === "home" && !pinned) {
            noDockUntil = 0
            goDock()
        }
        return true
    }
    property real aloneSince: Date.now()
    property int strayChat: 0
    property real lastCall: 0
    // alone for a while at the liveliest: he calls, a friend comes for a few minutes
    function lonely(idleMin, force) {
        if (!main || world.guest !== "" || world.guestSlot < 0) return false
        if (!force && (act !== "max" || others.length > 0 || saving
                       || Date.now() - aloneSince < 180000 || Date.now() - lastCall < 600000)) return false
        lastCall = Date.now()
        const used = world.active.map(c => c.skin)
        const looks = ["kuro", "mochi", "shiro", "momo", "robo", "bao", "neko", "kumo", "tako", "hiyoko", "arai"].filter(k => used.indexOf(k) < 0)
        if (!looks.length) return false
        st.feel("sad", 1)
        st.call(say("callFriend"))
        callArrive.restart()
        return true
    }
    onOthersChanged: if (others.length > 0) aloneSince = Date.now()
    Timer {
        id: callArrive; interval: 2600
        onTriggered: {
            const used = brain.world.active.map(c => c.skin)
            const looks = ["kuro", "mochi", "shiro", "momo", "robo", "bao", "neko", "kumo", "tako", "hiyoko", "arai"].filter(k => used.indexOf(k) < 0)
            if (!looks.length) return
            brain.world.guest = looks[Math.floor(Math.random() * looks.length)]
            brain.st.feel("happy", 3)
            guestStay.interval = 240000 + Math.random() * 240000
            guestStay.restart()
        }
    }
    // the visit is over: he waves goodbye and is gone
    Timer {
        id: guestStay
        onTriggered: {
            const g = brain.others.find(o => o.slot === brain.world.guestSlot)
            if (g && (g.held || g.place === "sky" || g.place === "chat")) { interval = 20000; restart(); return }
            if (g) { g.feel("happy", 1); if (g.place === "dock") g.dockMove("wave", 1, 1, 0); else g.wave() }
            guestGone.restart()
        }
    }
    function endVisit() { guestStay.stop(); guestStay.interval = 10; guestStay.restart() }
    Timer { id: guestGone; interval: 1400; onTriggered: { brain.world.guest = ""; brain.aloneSince = Date.now(); brain.st.feel("sad", 1); brain.moodBackLater() } }

    // ── the tick ──────────────────────────────────────────────────
    Timer {
        interval: 1000; running: brain.st.active; repeat: true
        onTriggered: brain.tick()
    }
    function tick() {
        const idleMin = (Date.now() - lastActivity) / 60000
        // waiting for or dancing with a partner who has gone off to something else
        if ((doing === "duet" || doing === "toDuet") && (!partner || !partner.brain || !partner.active
                || ["duet", "toDuet"].indexOf(partner.brain.doing) < 0) && !duetGrace.running) {
            partner = null; duetLead = false; doing = "idle"; st.danceRest()
        }
        const hour = new Date().getHours()
        const night = hour >= 23 || hour < 6

        if (doing === "sleep") {
            energy = Math.min(1, energy + 0.004)
            return
        }
        // a rope left over from the grappling gun, with nobody on it any more
        if (st.rope && doing !== "grapple" && !st.hanging) st.rope = false
        // taken off the pointer some other way (picked up, a command): it is free again
        if (onPointer && doing !== "onPointer") { onPointer = false; hangTired.stop() }
        if (world.pointerHolder === st && !onPointer) world.pointerHolder = null
        if (onPointer && world.dnd) { shakenOff(); return }
        // the window counted as open with him neither in it nor out of it on purpose: closed
        if (main && world.chatOpen && st.place !== "chat" && doing !== "chat" && !world.chatAway && !backToChat && !st.moving) {
            if (++strayChat > 3) { strayChat = 0; world.chatOpen = false }
        } else strayChat = 0
        if (world.dnd && quiet()) return
        if (st.place === "dock") {
            if (doing === "idle") doing = "dock"
            if (doing !== "dock" || st.moving) return
            const stay = hiding || !pinned && (world.dock === "always" || act === "minimal" && world.dock !== "off"
                                               || (world.dock === "auto" && act !== "max" && idleMin < quietMin))
            if (!stay) { leaveDock(); return }
            if (hiding) return
            if (world.dock === "always" && !world.music && idleMin > mySleepAfter) goSleep()
            // the others are playing ball: out and join them
            if (world.ballOut && world.players > 0 && energy > 0.4 && Math.random() < 0.15) { joinGame(); return }
            // now and then something with the neighbour in the frame
            if (Math.random() < 1 / (50 * actPace)) dockChatter()
            else if (act !== "minimal" && Math.random() < 1 / (200 * actPace) && !saving && Date.now() - lastTease > 90000) outing()
            return
        }
        // nothing more to do in front of the windows: home after a while
        if (st.place === "stage" && doing === "idle" && !pinned && !world.chatOpen) {
            if (++stageIdle > (act === "minimal" ? 4 : act === "max" ? 20 : 8)) { stageIdle = 0; doing = "back"; st.dive("home"); return }
        } else stageIdle = 0
        // a ball is out and somebody plays: join in, out of the frame too
        if ((doing === "idle" || doing === "dock") && !st.held && world.ballOut && world.players > 0 && energy > 0.4
                && Math.random() < (doing === "dock" ? 0.15 : 0.35) * trait("playful")) { joinGame(); return }
        const home = st.place === "home" || pinned
        if (doing === "idle" && home && wantDock(idleMin)) { goDock(); return }
        if (doing === "idle" && home && dancing) return
        if (doing === "idle" && home) {
            boredom += night ? 0.6 : 1
            const sleepAfter = mySleepAfter
            if (idleMin > sleepAfter || (night && energy < 0.3 && boredom > 40)) { napOrSleep(); return }
            if (lonely(idleMin)) { boredom = 0; return }
            const threshold = (25 + Math.random() * 40) * actPace * (saving ? 2.5 : 1) * trait("restless")
            if (boredom > threshold && !st.moving) {
                boredom = 0
                const company = others.length > 0
                const choice = pick({
                    walk: 40, roll: 15, look: 15,
                    play: energy > 0.5 && !night && world.games && !saving ? 14 * trait("playful") : 0,
                    meet: company && Date.now() - lastMeet > 60000 ? 18 * trait("social") : 0,
                    visit: main && !pinned && (idleMin < 3 || act === "max") ? (act === "max" ? 14 : 6) : 0,
                    tease: company && Date.now() - lastTease > 90000 ? 10 * trait("social") : 0,
                    climb: !saving && Date.now() - lastClimb > 120000 ? climbLike : 0,
                    grapple: !saving && Date.now() - lastClimb > 120000 ? grappleLike : 0,
                    snack: Date.now() - lastSnack > 240000 ? snackLike : 0,
                    repair: st.skin === "robo" && Date.now() - lastRepair > 150000 ? 6 : 0,
                    hobby: Date.now() - lastHobby > 180000 ? hobbyLike : 0,
                    race: company && Date.now() - lastRace > 240000 ? 3 : 0,
                    rps: company && Date.now() - lastRace > 240000 ? 3 : 0,
                    frog: company && Date.now() - lastRace > 240000 ? 3 : 0,
                    rope: company && Date.now() - lastRace > 240000 ? 3 : 0
                })
                if (choice === "walk") startWalk(false)
                else if (choice === "roll") startWalk(true)
                else if (choice === "look") lookAround()
                else if (choice === "play") startPlay()
                else if (choice === "meet") meet()
                else if (choice === "visit") visit()
                else if (choice === "tease") tease()
                else if (choice === "climb") climb()
                else if (choice === "grapple") grapple()
                else if (choice === "snack") eatSnack()
                else if (choice === "repair") doRepair()
                else if (choice === "hobby") doHobby()
                else if (choice === "race") { const o = idleBuddy(); if (o) startRace(o) }
                else if (choice === "rps") { const o = idleBuddy(); if (o) startRps(o) }
                else if (choice === "frog" || choice === "rope") {
                    // with whoever is free and on the same floor
                    const ps = [st].concat(others.filter(o => o.brain && o.brain.doing === "idle" && samePlace(o) && !o.sleeping && !o.moving))
                    if (ps.length >= 2) { if (choice === "frog") startFrog(ps); else startRope(ps) }
                }
            }
        }
        if (doing === "play") {
            energy -= 0.006
            playTicks++
            if (!world.ballOut || energy < 0.25 || playTicks > 70) stopPlay()
        }
    }

    // put to sleep by hand (click, shortcut): stays asleep until woken by hand
    property bool tucked: false
    function activity() {
        const now = Date.now()
        if (now - lastActivity > 60000) busySince = now
        lastActivity = now
        if (doing === "sleep" && !tucked) wakeTimer.restart()
    }
    Timer { id: wakeTimer; interval: 1800 + Math.random() * 1500; onTriggered: brain.wake(false) }

    // ── the frame: while you work he waits in it ─────────────
    // auto: after 45 s of steady activity; out again after 2.5 min of quiet
    // fetched out by hand: no going back into the frame by himself for a while
    property real noDockUntil: 0
    function wantDock(idleMin) {
        if (world.dock === "off" || pinned || st.place !== "home" || st.moving || world.clothBusy) return false
        if (Date.now() < noDockUntil) return false
        if (world.dock === "always" || act === "minimal") return true
        if (act === "max") return false
        return idleMin < 0.5 && Date.now() - busySince > busyMs
    }
    // the frame where he stands, or the side of the bar if that is nearer
    property string forceSide: ""        // for testing: aibou dockAt bar|frame
    function chooseDockSide() {
        if (forceSide !== "") { const f = forceSide; forceSide = ""; return f === "bar" && world.barSide ? "bar" : "frame" }
        if (!world.barSide || world.dockAt === "frame") return "frame"
        if (world.dockAt === "bar") return "bar"
        const fromBar = world.barEdge === "left" ? st.x0 - st.minX : st.maxX - st.x0
        return fromBar < (st.maxX - st.minX) * 0.3 ? "bar" : "frame"
    }
    function goDock() {
        st.dockSide = chooseDockSide()
        if (st.dockSide === "bar" && world.barStyle === "flat") world.barSpotWanted()
        st.mood = "neutral"
        st.gazeX = 0
        const target = world.barEdge === "left" ? st.minX : st.maxX
        if (st.dockSide === "bar" && Math.abs(st.x0 - target) > 6) {
            doing = "toDock"
            walkTarget = target
            if (Math.abs(target - st.x0) > 260 && !blockedOnWay(target)) st.roll(target)
            else nextHop()
            return
        }
        // in the bottom frame: not right beside another dome, they would overlap
        if (st.dockSide === "frame") {
            const free = freeDockX()
            if (Math.abs(free - st.x0) > 6) {
                doing = "toDock"
                walkTarget = free
                nextHop()
                return
            }
        }
        doing = "dock"
        st.dive("dock")
    }
    // the nearest place in the bottom frame with room beside the other domes
    // (and those on their way there)
    function freeDockX() {
        const gap = st.size * 1.9
        const taken = others.filter(o => o.dockSide === "frame" && (o.place === "dock"
                                    || (o.brain && (o.brain.doing === "toDock" || o.brain.doing === "dock"))))
                            .map(o => o.brain && o.brain.doing === "toDock" ? o.brain.walkTarget : o.x0)
        const ok = x => taken.every(t => Math.abs(t - x) >= gap)
        if (ok(st.x0)) return st.x0
        let best = st.x0, bestD = 1e9
        for (const t of taken) for (const side of [-1, 1]) {
            const x = Math.max(st.minX, Math.min(st.maxX, t + side * gap))
            if (ok(x) && Math.abs(x - st.x0) < bestD) { best = x; bestD = Math.abs(x - st.x0) }
        }
        return best
    }
    function leaveDock() {
        if (st.place !== "dock") return
        doing = "undock"
        st.undock("home")
    }
    // clicked in the frame: he hops out in front of the windows, waves, and
    // goes home after a while; three minutes without docking by himself
    function fetchOut() {
        if (st.place !== "dock") return
        if (st.dockSide === "top") { drop(); return }
        noDockUntil = Date.now() + 180000
        toStage("", "", "happy", 4500, false)
        backToDock = false
    }

    // ── walking and rolling ───────────────────────────────────────
    function startWalk(roll) {
        doing = roll ? "roll" : "walk"
        const span = st.maxX - st.minX
        let t = st.x0 + (Math.random() < 0.5 ? -1 : 1) * (120 + Math.random() * span * 0.35)
        if (t < st.minX || t > st.maxX) t = st.x0 - (t - st.x0)
        walkTarget = Math.max(st.minX, Math.min(st.maxX, t))
        if (roll && !blockedOnWay(walkTarget)) st.roll(walkTarget)
        else { doing = "walk"; nextHop() }
    }
    function blockedOnWay(target) {
        for (const o of others) if (samePlace(o) && (o.x0 - st.x0) * (o.x0 - target) < 0) return true
        return false
    }
    function nextHop() {
        const d = walkTarget - st.x0
        if (Math.abs(d) < 4) { arrive(); return }
        // a long way: he rolls most of it, faster than hopping, and hops the
        // last bit so he arrives on his feet
        if (Math.abs(d) > 300 && !saving) {
            const stop = walkTarget - Math.sign(d) * 50
            if (!blockedOnWay(stop) && st.roll(stop)) return
        }
        const step = st.x0 + Math.sign(d) * Math.min(Math.abs(d), (38 + Math.random() * 26) * trait("step"))
        // on his way into the frame he passes the others, they go there too
        const o = doing === "toDock" ? null : blocked(step)
        if (o) {
            // walked into somebody: now and then that starts a quarrel (not
            // right after a kiss or a hug, when they still stand close)
            if (o.brain && ["idle", "walk"].indexOf(o.brain.doing) >= 0 && !o.sleeping && !tidying
                    && doing === "walk" && Date.now() - lastQuarrel > 90000 && Date.now() - lastMeet > 20000
                    && Math.random() < 0.45) {
                startQuarrel(o)
                return
            }
            // passing somebody: over him in a high jump (he ducks)
            if (doing !== "tease" && (walkTarget - o.x0) * Math.sign(d) > 0 && leapOver(o, Math.sign(d))) return
            // on the way to tease somebody: whoever is in the way gets it
            if (doing === "tease") friend = o
            arrive()
            return
        }
        st.hop(step, (14 + Math.random() * 14) * trait("hopH"))
    }
    function leapOver(o, dir) {
        const land = o.x0 + dir * (o.size + st.size) * 0.62
        if (land < st.minX || land > st.maxX) return false
        for (const x of others) if (x !== o && samePlace(x) && Math.abs(x.x0 - land) < (x.size + st.size) * 0.5) return false
        if (!st.hop(land, 42 + o.size * 0.45)) return false
        st.armUp(0, 0.8)
        if (o.brain) o.brain.leapedOver(st)
        return true
    }
    function leapedOver(by) {
        if (st.moving || st.sleeping || st.place === "dock") return
        st.gazeX = by.x0 > st.x0 ? 1 : -1
        st.gazeY = -0.9
        st.squat()
        if (Math.random() < 0.4) st.mood = "surprised"
        leapBack.restart()
    }
    Timer { id: leapBack; interval: 900; onTriggered: { brain.st.gazeY = 0; if (brain.st.mood === "surprised") brain.st.mood = "neutral" } }
    // two standing (nearly) on the same spot: one of them hops aside. A
    // little overlap is fine, and so is closeness on purpose (a kiss, a dance).
    Timer { interval: 900; repeat: true; running: brain.st.active; onTriggered: brain.makeSpace() }
    function makeSpace() {
        if (doing !== "idle" || st.moving || !onFloor(st.place) || st.held || st.sleeping) return
        for (const o of others) {
            if (!onFloor(o.place) || o.moving || o.held) continue
            if (o.brain && ["duet", "toDuet", "kissed", "quarrel", "meet"].indexOf(o.brain.doing) >= 0) continue
            const dx = st.x0 - o.x0
            if (Math.abs(dx) >= (o.size + st.size) * 0.4) continue
            // only one of the two moves: the later one, unless the other cannot
            if (st.slot < o.slot && o.brain && o.brain.doing === "idle" && !o.sleeping) continue
            let side = dx === 0 ? (Math.random() < 0.5 ? -1 : 1) : Math.sign(dx)
            let to = o.x0 + side * (o.size + st.size) * 0.55
            if (to < st.minX || to > st.maxX) { side = -side; to = o.x0 + side * (o.size + st.size) * 0.55 }
            st.hop(to, 14)
            return
        }
    }
    function arrive() {
        st.gazeX = 0
        if (doing === "toDock") { doing = "dock"; st.dive("dock"); return }
        if (doing === "meet") greet()
        else if (doing === "tease") pokeFriend()
        else if (doing === "climb") startClimb()
        else if (doing === "outing") outingPoke()
        else if (doing === "toQuarrel") {
            const o = quarrelTarget
            quarrelTarget = null
            if (o && o.brain && Math.abs(o.x0 - st.x0) < (o.size + st.size) && ["idle", "walk"].indexOf(o.brain.doing) >= 0) startQuarrel(o)
            else doing = "idle"
        }
        else if (doing === "outingBack") { doing = "dock"; st.dockSide = "frame"; st.dive("dock") }
        else if (doing === "toDuet") beginDuet()
        else if (doing === "toFive") { doing = "idle"; grapple(["fiveB"].concat(randomPlan().slice(-2)), fiveHook) }
        else if (doing === "toHide") hideNow()
        else if (doing === "seekWalk" || doing === "seekFind") seekArrived()
        else doing = "idle"
    }
    Connections {
        target: brain.st
        function onHopDone() {
            if (["walk", "meet", "tease", "climb", "toDock", "outing", "outingBack", "toQuarrel", "toDuet", "toFive", "toHide", "seekWalk", "seekFind"].indexOf(brain.doing) >= 0) brain.nextHop()
            else if (brain.doing === "play") brain.playStep()
        }
        function onRollDone() {
            if (brain.doing === "roll") { brain.doing = "idle"; brain.st.gazeX = 0 }
            // rolled most of a long way: the last bit in hops
            else if (["walk", "meet", "tease", "climb", "toDock", "outing", "outingBack", "toQuarrel", "toDuet", "toFive", "toHide", "seekWalk", "seekFind"].indexOf(brain.doing) >= 0) {
                brain.st.gazeX = 0
                brain.nextHop()
            }
        }
        function onPlaceDone() { brain.placeDone() }
        function onDockDone() {
            // late: he already left the frame again; or held there by the pointer
            if (brain.st.place !== "dock" || brain.st.held) return
            if (brain.st.dockSide === "top") {
                // up there for a nap: asleep until woken (a click lets him drop)
                if (brain.napTop) { brain.napTop = false; brain.doing = "sleep"; brain.st.mood = "sleepy"; brain.st.sleeping = true; return }
                brain.doing = "topDock"; brain.topStay.interval = 25000 + Math.random() * 45000; brain.topStay.restart(); return
            }
            if (brain.doing !== "sleep") brain.doing = "dock"
            // into the frame under an open popout
            brain.makeRoom()
        }
        function onGlideDone() { brain.climbNext() }
    }

    // looks about, and now and then says something to himself
    function lookAround() {
        lookAnim.start()
        if (Math.random() < 0.35) { const l = voice("idle"); if (l) st.call(l) }
    }
    SequentialAnimation {
        id: lookAnim
        NumberAnimation { target: brain.st; property: "gazeX"; to: -1; duration: 300; easing.type: Easing.OutQuad }
        PauseAnimation { duration: 900 }
        NumberAnimation { target: brain.st; property: "gazeX"; to: 1; duration: 450; easing.type: Easing.InOutQuad }
        PauseAnimation { duration: 900 }
        NumberAnimation { target: brain.st; property: "gazeX"; to: 0; duration: 300 }
    }

    // ── meeting another character ─────────────────────────────────
    property var friend: null
    property string meetKind: ""         // forced for tests: wave kiss hug five
    function meet(who, kind) {
        const idle = others.filter(o => o.brain && o.brain.doing === "idle" && samePlace(o))
        if (idle.length === 0) { startWalk(false); return }
        friend = who && idle.indexOf(who) >= 0 ? who : idle[Math.floor(Math.random() * idle.length)]
        meetKind = kind || ""
        lastMeet = Date.now()
        doing = "meet"
        const side = friend.x0 > st.x0 ? -1 : 1
        walkTarget = Math.max(st.minX, Math.min(st.maxX, friend.x0 + side * (friend.size + st.size) * 0.55))
        nextHop()
    }
    // what two do when they meet: mostly wave; Kuro likes to give Shiro a
    // kiss, anybody may hug or give a high five
    function greetKind(f) {
        if (meetKind) return meetKind
        const r = Math.random()
        if (st.skin === "kuro" && f.skin === "shiro") return r < 0.5 ? "kiss" : r < 0.7 ? "hug" : r < 0.85 ? "five" : "wave"
        return r < 0.08 ? "kiss" : r < 0.3 ? "hug" : r < 0.55 ? "five" : "wave"
    }
    function greet() {
        doing = "idle"
        if (!friend) return
        const f = friend
        const side = f.x0 > st.x0 ? 1 : -1
        st.gazeX = side
        const kind = f.brain && f.brain.doing === "idle" && samePlace(f) ? greetKind(f) : "wave"
        meetKind = ""
        friend = null
        if (kind === "kiss") {
            st.mood = "happy"
            st.kiss(side)
            f.brain.kissed(st)
            afterKiss.restart()
        } else if (kind === "hug") {
            st.mood = "happy"
            st.hug(side)
            f.brain.hugged(st)
            moodBack.interval = 3200
        } else if (kind === "five") {
            st.mood = "happy"
            st.highFive(side)
            f.brain.fived(st)
        } else {
            st.mood = "happy"
            st.wave()
            if (f.brain) f.brain.greeted(st)
        }
        moodBack.restart()
    }
    // after the kiss he goes a little pink himself
    Timer { id: afterKiss; interval: 900; onTriggered: { brain.st.feel("blush", 1); moodBack.restart() } }
    function kissed(by) {
        if (doing !== "idle") return
        lastMeet = Date.now()
        doing = "kissed"
        st.gazeX = by.x0 > st.x0 ? 1 : -1
        kissedBy = by
        blushUp.restart()
    }
    property var kissedBy: null
    // the kiss lands, she goes bright pink, and now and then kisses back
    Timer {
        id: blushUp; interval: 420
        onTriggered: {
            brain.st.feel("blush", 3)
            brain.st.jolt()
            brain.st.jump(8)
            if (Math.random() < 0.35) kissBack.restart()
            else { brain.doing = "idle"; moodBack.interval = 5200; moodBack.restart() }
        }
    }
    Timer {
        id: kissBack; interval: 1500
        onTriggered: {
            const by = brain.kissedBy
            brain.doing = "idle"
            if (!by || by.place !== brain.st.place || brain.st.moving) return
            brain.st.kiss(by.x0 > brain.st.x0 ? 1 : -1)
            if (by.brain) by.brain.kissedBack()
            moodBack.interval = 5200; moodBack.restart()
        }
    }
    Timer { id: kissedBackT; interval: 420; onTriggered: { brain.st.feel("blush", 3); brain.st.jump(10); brain.moodBackLater() } }
    function kissedBack() { afterKiss.stop(); kissedBackT.restart() }
    function hugged(by) {
        if (doing !== "idle") return
        lastMeet = Date.now()
        st.gazeX = by.x0 > st.x0 ? 1 : -1
        st.mood = Math.random() < 0.3 ? "blush" : "happy"
        st.hug(by.x0 > st.x0 ? 1 : -1)
        moodBack.interval = 3200
        moodBack.restart()
    }
    function fived(by) {
        if (doing !== "idle") return
        lastMeet = Date.now()
        st.gazeX = by.x0 > st.x0 ? 1 : -1
        st.mood = "happy"
        st.highFive(by.x0 > st.x0 ? 1 : -1, true)
        moodBack.restart()
    }
    function greeted(by) {
        if (doing !== "idle") return
        lastMeet = Date.now()
        st.gazeX = by.x0 > st.x0 ? 1 : -1
        st.mood = Math.random() < 0.5 ? "happy" : "shy"
        if (Math.random() < 0.6) st.jump(16); else st.cheer()
        moodBack.restart()
    }
    Timer {
        id: moodBack; interval: 2600
        onTriggered: if (brain.doing === "idle" || brain.doing === "dock") {
            if (!brain.st.calm()) { restart(); return }
            brain.st.gazeX = 0
            interval = 2600
        }
    }

    // how soon he gets sleepy: the cakes love a nap, the robot and the climber
    // keep going longer; half as long on battery with the saver
    readonly property real sleepiness: trait("sleepy")
    readonly property real mySleepAfter: world.sleepAfter * sleepiness * (saving ? 0.5 : 1)

    // ── climbing: up a side of the screen, along the top, into its frame ──
    // how much he likes it, by figure
    readonly property real climbLike: trait("climb")
    // the grappling gun: Kuro's favourite, the cakes hardly ever
    readonly property real grappleLike: trait("grapple")

    // ── the grappling gun: up a rope from wherever he stands ──────
    // He draws the gun, aims a little to one side of straight up, the hook
    // catches the top edge, and he pulls himself up hand over hand; the rope
    // starts at a slant, so he swings on the way, and halfway he swings on
    // purpose for a moment. At the top he hangs by his hands like a monkey
    // and does a few things (monkeyPlan), then comes down one way or another.
    property string grStage: ""
    property string grStyle: "hands"
    property real reelStep: 60
    property real reelPace: 300
    property bool halfSwing: true
    property real halfAmp: 0.35
    property bool slipChance: false
    property bool slid: false
    function pickCall(de, en, ja) { const l = world.tr(de, en, ja); return l[Math.floor(Math.random() * l.length)] }
    function tr(de, en, ja) { return world.tr(de, en, ja) }
    property var monkeyPlan: []
    property bool stunt: false           // a jump of his own: landing makes him proud, not cross
    property real hookAt: 0
    property bool swungHalfway: false
    property real hookWish: NaN          // where the hook should go (a partner's high five)
    property var fivePartner: null
    function grapple(plan, hookX) {
        if ((st.place !== "home" && st.place !== "stage") || st.held || st.flying) return false
        // no grappling gun for the cloud either: up it floats
        if (st.skin === "kumo") { if (doing === "play") stopPlay(); climb(); return true }
        st.stopPlace()
        lastClimb = Date.now()
        if (doing === "play") stopPlay()
        doing = "grapple"
        st.stopAll()
        st.place = "sky"; st.y0 = world.floorY; st.surfaceRot = 0
        st.mood = "curious"; st.gazeY = -1
        const side = Math.random() < 0.5 ? -1 : 1
        hookAt = Math.max(world.insets.left + st.size, Math.min(world.areaW - world.insets.right - st.size,
                          hookX !== undefined ? hookX : st.x0 + st.size * 0.42 + side * (30 + Math.random() * 110)))
        monkeyPlan = plan || randomPlan()
        swungHalfway = false
        // a little different every time: hand over hand (step and pace vary,
        // a rest now and then) or the gun winds him up in one go; a swing
        // halfway only sometimes, and not always as wide; rarely a slip
        grStyle = Math.random() < 0.35 ? "zip" : "hands"
        reelStep = 45 + Math.random() * 40
        reelPace = 240 + Math.random() * 160
        halfSwing = Math.random() < 0.55
        halfAmp = 0.22 + Math.random() * 0.3
        slipChance = Math.random() < 0.18
        slid = false
        st.useHands(600000)
        st.drawGun(true)
        st.handRY = -st.size * 0.45; st.handRX = st.size * 0.04
        st.aimAt(hookAt, world.insets.top)
        grStage = "aim"
        grTimer.interval = 650; grTimer.restart()
        return true
    }
    function randomPlan() {
        const middle = ["brachiate", "brachiate", "scratch", "swing", "sway", "banana"]
            .concat(others.length ? ["callFive"] : [])
        const plan = []
        for (let n = 2 + Math.floor(Math.random() * 2); n > 0; n--) plan.push(middle[Math.floor(Math.random() * middle.length)])
        const ends = ["dismount", "dismount", "abseil", "drop"].concat(world.dock !== "off" ? ["melt"] : [])
        plan.push(ends[Math.floor(Math.random() * ends.length)])
        return plan
    }
    Timer { id: grTimer; onTriggered: brain.grNext() }
    // called away from the grappling gun (a message, a command): off the rope,
    // or it stays hanging in the air where he was
    onDoingChanged: {
        if (doing !== "walk") tidying = false
        // off the wall: hands that held the frame let go
        if (doing !== "climb" && !st.hanging) st.releaseGrips()
        if (doing === "grapple" || doing === "onPointer" || doing === "held") return
        if (st.hanging || st.rope) { st.stopHanging(); st.surfaceRot = 0; st.theta = 0 }
        abseilAnim.stop(); grTimer.stop(); dismountGuard.stop()
        grStage = ""
    }
    function grNext() {
        if (doing !== "grapple") return
        const top = world.insets.top
        switch (grStage) {
        case "aim":
            st.shoot(hookAt, top)
            grStage = "shot"
            return
        case "hooked":
            // both hands on the rope (or the gun winds him up), and up
            if (grStyle !== "zip") st.drawGun(false)
            st.hangFrom(hookAt, top)
            st.mood = "happy"
            grStage = "reel"
            grTimer.interval = 250; grTimer.restart()
            return
        case "reel": {
            const total = world.floorY - top
            if (grStyle === "zip") {
                // the gun's winch: up in one smooth pull
                st.call(pickCall(["Zzzip!", "Wiiiu!"], ["Zzzip!", "Wheee!"], ["シュルルッ!", "ひゅーん!"]))
                ropeAnim.easing.type = Easing.InOutQuad
                ropeAnim.duration = 1200 + Math.random() * 800
                ropeAnim.to = 0
                ropeAnim.restart()
                grStage = "top"; grTimer.interval = ropeAnim.duration + 300; grTimer.restart()
                return
            }
            if (halfSwing && !swungHalfway && st.ropeLen < total * (0.4 + Math.random() * 0.2)) {
                swungHalfway = true
                grStage = "swingHalf"
                st.swingAmp = halfAmp
                st.pump = 2 + Math.random()
                st.call(pickCall(["Hui!", "Juchu!", "Hihi!"], ["Whee!", "Yay!", "Wooo!"], ["わーい!", "やったー!", "ひゃっほー!"]))
                grTimer.interval = 1600 + Math.random() * 1400; grTimer.restart()
                return
            }
            if (slipChance && !slid && st.ropeLen < total * 0.7 && st.ropeLen > total * 0.25) {
                // the hands slip: down a bit, a fright, and on again
                slid = true
                ropeAnim.easing.type = Easing.OutBounce
                ropeAnim.duration = 260
                ropeAnim.to = st.ropeLen + 50 + Math.random() * 40
                ropeAnim.restart()
                st.feel("scared", 1)
                st.call(pickCall(["Hoppla!", "Huch!"], ["Whoops!", "Eek!"], ["おっと!", "ひゃっ!"]))
                grTimer.interval = 1100; grTimer.restart()
                return
            }
            ropeAnim.easing.type = Easing.OutQuad
            ropeAnim.duration = reelPace * 0.75
            ropeAnim.to = Math.max(0, st.ropeLen - reelStep * (0.85 + Math.random() * 0.3))
            ropeAnim.restart()
            if (ropeAnim.to <= 0) { grStage = "top"; grTimer.interval = 700 }
            // now and then a breather: a look down, then on
            else if (Math.random() < 0.06) { st.gazeY = 1; grTimer.interval = 900 + Math.random() * 500 }
            else { st.gazeY = 0; grTimer.interval = reelPace }
            grTimer.restart()
            return
        }
        case "swingHalf":
            st.pump = 0
            grStage = "reel"
            grTimer.interval = 900; grTimer.restart()
            return
        case "top":
            // at the edge: the hook comes off, he holds the edge itself
            st.drawGun(false)
            st.gazeY = 0
            st.rope = false
            st.takeBar()
            grStage = "monkey"
            grTimer.interval = 500; grTimer.restart()
            return
        case "monkey":
            monkeyNext()
            return
        case "waitFive":                         // nobody came up
            grStage = "monkey"; grTimer.interval = 200; grTimer.restart()
            return
        case "scratchEnd":
            st.oneHand = 0; st.hangPlace()
            grStage = "monkey"; grTimer.interval = 400; grTimer.restart()
            return
        case "swingEnd":
            st.pump = 0
            grStage = "monkey"; grTimer.interval = 1800; grTimer.restart()
            return
        }
    }
    NumberAnimation { id: ropeAnim; target: brain.st; property: "ropeLen"; duration: 230; easing.type: Easing.OutQuad }
    Connections {
        target: brain.st
        function onHooked() {
            if (brain.doing !== "grapple" || brain.grStage !== "shot") return
            brain.st.jolt()
            brain.grStage = "hooked"
            grTimer.interval = 300; grTimer.restart()
        }
        function onBrachiated() {
            if (brain.doing !== "grapple" || brain.grStage !== "brachiate") return
            if (--brain.brSteps > 0 && brain.st.brachiate(brain.brDir)) return
            brain.grStage = "monkey"; grTimer.interval = 350; grTimer.restart()
        }
        function onSwing(theta, omega) {
            // swinging up to let go: at the far end of a big swing, moving outwards
            if (brain.doing !== "grapple" || brain.grStage !== "dismount") return
            if (Math.abs(theta) > 0.85 && theta * omega > 0 && Math.abs(omega) > 1.2) brain.letGo()
        }
    }
    property int brSteps: 0
    property int brDir: 1
    // the banana's peel: he lets it fall where his free hand is
    Connections {
        target: brain.st
        function onBananaDone() {
            if (brain.doing !== "grapple" || brain.grStage !== "banana") return
            const st = brain.st
            const freeSide = st.oneHand > 0 ? -1 : 1
            const a = st.theta
            const hx = st.x0 - Math.sin(a) * st.bodyH * 0.55 + Math.cos(a) * freeSide * st.size * 0.2
            const hy = st.y0 - Math.cos(a) * st.bodyH * 0.55
            brain.world.dropPeel(hx, hy, st)
            st.oneHand = 0; st.hangPlace()
            st.mood = "smug"
            brain.grStage = "monkey"; grTimer.interval = 1600; grTimer.restart()
        }
        function onReached() {
            if (brain.grStage !== "five" || !brain.fiveLead) return
            const st = brain.st, o = brain.fivePartner
            st.towards = o && o.x0 > st.x0 ? 1 : -1
            st.pop("star")
            st.jolt(); if (o) o.jolt()
            st.feel("happy", 3); if (o) o.feel("happy", 3)
            fiveDone.restart()
        }
        function onSlipped() {
            if (brain.doing !== "slip") return
            brain.doing = "idle"
            if (Math.random() < 0.5) brain.st.feel("angry", 1); else brain.st.feel("blush", 1)
            brain.moodBackLater()
        }
    }
    property bool fiveLead: false
    Timer {
        id: fiveDone; interval: 900
        onTriggered: {
            for (const b of [brain, brain.fivePartner ? brain.fivePartner.brain : null]) {
                if (!b || b.grStage !== "five") continue
                b.st.oneHand = 0; b.st.hangPlace()
                b.fiveLead = false
                b.grStage = "monkey"; b.grapTimer.interval = 700; b.grapTimer.restart()
            }
        }
    }
    property alias grapTimer: grTimer
    // somebody standing on the floor, free to come up
    // free enough: standing, walking about or on the way home, not asleep
    function freeFor(o) {
        return o && o.brain && ["idle", "walk", "roll", "back"].indexOf(o.brain.doing) >= 0 && onFloor(o.place) && !o.sleeping && !o.held
    }
    function freeBuddy() {
        if (freeFor(fivePartner)) return fivePartner
        const f = others.filter(o => freeFor(o))
        return f.length ? f[Math.floor(Math.random() * f.length)] : null
    }
    // called up for a high five: first under the spot next to the caller,
    // then straight up from there
    property real fiveHook: 0
    function comeUpTo(at) {
        fiveHook = at
        doing = "toFive"
        walkTarget = Math.max(st.minX, Math.min(st.maxX, at - st.size * 0.42))
        st.mood = "happy"
        nextHop()
    }
    function monkeyNext() {
        const what = monkeyPlan.length ? monkeyPlan[0] : "drop"
        monkeyPlan = monkeyPlan.slice(1)
        switch (what) {
        case "hide":
            // still at the top edge, eyes nearly shut, until found
            grStage = "hiding"
            st.mood = "sleepy"
            st.theta = 0.05
            return
        case "banana":
            st.eatBanana(Math.random() < 0.5 ? -1 : 1)
            st.mood = "happy"
            st.call(tr("Mampf!", "Nom!", "もぐもぐ!"))
            grStage = "banana"
            return
        case "callFive": {
            // calls a buddy up: he shoots his hook right next to him
            const b = freeBuddy()
            fivePartner = null
            if (!b) { grStage = "monkey"; grTimer.interval = 200; grTimer.restart(); return }
            if (b.brain.doing !== "idle") { b.brain.doing = "idle"; b.stopAll() }
            let side = b.x0 > st.pivotX ? 1 : -1
            let at = st.pivotX + side * st.size * 1.75
            if (at < world.insets.left + st.size || at > world.areaW - world.insets.right - st.size) { side = -side; at = st.pivotX + side * st.size * 1.75 }
            st.call(tr("Komm hoch!", "Come up!", "上においでよ!"))
            b.brain.whenFree(() => b.brain.comeUpTo(at))
            grStage = "waitFive"
            grTimer.interval = 25000; grTimer.restart()
            return
        }
        case "fiveB": {
            // up next to the one who called: both swing towards each other and clap
            const a = others.find(o => o.brain && o.brain.doing === "grapple" && o.brain.grStage === "waitFive")
            if (!a) { grStage = "monkey"; grTimer.interval = 200; grTimer.restart(); return }
            a.brain.grapTimer.stop()
            const dir = a.pivotX > st.pivotX ? 1 : -1
            grStage = "five"; a.brain.grStage = "five"
            fivePartner = a; a.brain.fivePartner = st
            fiveLead = true; a.brain.fiveLead = false
            st.reachTo(dir); a.reachTo(-dir)
            return
        }
        case "brachiate":
            // towards the middle of the screen, three to six grips
            brDir = st.x0 < world.areaW / 2 ? 1 : -1
            brSteps = 3 + Math.floor(Math.random() * 4)
            grStage = "brachiate"
            st.mood = "happy"
            if (!st.brachiate(brDir)) { grStage = "monkey"; grTimer.interval = 200; grTimer.restart() }
            return
        case "scratch":
            st.scratch(Math.random() < 0.5 ? -1 : 1)
            st.mood = "curious"
            st.call(tr("Uh uh ah ah!", "Ooh ooh ah ah!", "ウキキッ!"))
            grStage = "scratchEnd"; grTimer.interval = 1500; grTimer.restart()
            return
        case "swing":
            st.swingAmp = 0.5 + Math.random() * 0.35
            st.pump = 3 + Math.random() * 2
            st.mood = "happy"
            grStage = "swingEnd"; grTimer.interval = 2600 + Math.random() * 1600; grTimer.restart()
            return
        case "sway":
            st.theta = 0.25 * (Math.random() < 0.5 ? -1 : 1)
            grStage = "monkey"; grTimer.interval = 1800; grTimer.restart()
            return
        case "dismount":
            st.swingAmp = 1.15
            st.pump = 4 + Math.random() * 1.5
            st.mood = "happy"
            grStage = "dismount"
            // in case the swing never gets big enough
            dismountGuard.restart()
            return
        case "abseil": {
            // the hook goes back on, and down the rope he goes
            st.leaveBar()
            st.hookX = st.pivotX; st.hookY = st.pivotY
            st.ropeShot = 1; st.rope = true
            abseilAnim.to = Math.max(0, world.floorY - st.pivotY - st.hangLen)
            abseilAnim.duration = 1800 + abseilAnim.to * 0.6
            grStage = "abseil"
            st.theta = 0.12
            abseilAnim.restart()
            return
        }
        case "melt":
            st.stopHanging()
            st.rope = false
            st.surfaceRot = 180
            st.y0 = world.insets.top
            doing = "climb"
            topDock()
            return
        default:                                   // drop: let go and fall
            st.stopHanging()
            doing = "climb"
            climbStage = "fall"
            st.surfaceRot = 0
            st.feel("scared", 1)
            st.glide(st.x0, world.floorY, 0, 560, Easing.InQuad)
        }
    }
    Timer { id: dismountGuard; interval: 6000; onTriggered: if (brain.grStage === "dismount") brain.letGo() }
    NumberAnimation {
        id: abseilAnim; target: brain.st; property: "ropeLen"; easing.type: Easing.InOutSine
        onFinished: if (brain.doing === "grapple" && brain.grStage === "abseil") brain.abseiled()
    }
    // slipped on the banana peel: on his back for a moment, the one who
    // dropped it (and whoever saw it) grins
    // Arai on the peel: he picks it up instead of slipping, proud of it
    property bool tidying: false
    function tidyPeel() {
        tidying = false
        if (doing === "play") stopPlay()
        doing = "idle"
        st.stopAll()
        st.squat()
        st.feel("proud", 2)
        st.call(voice("tidy", undefined, tr("Aufgeräumt!", "All tidy!", "おかたづけ完了!")))
        moodBackLater.restart()
    }
    function slipOnPeel(dir) {
        if (doing === "play") stopPlay()
        doing = "slip"
        st.slip(dir)
        const sl = voice("slip"); if (sl) st.call(sl)
        const by = world.peelBy
        for (const o of world.active) {
            if (o === st) continue
            if (o === by) { o.mood = "smug"; o.call(o.brain ? o.brain.voice("happy", undefined, tr("Hihi!", "Hee hee!", "えへへ!")) : tr("Hihi!", "Hee hee!", "えへへ!")) }
            else if (o.brain && o.brain.doing === "idle") { o.mood = "smug"; o.brain.moodBackLater() }
        }
    }
    // the peel is down: the nearest one standing around happens to walk there
    Connections {
        target: brain.world
        function onPeelLanded() {
            const w = brain.world
            let best = null, d = 1e9
            // Arai tidies up: if he stands around, he goes for it (even his own)
            const tidy = w.active.find(o => o.skin === "arai" && o.brain && o.brain.doing === "idle" && brain.onFloor(o.place) && !o.sleeping)
            if (tidy) { if (tidy === brain.st) peelWalk.restart(); return }
            for (const o of w.active) {
                if (o === w.peelBy || !o.brain || o.brain.doing !== "idle" || !brain.onFloor(o.place) || o.sleeping) continue
                const dd = Math.abs(o.x0 - w.peelX)
                if (dd < d) { d = dd; best = o }
            }
            if (best !== brain.st || Math.random() > 0.75) return
            peelWalk.restart()
        }
    }
    Timer {
        id: peelWalk; interval: 1200
        onTriggered: {
            if (brain.doing !== "idle" || !brain.world.peelOn) return
            // Arai on his way to tidy up: no quarrels on the way
            brain.tidying = brain.st.skin === "arai"
            brain.doing = "walk"
            brain.walkTarget = Math.max(brain.st.minX, Math.min(brain.st.maxX, brain.world.peelX))
            brain.st.gazeX = brain.walkTarget > brain.st.x0 ? 1 : -1
            brain.nextHop()
        }
    }
    function abseiled() {
        st.stopHanging()
        st.rope = false
        st.theta = 0; st.surfaceRot = 0
        st.y0 = world.floorY
        grStage = ""
        climbStage = ""
        landed()
    }
    // lets go at the top of the swing: flies on with the swing's speed and
    // turns over (the throw's flight), and lands proud
    function letGo() {
        dismountGuard.stop()
        const v = st.swingVelocity()
        const deg = -st.theta * 180 / Math.PI
        st.stopHanging()
        st.rope = false
        grStage = ""
        doing = "held"
        st.surfaceRot = 0
        st.rot = deg
        st.flying = true
        stunt = true
        bounces = 0
        flyVX = Math.max(-2200, Math.min(2200, v.vx * 1.15))
        flyVY = Math.min(-200, v.vy - 350)
        st.call(tr("Juhuu!", "Wheee!", "わーい!"))
        flyT = Date.now()
        flight.start()
    }
    property real lastClimb: 0
    property string climbStage: ""
    property int ceilSteps: 0
    property int wallDir: -1             // -1 the left side, 1 the right side
    property alias topStay: topStayTimer
    function wallX() { return wallDir < 0 ? world.insets.left : world.areaW - world.insets.right }
    function climb() {
        // the cloud does not climb: it floats up to the top edge
        if (st.skin === "kumo") { floatUp(); return }
        st.stopPlace()
        lastClimb = Date.now()
        wallDir = st.x0 < world.areaW / 2 ? -1 : 1
        doing = "climb"
        climbStage = "walk"
        walkTarget = wallDir < 0 ? st.minX : st.maxX
        st.mood = "curious"
        nextHop()
    }
    // at the foot of the wall: onto it, feet against it
    function startClimb() {
        climbStage = "mount"
        ceilSteps = 2 + Math.floor(Math.random() * 4)
        st.y0 = world.floorY
        st.surfaceRot = 0
        st.place = "sky"
        st.mood = "happy"
        st.glide(wallX(), world.floorY - st.size * 0.6, wallDir < 0 ? 90 : -90, 380)
    }
    // Kumo: straight up, slowly, swaying a little; at the top it turns into
    // the frame and melts in there (or, without the frame, drifts down again)
    function floatUp() {
        st.stopPlace()
        lastClimb = Date.now()
        if (doing === "play") stopPlay()
        st.stopAll()
        doing = "climb"
        climbStage = "floatUp"
        st.place = "sky"; st.y0 = world.floorY; st.surfaceRot = 0
        st.mood = "happy"
        st.glide(st.x0 + (Math.random() - 0.5) * st.size, world.insets.top + st.bodyH + 18, 0, 2400, Easing.InOutSine)
    }
    function climbNext() {
        if (doing !== "climb") return
        const top = world.insets.top
        if (climbStage === "floatUp") {
            climbStage = "floatTurn"
            st.glide(st.x0, top, 180, 520, Easing.InOutSine)
            return
        }
        if (climbStage === "floatTurn") {
            if (world.dock !== "off") topDock(); else drop()
            return
        }
        if (climbStage === "mount" || climbStage === "up") {
            if (st.y0 > top + st.size * 1.4) {
                climbStage = "up"
                // up the wall is his own -x on the left side, +x on the right
                st.pullTo(wallX(), Math.max(top + st.size * 1.3, st.y0 - 30 - Math.random() * 14), wallDir)
                return
            }
            // round the corner onto the top edge (the hands let go of the wall)
            climbStage = "corner"
            st.releaseGrips()
            st.glide(wallX() - wallDir * st.size * 0.8, top, 180, 440)
            return
        }
        if (climbStage === "corner" || climbStage === "ceil") {
            if (ceilSteps-- > 0) {
                climbStage = "ceil"
                // hanging upside down his own x runs against the screen's:
                // away from the wall is his own -x on the left side
                st.pullTo(Math.max(st.minX, Math.min(st.maxX, st.x0 - wallDir * (34 + Math.random() * 22))), top, wallDir)
                return
            }
            st.releaseGrips()
            if (world.dock !== "off") topDock(); else drop()
            return
        }
        if (climbStage === "fall") landed()
    }
    // melts into the top frame for a while
    function topDock() {
        climbStage = "merged"
        st.dockSide = "top"
        st.place = "dock"
        st.dockRise = 0
        st.riseInDock()
    }
    Timer { id: topStayTimer; onTriggered: if (brain.doing === "topDock") brain.drop() }
    // lets go: falls to the floor, turning right way up on the way
    function drop() {
        topStayTimer.stop()
        if (st.sleeping) { st.sleeping = false; tucked = false }
        st.stopDockAnims()
        doing = "climb"
        climbStage = "fall"
        st.dockRise = 0
        st.place = "sky"
        st.y0 = world.insets.top
        st.surfaceRot = 180
        // the cloud drifts down; the others fall
        if (st.skin === "kumo") { st.mood = "happy"; st.glide(st.x0, world.floorY, 0, 1800, Easing.InOutSine); return }
        st.feel("scared", 2)
        const sc = voice("scared"); if (sc) st.call(sc)
        st.glide(st.x0, world.floorY, 0, 620, Easing.InQuad)
    }
    // ── the pointer: close above him, he jumps for it; caught, he hangs on ──
    // (from activity normal up). Shaken hard to and fro he flies off.
    property bool onPointer: false
    property real ptrX: -1
    property real ptrY: -1
    property real ptrT: 0
    property real ptrVX: 0
    property real lastLunge: 0
    property real pointerCool: 0
    property real caughtAt: 0
    property var shakes: []
    property int shakeDir: 0
    function mayLunge() {
        // (also while saving power: you start it with the pointer, like a command)
        return ["normal", "lively", "max"].indexOf(act) >= 0 && !world.dnd && !world.fullscreen
            && world.pointerHolder === null && !st.sleeping
            && (doing === "idle" && onFloor(st.place) || inFrame())
            && !st.held && !st.flying && !st.moving && Date.now() > pointerCool
            && (st.place === "stage" || !world.windowOver(st.x0, st.size * 0.5))
    }
    // a dome in the bottom frame: the pointer close above it brings him out
    function inFrame() { return doing === "dock" && st.place === "dock" && st.dockSide === "frame" && !hiding && !pinned }
    // where his raised hands get to at the top of a jump of height h
    function gripY(h) { return world.floorY - h - st.hangLen }
    function pointerMoved(x, y) {
        const now = Date.now()
        if (onPointer) { hangOnPointer(x, y, now); return }
        ptrX = x; ptrY = y
        if (!mayLunge() || now - lastLunge < 900 / trait("pointer")) return
        const dx = x - st.x0, above = gripY(0) - y
        const keen = trait("pointer")
        if (Math.abs(dx) > st.size * 2.2 * keen || above < -st.size * 0.4 || above > st.size * 2.8 * Math.max(1, keen * 0.8)) return
        lastLunge = now
        if (inFrame()) {
            // out of the frame first, then for it if it is still there
            noDockUntil = now + 20000
            pendingAction = () => { if (Math.hypot(ptrX - st.x0, ptrY - gripY(0)) < st.size * 3) lunge() }
            doing = "undock"
            st.undock("stage")
            return
        }
        lunge()
    }
    function lunge() {
        const step = Math.max(-st.size * 1.1, Math.min(st.size * 1.1, ptrX - st.x0))
        // (higher than a drift for the cloud: it jumps for the pointer like the others)
        const h = Math.max(st.skin === "kumo" ? 31 : 16, Math.min(st.size * 2.8, gripY(0) - ptrY + 6))
        st.mood = "curious"
        st.gazeY = -1; st.gazeX = step > 0 ? 0.5 : step < 0 ? -0.5 : 0
        // arms down and back while he gathers himself, then they go for it
        st.useHands(1500)
        st.handLX = -st.size * 0.12; st.handLY = st.size * 0.1
        st.handRX = st.size * 0.12; st.handRY = st.size * 0.1
        if (!st.hop(st.x0 + step, h)) return
        doing = "lunge"
        reachSide = ptrX >= st.x0 ? 1 : -1
        reachFrom = Date.now()
        aimX = ptrX + gripDX; aimY = ptrY + gripDY
        reachTick.start()
        lungeCheck.interval = 90 + st.hopDur / 2
        lungeCheck.restart()
    }
    // in the air both hands reach for the pointer wherever it is, the one on
    // its side ahead, the other a little behind and lower
    property int reachSide: 1
    property real reachFrom: 0
    // where the hands aim: follows the pointer smoothly (it comes 30 times a second)
    property real aimX: 0
    property real aimY: 0
    function reachFor(px, py) {
        const reach = st.size * 1.05
        for (const side of [-1, 1]) {
            const bx = st.x0 + side * st.size * (0.36 + 0.2 * st.handsOut) * st.sx
            const by = st.y0 - st.lift - st.hover - st.bodyH * 0.34
            const lead = side === reachSide
            let dx = px + side * 4 - bx, dy = py + (lead ? 0 : 6) - by
            const d = Math.hypot(dx, dy), r = reach * (lead ? 1 : 0.85)
            if (d > r) { dx *= r / d; dy *= r / d }
            if (side < 0) { st.handLX = dx; st.handLY = dy } else { st.handRX = dx; st.handRY = dy }
        }
    }
    Timer {
        id: reachTick
        interval: 16; repeat: true
        onTriggered: {
            if (brain.doing !== "lunge") { stop(); return }
            // after the gathering (90 ms) the arms shoot up
            if (Date.now() - brain.reachFrom < 70) return
            const st = brain.st
            brain.aimX += (brain.ptrX + brain.gripDX - brain.aimX) * 0.35
            brain.aimY += (brain.ptrY + brain.gripDY - brain.aimY) * 0.35
            // moved to his other side: the other hand leads now
            const dx = brain.aimX - st.x0
            if (dx * brain.reachSide < -st.size * 0.12) brain.reachSide = -brain.reachSide
            brain.reachFor(brain.aimX, brain.aimY)
            st.gazeX = Math.max(-1, Math.min(1, dx / st.size))
            // out of reach to the side: he leans after it
            st.lean = Math.max(-16, Math.min(16, dx / st.size * 12))
        }
        onRunningChanged: if (!running && brain.doing !== "lunge") brain.st.lean = 0
    }
    Timer {
        id: lungeCheck
        onTriggered: {
            if (brain.doing !== "lunge") return
            const gx = brain.st.x0, gy = brain.gripY(brain.st.lift)
            if (brain.world.pointerHolder === null && Math.hypot(brain.ptrX - gx, brain.ptrY - gy) < brain.st.size * 0.55) brain.catchPointer()
            else {
                // missed: the hands snap shut on nothing, up where it was
                reachTick.stop()
                const st = brain.st, mx = (st.handLX - st.size * 0.56 + st.handRX + st.size * 0.56) / 2
                st.handLX = mx + st.size * 0.56 - st.size * 0.06; st.handRX = mx - st.size * 0.56 + st.size * 0.06
                st.handLY = st.handRY = Math.min(st.handLY, st.handRY)
                st.jolt()
                lungeMiss.restart()
            }
        }
    }
    // missed: lands, a little cross, and maybe again
    Timer { id: lungeMiss; interval: 420; onTriggered: if (brain.doing === "lunge") { brain.st.lean = 0; brain.doing = "idle"; if (Math.random() < 0.4) brain.st.feel("angry", 1); brain.moodBackLater() } }
    function catchPointer() {
        world.pointerHolder = st
        // the hands round the arrow's body, a little below its tip: the
        // arrow is drawn over everything, so they hold it from the sides
        st.hangFrom(ptrX + gripDX, ptrY + gripDY)
        st.gripSpread = 5.5
        st.ropeLen = 0; st.theta = 0; st.omega = 0
        st.hangPlace()
        onPointer = true
        doing = "onPointer"
        caughtAt = Date.now()
        ptrT = Date.now(); ptrVX = 0; ptrVXs = 0
        shakes = []; shakeDir = 0
        st.feel("happy", 3)
        st.call(voice("gotIt", undefined, tr("Hab dich!", "Got you!", "つかまえた!")))
        hangTired.restart()
    }
    // where the grip sits from the pointer's tip (Adwaita arrow, 30 px)
    readonly property real gripDX: 5
    readonly property real gripDY: 11
    property real ptrVXs: 0
    function hangOnPointer(x, y, now) {
        const dt = Math.max(0.004, (now - ptrT) / 1000)
        const vx = (x - ptrX) / dt
        // the hands go with it, the body lags behind and swings; the speed
        // smoothed, or every uneven step of the pointer would jerk him
        const vs = ptrVXs * 0.65 + vx * 0.35
        const l = st.ropeLen + st.hangLen * 0.6
        st.omega -= (vs - ptrVXs) * Math.cos(st.theta) / l * 0.9
        st.omega = Math.max(-9, Math.min(9, st.omega))
        ptrVXs = vs
        st.pivotX = x + gripDX; st.pivotY = y + gripDY
        st.hangPlace()
        // shaking: quick turns to and fro
        const dir = vs > 1400 ? 1 : vs < -1400 ? -1 : 0
        if (dir !== 0 && dir !== shakeDir) {
            shakeDir = dir
            shakes = shakes.filter(t => now - t < 1000).concat([now])
            if (shakes.length >= 3 && now - caughtAt > 600) { shakenOff(); return }
            st.feel("scared", Math.min(3, shakes.length))
        }
        ptrX = x; ptrY = y; ptrT = now; ptrVX = vx
        // off the screen with it: lets go
        if (x < 0 || x > world.areaW || y < 0 || y > world.areaH) shakenOff()
    }
    function shakenOff() {
        if (!onPointer) return
        onPointer = false
        hangTired.stop()
        world.pointerHolder = null
        pointerCool = Date.now() + 25000
        letGo()
        st.call(tr("Uiii!", "Whoa!", "うわぁ!"))
    }
    // tired of hanging: lets go by himself
    Timer { id: hangTired; interval: 60000; onTriggered: if (brain.onPointer) { brain.shakenOff(); brain.st.call(brain.tr("Genug!", "Enough!", "もういいや!")) } }

    // what was asked for while he was up there, after the bob of the landing
    Timer { id: landedThen; property var f: null; interval: 450; onTriggered: if (f && brain.doing === "idle") { const g = f; f = null; g() } }
    function landed() {
        climbStage = ""
        st.place = "stage"
        st.surfaceRot = 0
        st.y0 = world.floorY
        st.bob()
        st.mood = Math.random() < 0.6 ? "happy" : "proud"
        if (pendingAction) { const f = pendingAction; pendingAction = null; doing = "idle"; landedThen.f = f; landedThen.restart(); return }
        if (pinned) { doing = "idle"; return }
        doing = "back"
        homeAfterLanding.restart()
    }
    Timer { id: homeAfterLanding; interval: 1800; onTriggered: if (brain.doing === "back" && brain.st.place === "stage") brain.st.dive("home") }

    // ── news from the machine (aiboud): the main one tells it, all show it ──
    // recording (wave into the camera), a download, the battery running low,
    // updates waiting, a long build or update finished. Off with "moods".
    Connections {
        target: brain.world
        function onNews(kind, d) { brain.onMachine(kind, d) }
    }
    property int batteryStage: 0         // 0 fine, 1 low (≤ 15 %), 2 nearly empty (≤ 5 %)
    property int knownUpdates: -1
    function shortName(n) { n = String(n || ""); return n.length > 28 ? n.slice(0, 25) + "…" : n }
    function duration(secs) {
        return secs < 120 ? secs + " s" : Math.round(secs / 60) + " min"
    }
    function onMachine(kind, d) {
        if (!world.moods || !st.active || world.dnd) return
        let text = "", mood = "happy", react = "cheer", level = 2
        switch (kind) {
        case "recording":
            text = say(d.on ? "recOn" : "recOff"); react = "wave"
            break
        case "download":
            text = say("download").replace("%1", shortName(d.name)); react = "jump"
            break
        case "battery": {
            const stage = d.charging ? 0 : d.level <= 5 ? 2 : d.level <= 15 ? 1 : 0
            const before = batteryStage
            batteryStage = stage
            if (stage === before) return
            if (stage === 1) { text = say("batLow").replace("%1", d.level); mood = "sleepy"; react = "yawn" }
            else if (stage === 2) { text = say("batCrit"); mood = "scared"; react = "fright" }
            else if (d.charging) { text = say("batOk"); react = "cheer" }
            else return
            break
        }
        case "updates":
            if (d.count <= 0 || d.count <= knownUpdates) { knownUpdates = d.count; return }
            knownUpdates = d.count
            text = say("updates").replace("%1", d.count); mood = "curious"; react = "look"
            break
        case "job":
            text = say(d.kind === "update" ? "updDone" : "buildDone").replace("%1", d.name).replace("%2", duration(d.secs))
            level = d.kind === "update" ? 2 : 3
            break
        case "locked":
            // locked: nothing to see; unlocked: a hello, the longer away the gladder
            if (d.on) return
            if (st.sleeping || doing === "sleep") wake(true)
            text = say(d.away > 600 ? "welcome" : "welcomeShort")
            react = "wave"; level = d.away > 600 ? 3 : 2
            break
        case "mic":
            // on: a finger on his lips (shy and quiet); off: nothing to say
            if (!d.on) return
            text = say("micOn").replace("%1", shortName(d.by)); mood = "shy"; react = "look"
            break
        case "usb":
            text = say("usb").replace("%1", shortName(d.name)); mood = "curious"; react = "jump"
            break
        default:
            return
        }
        if (main) announce(text, mood)
        showNews(react, mood, level)
    }
    // the main one says it: a bubble out front, a line in an open chat, or
    // at least a call beside him when he is busy with something else
    function announce(text, mood) {
        if (world.chatOpen) { world.logAdd("note", text); return }
        if (world.notifications && !st.sleeping && ["idle", "dock", "walk", "toDock", "back"].indexOf(doing) >= 0) {
            toStage("", text, mood, 5000, false)
            return
        }
        st.call(text)
    }
    function showNews(react, mood, level) {
        if (st.sleeping && react !== "fright") return
        if (mood === "scared") st.feel("scared", 2)
        else if (mood === "happy") st.feel("happy", level)
        else st.mood = mood
        const docked = st.place === "dock", free = onFloor(st.place) && !st.moving
        switch (react) {
        case "wave":
            st.gazeX = 0; st.gazeY = 0.2
            if (docked) st.dockMove("wave", 1, 1, 0); else if (free) st.wave()
            break
        case "jump":
            if (docked) st.dockMove("peek", 1, 1, 1); else if (free) st.jump(26)
            break
        case "cheer":
            if (docked) st.dockMove("up", 1, 1, 0); else if (free) { st.cheer(); st.jump(14) }
            break
        case "look":
            st.gazeY = -0.6
            break
        }
        moodBack.interval = mood === "sleepy" ? 20000 : 5000
        moodBack.restart()
    }

    // ── games for two: tag and hide and seek ─────────────────────
    // Tag: whoever is "it" (world.tagIt) chases, the other runs; cornered he
    // jumps over the chaser. A touch, "got you!", and the other one is it.
    // After about 40 s both are out of breath.
    function startTag(o) {
        if (!o || !o.brain) return false
        for (const b of [brain, o.brain]) {
            if (b.doing === "play") b.stopPlay()
            b.st.stopAll()
            b.doing = "tag"
            b.st.feel("happy", 2)
        }
        world.tagIt = Math.random() < 0.5 ? st : o
        world.tagUntil = Date.now() + 36000 + Math.random() * 12000
        world.tagFreeze = Date.now() + 1200
        world.tagIt.call(tr("Ich bin dran!", "I'm it!", "オニだよ!"))
        return true
    }
    Timer {
        interval: 140; repeat: true
        running: brain.doing === "tag"
        onTriggered: brain.tagStep()
    }
    // the one who was caught counts down before he chases
    Timer {
        id: countdown
        property var target: null
        property int n: 3
        interval: 750; repeat: true
        onTriggered: {
            if (!target || n <= 0) { stop(); return }
            target.call(String(n))
            n--
        }
    }
    function tagPlayers() { return world.active.filter(c => c.brain && c.brain.doing === "tag") }
    function endTag() {
        for (const c of tagPlayers()) {
            c.brain.doing = "idle"
            c.danceRest()
            c.feel("happy", 2)
            c.call(tr("Puh!", "Phew!", "ふぅ!"))
            c.squat()
            c.brain.moodBackLater()
        }
        world.tagIt = null
    }
    function tagStep() {
        const players = tagPlayers()
        if (players.length < 2 || !onFloor(st.place) || st.held) { endTag(); return }
        if (Date.now() > world.tagUntil) { endTag(); return }
        const it = world.tagIt
        // only the one who is it waits after a touch: the other gets a head start
        if (st.moving || (it === st && Date.now() < world.tagFreeze)) return
        // the chaser is a little faster, so a touch comes now and then
        const speed = it === st ? 1.3 + Math.random() * 0.25 : 0.85 + Math.random() * 0.25
        if (it === st) {
            // the chaser: after the nearest one
            let target = null, d = 1e9
            for (const c of players) if (c !== st && Math.abs(c.x0 - st.x0) < d) { d = Math.abs(c.x0 - st.x0); target = c }
            if (!target) { endTag(); return }
            const dir = target.x0 > st.x0 ? 1 : -1
            const reach = (target.size + st.size) * 0.58
            if (d <= reach + 10) {
                // got you
                st.poke(dir); target.jolt(); target.mood = "surprised"
                st.call(voice("gotIt", undefined, tr("Hab dich!", "Got you!", "つかまえた!")))
                world.tagIt = target
                world.tagFreeze = Date.now() + 2600
                target.feel("happy", 2)
                countdown.target = target
                countdown.n = 3
                countdown.restart()
                return
            }
            st.gazeX = dir
            // aims where the other one will be (he is moving away), not where he is
            const lead = target.moving ? 45 : 0
            st.hop(st.x0 + dir * Math.min(Math.max(10, d - reach * 0.4 + lead), (52 + Math.random() * 26) * speed), 10 + Math.random() * 8)
            return
        }
        // a runner: away from the chaser, over him when cornered, a taunt when far
        const dx = st.x0 - it.x0, dist = Math.abs(dx)
        if (dist > 420) {
            if (Math.random() < 0.1) { st.gazeX = -Math.sign(dx); st.mood = "smug"; st.wave() }
            return
        }
        const dir = dx === 0 ? (Math.random() < 0.5 ? -1 : 1) : Math.sign(dx)
        // now and then he turns round to tease, and loses a moment
        if (dist > 160 && Math.random() < 0.12) { st.gazeX = -dir; st.mood = "smug"; st.squat(); return }
        const to = st.x0 + dir * (48 + Math.random() * 26) * speed
        if (to < st.minX + 4 || to > st.maxX - 4) {
            // cornered: over the chaser to the open side
            if (dist < (it.size + st.size) * 1.4 && leapOver(it, -dir)) { st.call(tr("Hihi!", "Hee!", "へへっ!")); return }
            return
        }
        st.gazeX = dir
        st.hop(to, 9 + Math.random() * 8)
    }

    // Hide and seek: the seeker covers his eyes and counts to ten; the other
    // hides in the frame (a dome with closed eyes) or up at the top edge.
    // Then "ready or not": a wrong place or two first, then he finds him.
    property bool hiding: false
    property var seekFor: null
    property int seekCount: 0
    property real seekSpot: 0
    property int seekWrong: 0
    function startHide(o) {
        if (!o || !o.brain) return false
        if (doing === "play") stopPlay()
        st.stopAll()
        doing = "seek"
        seekFor = o
        seekCount = 0
        // hands over the eyes, facing out
        st.useHands(30000)
        st.handLX = st.size * 0.42; st.handLY = -st.bodyH * 0.38
        st.handRX = -st.size * 0.42; st.handRY = -st.bodyH * 0.38
        st.coverEyes = true
        st.gazeX = 0
        st.feel("happy", 2)
        o.brain.goHide(st)
        seekTimer.interval = 700; seekTimer.restart()
        return true
    }
    Timer { id: seekTimer; repeat: false; onTriggered: brain.seekNext() }
    function seekNext() {
        if (doing !== "seek") return
        const o = seekFor
        if (!o || !o.active || !o.brain) { endSeek(); return }
        if (seekCount < 10) {
            seekCount++
            st.call(String(seekCount))
            seekTimer.interval = 650; seekTimer.restart()
            return
        }
        if (seekCount === 10) {
            seekCount++
            st.coverEyes = false
            st.handLX = 0; st.handLY = 0; st.handRX = 0; st.handRY = 0
            st.call(tr("Ich komme!", "Ready or not!", "いくよー!"))
            st.mood = "curious"
            seekWrong = 1 + Math.floor(Math.random() * 2)
            seekTimer.interval = 900; seekTimer.restart()
            return
        }
        if (st.moving) { seekTimer.interval = 200; seekTimer.restart(); return }
        // a wrong place first: there, look left and right
        if (seekWrong > 0) {
            seekWrong--
            const span = st.maxX - st.minX
            let x = st.minX + Math.random() * span
            if (Math.abs(x - o.x0) < span * 0.2) x = st.minX + ((x - st.minX + span * 0.5) % span)
            walkTarget = x
            doing = "seekWalk"
            nextHop()
            return
        }
        // there he is
        const top = o.place === "sky" || (o.place === "dock" && o.dockSide === "top")
        walkTarget = Math.max(st.minX, Math.min(st.maxX, o.x0 + (st.x0 < o.x0 ? -1 : 1) * st.size * (top ? 0.2 : 0.9)))
        doing = "seekFind"
        nextHop()
    }
    // arrived somewhere while seeking
    function seekArrived() {
        if (doing === "seekWalk") {
            doing = "seek"
            st.gazeX = -1; lookLR.restart()
            seekTimer.interval = 1400; seekTimer.restart()
            return
        }
        // found
        const o = seekFor
        doing = "seek"
        if (!o || !o.brain) { endSeek(); return }
        st.gazeX = o.x0 > st.x0 ? 1 : -1
        if (o.place === "dock" && o.dockSide === "frame") {
            st.poke(st.gazeX); o.jolt()
        } else st.gazeY = -1
        st.call(tr("Gefunden!", "Found you!", "みーつけた!"))
        st.feel("happy", 3)
        o.brain.found()
        endSeekLater.restart()
    }
    Timer { id: lookLR; interval: 600; onTriggered: { brain.st.gazeX = 1; brain.st.mood = "curious" } }
    Timer { id: endSeekLater; interval: 2500; onTriggered: brain.endSeek() }
    function endSeek() {
        seekTimer.stop()
        st.coverEyes = false
        st.gazeY = 0
        st.handLX = 0; st.handLY = 0; st.handRX = 0; st.handRY = 0
        if (doing.indexOf("seek") === 0) doing = "idle"
        seekFor = null
        moodBackLater()
    }
    // the hider: off to a spot, into the frame (eyes shut) or up the rope
    function goHide(seeker) {
        if (doing === "play") stopPlay()
        hiding = true
        st.feel("happy", 2)
        st.call(tr("Hihi!", "Hee hee!", "えへへ!"))
        const far = seeker.x0 < world.areaW / 2 ? st.maxX - Math.random() * 300 : st.minX + Math.random() * 300
        if (Math.random() < 0.45 && !saving) {
            doing = "toHide"; walkTarget = far; hideHow = "top"
        } else {
            doing = "toHide"; walkTarget = far; hideHow = "frame"
        }
        nextHop()
    }
    property string hideHow: "frame"
    // in the frame: eyes half shut, keeping still (once he has melted in)
    Timer { id: hidePeek; interval: 1500; onTriggered: if (brain.hiding) brain.st.mood = "sleepy" }
    function hideNow() {
        if (hideHow === "top") { doing = "idle"; grapple(["hide"]); return }
        doing = "idle"
        forceSide = "frame"
        goDock()
        hidePeek.restart()
    }
    // found: out of the hiding place, laughing
    function found() {
        hiding = false
        hidePeek.stop()
        st.feel("happy", 3)
        st.call(tr("Hihi, gefunden!", "Hee, you found me!", "えへへ、見つかっちゃった!"))
        if (doing === "grapple" && grStage === "hiding") { monkeyPlan = [Math.random() < 0.5 ? "dismount" : "abseil"]; grStage = "monkey"; grTimer.interval = 600; grTimer.restart() }
        else if (st.place === "dock") { noDockUntil = Date.now() + 60000; wake(true); leaveDock() }
    }

    // ── hobbies: Bao loves a snack, Robo repairs, Mochi naps up top ──
    readonly property real snackLike: trait("snack")
    property real lastSnack: 0
    property real lastRepair: 0
    function eatSnack() {
        if (!onFloor(st.place) || st.moving) return false
        lastSnack = Date.now()
        doing = "snack"
        st.feel("happy", 2)
        st.call(voice("snack", undefined, pickCall(["Mampf!", "Lecker!", "Hmm!"], ["Nom!", "Yummy!", "Mmm!"], ["もぐもぐ!", "おいしい!", "んー!"])))
        st.eatSnack()
        return true
    }
    // each figure's own pastime: Shiro juggles, Momo does yoga, Kuro polishes his glass
    readonly property string hobbyKind: trait("hobby")
    readonly property real hobbyLike: hobbyKind ? 5 : 0
    property real lastHobby: 0
    function doHobby(kind) {
        const k = kind || hobbyKind
        if (!k || !onFloor(st.place) || st.moving) return false
        lastHobby = Date.now()
        doing = "hobby"
        if (k === "juggle") { st.feel("happy", 2); st.call(pickCall(["Hopp, hopp!", "Schau mal!"], ["Hup, hup!", "Look!"], ["ほいっ、ほいっ!", "見て見て!"])); st.juggle() }
        else if (k === "yoga") { st.call(pickCall(["Ommm …", "Und ausatmen …"], ["Ommm …", "And breathe out …"], ["オーム …", "はい、息をはいて …"])); st.yoga() }
        else {
            st.mood = "smug"
            // Neko washes, Arai scrubs, Kuro polishes his glass
            st.call(st.skin === "neko" ? pickCall(["*putz putz*"], ["*lick lick*"], ["*ぺろぺろ*"])
                    : st.skin === "arai" ? pickCall(["*schrubb schrubb*"], ["*scrub scrub*"], ["*ごしごし*"])
                    : pickCall(["*quietsch quietsch*"], ["*squeak squeak*"], ["*きゅっきゅっ*"]))
            st.polish()
        }
        return true
    }
    function idleBuddy() {
        const f = others.filter(o => o.brain && o.brain.doing === "idle" && onFloor(o.place) && !o.sleeping)
        return f.length ? f[Math.floor(Math.random() * f.length)] : null
    }

    // ── a race: side by side to the far edge, the winner jumps for joy ──
    property real lastRace: 0
    function startRace(o) {
        if (!o || !o.brain || !onFloor(st.place) || !onFloor(o.place)) return false
        for (const b of [brain, o.brain]) { b.lastRace = Date.now(); if (b.doing === "play") b.stopPlay(); b.st.stopAll(); b.doing = "raceReady" }
        // the far side from both, a start line between them
        const mid = (st.x0 + o.x0) / 2
        const dir = mid < world.areaW / 2 ? 1 : -1
        world.raceGoal = dir > 0 ? st.maxX : st.minX
        world.raceDir = dir
        world.raceWinner = null
        st.gazeX = dir; o.gazeX = dir
        st.call(tr("Wettrennen!", "Race you!", "かけっこしよう!"))
        raceCount.n = 3; raceCount.players = [st, o]; raceCount.restart()
        return true
    }
    Timer {
        id: raceCount
        property int n: 3
        property var players: []
        interval: 700; repeat: true
        onTriggered: {
            if (n > 0) { brain.st.call(String(n)); for (const p of players) p.bob(); n--; return }
            stop()
            brain.st.call(brain.tr("Los!", "Go!", "よーい、ドン!"))
            for (const p of players) if (p.brain && p.brain.doing === "raceReady") p.brain.raceGo()
        }
    }
    function raceGo() {
        doing = "race"
        st.feel("happy", 2)
        raceStep.restart()
    }
    // short fast hops; each figure a little different, now and then a stumble
    Timer {
        id: raceStep; interval: 60; repeat: true
        onTriggered: {
            if (brain.doing !== "race") { stop(); return }
            if (brain.st.moving) return
            const goal = brain.world.raceGoal, dir = brain.world.raceDir
            if ((goal - brain.st.x0) * dir <= 4) { stop(); brain.raceFinish(); return }
            if (Math.random() < 0.04) { brain.st.squat(); return }
            const step = Math.min(Math.abs(goal - brain.st.x0), 40 + Math.random() * 30)
            brain.st.hop(brain.st.x0 + dir * step, 8 + Math.random() * 8)
        }
    }
    function raceFinish() {
        doing = "idle"
        if (!world.raceWinner) {
            world.raceWinner = st
            st.feel("happy", 3); st.cheer(); st.jump(24)
            st.call(tr("Erster!", "First!", "いちばん!"))
        } else {
            st.mood = Math.random() < 0.5 ? "sad" : "smug"
            st.call(pickCall(["Knapp!", "Nächstes Mal!"], ["Close one!", "Next time!"], ["おしい!", "次こそ!"]))
        }
        moodBackLater()
    }

    // ── leapfrog: in a row, the one at the back leaps over all the others ──
    // (they crouch as the buck), crouches at the front, then the next one.
    // At the edge of the screen the row turns round. Two turns each.
    property var frogPlayers: []
    property int frogDir: 1
    property var frogJumper: null
    property int frogTurns: 0
    property string frogStage: ""
    property var frogTargets: ({})
    function startFrog(ps) {
        ps = ps.filter(p => p && p.brain && onFloor(p.place))
        if (ps.length < 2) return false
        for (const p of ps) { const b = p.brain; b.lastRace = Date.now(); if (b.doing === "play") b.stopPlay(); p.stopAll(); b.doing = "frog" }
        const mean = ps.reduce((a, p) => a + p.x0, 0) / ps.length
        frogDir = mean < world.areaW / 2 ? 1 : -1
        const gap = Math.max(...ps.map(p => p.size)) * 1.3
        const sorted = ps.slice().sort((a, b) => (a.x0 - b.x0) * frogDir)
        const lo = Math.max(...ps.map(p => p.minX)), hi = Math.min(...ps.map(p => p.maxX))
        let start = mean - frogDir * gap * (ps.length - 1) / 2
        start = Math.max(lo, Math.min(hi, start)); const end = start + frogDir * gap * (ps.length - 1)
        if (end < lo || end > hi) start += (end < lo ? lo - end : hi - end)
        const t = {}
        sorted.forEach((p, i) => t[p.slot] = start + frogDir * gap * i)
        frogTargets = t
        frogPlayers = sorted
        frogTurns = 0
        frogJumper = null
        frogStage = "line"
        st.call(tr("Bockspringen!", "Leapfrog!", "馬とびしよう!"))
        frogTick.restart()
        return true
    }
    // crouched as the buck: low and wide, hands on the floor, looking back
    function bock(p, on) {
        if (on) {
            p.useHands(600000)
            p.sy = 0.78; p.sx = 1.14
            p.handLX = p.size * 0.08; p.handLY = p.size * 0.2; p.handRX = -p.size * 0.08; p.handRY = p.size * 0.2
            p.gazeX = -frogDir; p.gazeY = -0.3
        } else {
            p.sy = 1; p.sx = 1; p.gazeY = 0
            p.handLX = 0; p.handLY = 0; p.handRX = 0; p.handRY = 0
            p.useHands(250)
        }
    }
    function endFrog(cheer) {
        frogTick.stop()
        frogStage = ""
        for (const p of frogPlayers) {
            if (!p.brain || p.brain.doing !== "frog") continue
            bock(p, false)
            p.brain.doing = "idle"
            if (cheer) { p.feel("happy", 3); p.cheer(); p.brain.moodBackLater() }
        }
        frogPlayers = []
    }
    Timer {
        id: frogTick; interval: 110; repeat: true
        onTriggered: brain.frogStep()
    }
    function frogStep() {
        const ps = frogPlayers
        if (ps.length < 2 || ps.some(p => !p.brain || p.brain.doing !== "frog" || p.held || !onFloor(p.place))) { endFrog(false); return }
        if (frogStage === "line") {
            // everybody to his place in the row
            let ready = true
            for (const p of ps) {
                const tx = frogTargets[p.slot]
                if (Math.abs(tx - p.x0) > 4) { ready = false; if (!p.moving) p.hop(p.x0 + Math.sign(tx - p.x0) * Math.min(Math.abs(tx - p.x0), 50), 10) }
                else if (p.moving) ready = false
            }
            if (!ready) return
            frogStage = "jump"
            for (const p of ps) bock(p, true)
            frogNext()
            return
        }
        const j = frogJumper
        if (!j || j.moving) return
        // the nearest one ahead of him that he has not leapt yet
        const ahead = ps.filter(o => o !== j && (o.x0 - j.x0) * frogDir > 2).sort((a, b) => (a.x0 - b.x0) * frogDir)
        if (!ahead.length) {
            // at the front: crouches himself, the next one comes
            bock(j, true)
            j.feel("happy", 2)
            if (++frogTurns >= Math.max(6, ps.length * 2)) { endFrog(true); return }
            frogNext()
            return
        }
        const o = ahead[0], near = (o.size + j.size) * 0.62
        const dist = Math.abs(o.x0 - j.x0)
        if (dist > near + 10) { j.hop(o.x0 - frogDir * near, 10); return }
        const land = o.x0 + frogDir * near
        j.hop(land, 40 + o.size * 0.45)
        j.armUp(0, 0.8)
        o.jolt()
        if (Math.random() < 0.25) o.mood = "surprised"
    }
    // the one at the back is next; with the front at the edge the row turns round first
    function frogNext() {
        const ps = frogPlayers
        const gap = Math.max(...ps.map(p => p.size)) * 1.3
        const front = ps.reduce((a, p) => (p.x0 - a.x0) * frogDir > 0 ? p : a, ps[0])
        const room = frogDir > 0 ? front.maxX - front.x0 : front.x0 - front.minX
        if (room < gap * 1.1) { frogDir = -frogDir; for (const p of ps) p.gazeX = -frogDir }
        const back = ps.reduce((a, p) => (p.x0 - a.x0) * frogDir < 0 ? p : a, ps[0])
        frogJumper = back
        bock(back, false)
        back.gazeX = frogDir
        back.feel("happy", 2)
        if (Math.random() < 0.5) back.call(tr("Hopp!", "Hup!", "ぴょん!"))
    }

    // ── jump rope: two turn it (or one, the other end tied to the edge of
    // the screen), the one in the middle jumps whenever it comes under his
    // feet. It gets faster; when it catches his feet the roles change. ──
    property var jrPlayers: []           // all who play, in the order they take turns jumping
    property var jrTurners: []           // one or two
    property var jrJumper: null
    property int jrRound: 0
    property int jrCount: 0
    property int jrBest: 0
    property var jrBestBy: null
    property real jrSpeed: 0             // rad/s
    property real jrT: 0
    property real jrGo: 0
    property string jrStage: ""
    property real jrWallX: 0             // the tied end with only two players
    property var jrTargets: ({})
    function startRope(ps) {
        ps = ps.filter(p => p && p.brain && onFloor(p.place))
        if (ps.length < 2) return false
        ps = ps.slice(0, 3)
        for (const p of ps) { const b = p.brain; b.lastRace = Date.now(); if (b.doing === "play") b.stopPlay(); p.stopAll(); b.doing = "rope" }
        jrPlayers = ps
        jrRound = 0
        jrBest = 0; jrBestBy = null
        st.call(tr("Seilspringen!", "Jump rope!", "なわとびしよう!"))
        ropeRound()
        return true
    }
    // a round: who jumps, who turns, and where they stand
    function ropeRound() {
        const ps = jrPlayers
        const j = ps[jrRound % ps.length]
        const turners = ps.filter(p => p !== j)
        jrJumper = j
        jrTurners = turners
        const span = Math.max(...ps.map(p => p.size)) * 6.5
        const t = {}
        const lo = Math.max(...ps.map(p => p.minX)), hi = Math.min(...ps.map(p => p.maxX))
        if (turners.length >= 2) {
            const mid = Math.max(lo + span / 2, Math.min(hi - span / 2, ps.reduce((a, p) => a + p.x0, 0) / ps.length))
            const [a, b] = turners.slice().sort((p, q) => p.x0 - q.x0)
            t[a.slot] = mid - span / 2; t[b.slot] = mid + span / 2; t[j.slot] = mid
            jrTurners = [a, b]
        } else {
            // tied to the nearer edge of the screen; the jumper halfway, the turner beyond
            const left = j.x0 < world.areaW / 2
            jrWallX = left ? world.insets.left : world.areaW - world.insets.right
            const side = left ? 1 : -1
            t[j.slot] = Math.max(lo, Math.min(hi, jrWallX + side * span * 0.5))
            t[turners[0].slot] = Math.max(lo, Math.min(hi, jrWallX + side * span))
        }
        jrTargets = t
        jrStage = "place"
        world.jrSlack = true
        jrTick.interval = 110
        jrTick.restart()
    }
    function endRope() {
        jrTick.stop()
        jrStage = ""
        world.jrOn = false
        for (const p of jrPlayers) {
            if (!p.brain || p.brain.doing !== "rope") continue
            p.lift = 0; p.sx = 1; p.sy = 1
            p.handLX = 0; p.handLY = 0; p.handRX = 0; p.handRY = 0
            p.useHands(250)
            p.brain.doing = "idle"
        }
        jrPlayers = []
    }
    // where a turner's hand holds the rope (screen x, up from the floor)
    function jrHand(p, toRight) {
        const hx = toRight ? p.size * (0.36 + 0.2 * p.handsOut) * p.sx + p.handRX : -p.size * (0.36 + 0.2 * p.handsOut) * p.sx + p.handLX
        const hy = -p.bodyH * 0.34 + (toRight ? p.handRY : p.handLY)
        return Qt.point(p.x0 + hx, hy)
    }
    Timer {
        id: jrTick; interval: 110; repeat: true
        onTriggered: brain.ropeStep()
    }
    function ropeStep() {
        const ps = jrPlayers
        if (ps.length < 2 || ps.some(p => !p.brain || p.brain.doing !== "rope" || p.held || !onFloor(p.place))) { endRope(); return }
        const j = jrJumper
        if (jrStage === "place") {
            let ready = true
            for (const p of ps) {
                const tx = jrTargets[p.slot]
                if (Math.abs(tx - p.x0) > 4) { ready = false; if (!p.moving) p.hop(p.x0 + Math.sign(tx - p.x0) * Math.min(Math.abs(tx - p.x0), 55), 10) }
                else if (p.moving) ready = false
            }
            if (!ready) return
            // turners face the jumper and take the rope
            for (const p of jrTurners) { p.gazeX = j.x0 > p.x0 ? 1 : -1; p.useHands(600000) }
            j.gazeX = 0; j.gazeY = 0.2
            world.jrTop = j.bodyH * 1.45
            jrCount = 0
            jrSpeed = Math.PI * 2 / 1.15
            world.jrPhase = Math.PI * 0.55
            world.jrPlace = j.place
            world.jrOn = true
            ropeHands(world.jrPhase)
            jrStage = "ready"
            jrT = Date.now(); jrGo = jrT
            j.call(tr("Los!", "Go!", "せーの!"))
            jrTick.interval = 16
            return
        }
        const now = Date.now(), dt = Math.min(0.05, (now - jrT) / 1000)
        jrT = now
        // a moment with the rope still, then it turns
        if (jrStage === "ready") { if (now - jrGo > 500) jrStage = "turn"; else return }
        if (jrStage === "turn") {
            const before = world.jrPhase
            let ph = before + jrSpeed * dt
            // under his feet: a jump counted, faster, and maybe this time it catches
            if (before < Math.PI && ph >= Math.PI) {
                jrCount++
                const risk = 0.015 + Math.max(0, jrSpeed - 6) * 0.03 + jrCount * 0.006
                if (jrCount > 2 && Math.random() < risk) { ropeMiss(); return }
                j.call(String(jrCount))
                jrSpeed = Math.min(Math.PI * 2 / 0.5, jrSpeed * 1.045)
            }
            if (ph >= Math.PI * 2) ph -= Math.PI * 2
            world.jrPhase = ph
            ropeHands(ph)
            // the jumper is up while it passes under him
            const u = -Math.cos(ph), H = j.size * 0.42
            const k = Math.max(0, (u - 0.25) / 0.75)
            j.lift = H * Math.pow(k, 0.7)
            j.sy = 1 + 0.08 * k - (u > 0 && u < 0.3 ? 0.08 : 0)
            j.sx = 1 - 0.05 * k
            return
        }
    }
    // the turners' hands go round with the rope
    function ropeHands(ph) {
        const r = jrTurners[0] ? jrTurners[0].size * 0.16 : 10
        jrTurners.forEach(p => {
            const toRight = jrJumper.x0 > p.x0
            const hx = (toRight ? 1 : -1) * r * 0.25 * Math.sin(ph), hy = -p.size * 0.1 - r * Math.cos(ph)
            if (toRight) { p.handRX = hx; p.handRY = hy } else { p.handLX = hx; p.handLY = hy }
        })
        const a = jrTurners[0], b = jrTurners[1]
        const pa = jrHand(a, jrJumper.x0 > a.x0)
        let pb
        if (b) pb = jrHand(b, jrJumper.x0 > b.x0)
        else pb = Qt.point(jrWallX, -jrJumper.size * 0.45)
        const [l, rr] = pa.x < pb.x ? [pa, pb] : [pb, pa]
        world.jrAX = l.x; world.jrAY = l.y; world.jrBX = rr.x; world.jrBY = rr.y
        world.jrSlack = false
    }
    function ropeMiss() {
        const j = jrJumper
        jrStage = "miss"
        world.jrPhase = Math.PI
        world.jrSlack = true
        j.lift = 0; j.sx = 1; j.sy = 1
        j.jolt()
        j.feel(Math.random() < 0.5 ? "sad" : "angry", 1)
        j.call(tr("Hoppla! ", "Oops! ", "あっ! ") + jrCount)
        if (jrCount > jrBest) { jrBest = jrCount; jrBestBy = j }
        jrTick.stop()
        ropeNext.restart()
    }
    Timer {
        id: ropeNext; interval: 1700
        onTriggered: {
            if (brain.jrStage !== "miss") return
            brain.jrRound++
            if (brain.jrRound >= brain.jrPlayers.length) {
                const w = brain.jrBestBy
                if (w) { w.feel("happy", 3); w.cheer(); w.call(brain.tr("Rekord: ", "Record: ", "新記録: ") + brain.jrBest) }
                brain.endRope()
                return
            }
            brain.ropeRound()
        }
    }

    // ── rock, paper, scissors: three shakes of the fist, then the hands ──
    function startRps(o) {
        if (!o || !o.brain || !onFloor(st.place) || !onFloor(o.place)) return false
        for (const b of [brain, o.brain]) { b.lastRace = Date.now(); if (b.doing === "play") b.stopPlay(); b.doing = "rps" }
        const dir = o.x0 > st.x0 ? 1 : -1
        st.gazeX = dir; o.gazeX = -dir
        rps.players = [st, o]
        rps.n = 0
        rps.restart()
        return true
    }
    Timer {
        id: rps
        property var players: []
        property int n: 0
        interval: 450; repeat: true
        onTriggered: {
            const ps = players
            if (ps.length < 2 || ps.some(p => !p.brain || p.brain.doing !== "rps")) { stop(); return }
            n++
            if (n <= 3) {
                // "Schnick, Schnack, Schnuck": the fists go up and down
                const w = brain.tr(["Schnick", "Schnack", "Schnuck!"], ["Rock", "Paper", "Scissors!"], ["じゃん", "けん", "ぽん!"])
                ps[0].call(w[n - 1])
                for (const p of ps) p.armUp(p.gazeX, 0.5)
                return
            }
            stop()
            const signs = ["✊", "✋", "✌"]
            const a = Math.floor(Math.random() * 3), b = Math.floor(Math.random() * 3)
            ps[0].call(signs[a]); ps[1].call(signs[b])
            rpsEnd.result = a === b ? 0 : (a - b + 3) % 3 === 1 ? 1 : 2
            rpsEnd.players = ps
            rpsEnd.restart()
        }
    }
    Timer {
        id: rpsEnd
        property int result: 0
        property var players: []
        interval: 1300
        onTriggered: {
            const ps = players
            for (const p of ps) if (p.brain) p.brain.doing = "idle"
            if (result === 0) {
                for (const p of ps) { p.mood = "surprised"; p.brain.moodBackLater() }
                ps[0].call(brain.tr("Unentschieden!", "A draw!", "あいこ!"))
                return
            }
            const win = ps[result - 1], lose = ps[2 - result]
            win.feel("happy", 3); win.cheer()
            lose.mood = Math.random() < 0.5 ? "sad" : "angry"
            win.brain.moodBackLater(); lose.brain.moodBackLater()
        }
    }

    function doRepair() {
        if (!onFloor(st.place) || st.moving) return false
        lastRepair = Date.now()
        doing = "repair"
        st.mood = "curious"
        st.call(pickCall(["Klonk!", "Bzzt!", "Mal sehen …"], ["Clonk!", "Bzzt!", "Let's see …"], ["カン!", "ビビッ!", "どれどれ …"]))
        st.repair()
        return true
    }
    Connections {
        target: brain.st
        function onSnackDone() {
            if (brain.doing !== "snack") return
            brain.doing = "idle"
            brain.st.feel("happy", brain.st.skin === "bao" ? 3 : 2)
            brain.moodBackLater()
        }
        function onRepaired() {
            if (brain.doing !== "repair") return
            brain.doing = "idle"
            brain.st.mood = "proud"
            brain.st.call(brain.pickCall(["Repariert!", "Wie neu!"], ["Fixed!", "Good as new!"], ["直った!", "新品同様!"]))
            brain.moodBackLater()
        }
        function onHobbyDone() {
            if (brain.doing !== "hobby") return
            brain.doing = "idle"
            brain.st.feel("happy", 2)
            brain.moodBackLater()
        }
    }
    // sleepy: Mochi climbs up first and naps in the top frame; the rest
    // sleep where they are
    property bool napTop: false
    function napOrSleep(force) {
        if ((force || trait("napTop")) && world.dock !== "off" && !saving && onFloor(st.place)
                && (force || Math.random() < 0.75)) {
            napTop = true
            st.mood = "sleepy"
            st.call(voice("yawn", undefined, pickCall(["*gähn*"], ["*yawn*"], ["*ふあぁ*"])))
            climb()
            return
        }
        goSleep()
    }

    // ── a new buddy: the others turn to him, wave and are glad ─────
    // (a figure switched on or swapped for another while Aibou runs; not at
    // the start). The nearest one calls hello and goes over to greet him.
    property string wasSkin: st.skin
    Connections {
        target: brain.st
        function onActiveChanged() {
            if (brain.st.active) brain.newHere()
            else if (brain.doing === "duet" || brain.doing === "toDuet") brain.endDuet(false)
        }
        function onSkinChanged() {
            const before = brain.wasSkin
            brain.wasSkin = brain.st.skin
            if (brain.st.active && before !== "" && before !== "none") brain.newHere()
        }
    }
    function newHere() {
        if (Date.now() - world.bornAt < 8000) return
        newHereTimer.restart()
    }
    // a moment to appear first
    Timer { id: newHereTimer; interval: 1100; onTriggered: brain.introduce() }
    function introduce() {
        if (!st.active) return
        st.mood = "happy"
        let lead = null, d = 1e9
        for (const o of others) {
            if (!o.brain) continue
            o.brain.welcome(st)
            const free = o.brain.doing === "idle" && onFloor(o.place)
            const dd = Math.abs(o.x0 - st.x0)
            if (free && dd < d) { d = dd; lead = o }
        }
        if (lead) lead.brain.welcomeLead(st)
        waveBack.restart()
    }
    Timer {
        id: waveBack; interval: 700
        onTriggered: {
            const st = brain.st
            if (st.place === "dock") st.dockMove("wave", 1, 1, 0)
            else if (!st.moving) st.wave()
            st.feel("happy", 3)
            brain.moodBackLater()
        }
    }
    // somebody new is here: turn, wave, be glad (asleep: wake up for it)
    function welcome(newbie) {
        if (st.sleeping || doing === "sleep") wake(true)
        if (["idle", "dock", "walk", "roll", "back"].indexOf(doing) < 0) return
        st.gazeX = newbie.x0 > st.x0 ? 1 : -1
        st.feel("happy", 2)
        if (st.place === "dock") st.dockMove(Math.random() < 0.5 ? "wave" : "up", 1, 1, 0)
        else if (onFloor(st.place) && !st.moving) {
            st.wave()
            if (Math.random() < 0.5) st.jump(14)
        }
        moodBack.restart()
    }
    // the nearest one says hello out loud and goes over to greet him
    function welcomeLead(newbie) {
        st.call(voice("hi", newbie.name, tr("Hallo " + newbie.name + "!", "Hi " + newbie.name + "!", newbie.name + "、こんにちは!")))
        welcomeWalk.target = newbie
        welcomeWalk.restart()
    }
    Timer {
        id: welcomeWalk
        property var target: null
        interval: 1400
        onTriggered: {
            const o = target
            if (!o || !o.active || brain.doing !== "idle" || !brain.onFloor(brain.st.place)) return
            const kinds = ["hug", "five", "wave"]
            brain.meet(o, kinds[Math.floor(Math.random() * kinds.length)])
        }
    }

    // ── tickled, picked up and thrown ─────────────────────────────
    function tickle() {
        if (st.place === "dock") {
            // the dome wriggles and giggles, then he pops out laughing
            st.tickleDome()
            if (st.mood === "angry" || st.mood === "happy" && st.level >= 3) st.feel("angry")
            else st.feel("happy", 2)
            tickleOut.restart()
            return
        }
        if (st.place !== "home" && st.place !== "stage") return
        if (doing === "play") stopPlay()
        st.tickle()
        const l = voice("tickle"); if (l) st.call(l)
        moodBackLater.restart()
    }
    Timer { id: tickleOut; interval: 650; onTriggered: if (brain.st.place === "dock") brain.fetchOut() }
    Timer { id: moodBackLater; interval: 1800; onTriggered: if (!brain.st.held && !brain.st.calm("happy")) restart() }

    // grabbed where the pointer pressed (screen px): wherever he was, he now
    // hangs from it, over everything (the sky surface)
    property real holdDX: 0
    property real holdDY: 0
    property var trail: []               // recent pointer positions, for the throw
    property real flyVX: 0
    property real flyVY: 0
    property real flyT: 0
    property int bounces: 0
    function grab(gx, gy) {
        topStayTimer.stop(); homeAfterLanding.stop(); tickleOut.stop(); flight.stop()
        stageTimer.stop()
        pendingAction = null
        if (doing === "play") stopPlay()
        if (st.sleeping) st.sleeping = false
        bubbleShown = false
        doing = "held"
        trail = []
        // melted in: he stays in the frame and slides along its edge with the
        // pointer, until he is pulled towards the middle (drag)
        if (st.place === "dock") {
            st.stopDockAnims()
            st.dockShift = 0
            st.held = true
            heldEdge = st.dockSide === "bar" ? world.barEdge : st.dockSide === "far" ? (world.barEdge === "left" ? "right" : "left")
                     : st.dockSide === "top" ? "top" : "bottom"
            st.dockRise = 1
            st.mood = "surprised"
            return
        }
        // where his feet were on the screen (in the chat window: just under the pointer)
        const feet = st.place === "sky" ? st.y0 : st.place === "chat" ? gy + st.size * 0.5 : world.floorY
        st.stopAll()
        st.held = true
        heldEdge = ""
        st.place = "sky"
        holdDX = st.x0 - gx
        holdDY = Math.max(st.size * 0.4, feet - gy)
        drag(gx, gy)
        hang()
    }
    // hanging from the pointer
    function hang() {
        st.mood = "surprised"
        st.sx = 0.92; st.sy = 1.1
        st.useHands(100000)
        st.handLY = -st.size * 0.35; st.handRY = -st.size * 0.35
    }
    // the edge he is melted into while held ("" while he hangs from the pointer)
    property string heldEdge: ""
    // pointer right at an edge he can melt into (the bar's side, the bottom, the top)
    function edgeAt(gx, gy) {
        const m = 4
        if (gy >= world.floorY - m) return "bottom"
        if (gy <= world.insets.top + m) return "top"
        // both sides: the bar's and the frame's across from it
        if (gx <= world.insets.left + m) return "left"
        if (gx >= world.areaW - world.insets.right - m) return "right"
        return ""
    }
    // how far the pointer is from the edge he is melted into
    function edgeDist(gx, gy) {
        return heldEdge === "bottom" ? world.floorY - gy : heldEdge === "top" ? gy - world.insets.top
             : heldEdge === "left" ? gx - world.insets.left : world.areaW - world.insets.right - gx
    }
    // slides along the edge to where the pointer is
    function slideInEdge(gx, gy) {
        if (heldEdge === "left" || heldEdge === "right") {
            st.barYAt = Math.max(world.insets.top + st.size * 1.2, Math.min(world.floorY - st.size * 1.1, gy))
            // along a popout that is open: out to its edge or onto its corner
            if (st.place === "dock") makeRoom()
        }
        else
            st.x0 = Math.max(st.minX, Math.min(st.maxX, gx))
    }
    function meltHere(edge, gx, gy) {
        st.stopAll()
        heldEdge = edge
        st.dockSide = edge === "bottom" ? "frame" : edge === "top" ? "top" : edge === world.barEdge ? "bar" : "far"
        slideInEdge(gx, gy)
        st.sink = 1
        st.place = "dock"
        st.mood = "surprised"
        st.riseInDock()
    }
    function popOut(gx, gy) {
        st.stopDockAnims()
        heldEdge = ""
        st.place = "sky"
        st.surfaceRot = 0
        st.sink = 0
        holdDX = 0
        holdDY = st.size * 0.75
        st.x0 = Math.max(st.minX, Math.min(st.maxX, gx))
        st.y0 = Math.max(world.insets.top + st.size, Math.min(world.floorY, gy + holdDY))
        st.jolt()
        hang()
    }
    function drag(gx, gy) {
        if (!st.held) return
        const now = Date.now()
        trail = trail.filter(p => now - p.t < 90).concat([{ t: now, x: gx, y: gy }])
        if (heldEdge !== "") {
            // pulled towards the middle: out he hops, else along the edge
            if (edgeDist(gx, gy) > st.size * 1.1) popOut(gx, gy)
            else slideInEdge(gx, gy)
            return
        }
        const edge = edgeAt(gx, gy)
        if (edge !== "") { meltHere(edge, gx, gy); return }
        const x = Math.max(st.minX, Math.min(st.maxX, gx + holdDX))
        // he dangles behind the motion
        const dx = x - st.x0
        st.lean = Math.max(-30, Math.min(30, st.lean * 0.6 - dx * 1.2))
        st.x0 = x
        st.y0 = Math.max(world.insets.top + st.size, Math.min(world.floorY, gy + holdDY))
    }
    function release() {
        if (!st.held) return
        st.held = false
        // let go in the frame: he stays there
        if (heldEdge !== "") {
            heldEdge = ""
            noDockUntil = 0
            st.mood = "happy"
            moodBackLater.restart()
            if (st.dockSide === "top") { doing = "topDock"; topStay.interval = 25000 + Math.random() * 45000; topStay.restart() }
            else doing = "dock"
            makeRoom()
            return
        }
        st.useHands(400)
        st.handLY = 0; st.handRY = 0
        const a = trail[0], b = trail[trail.length - 1]
        const dt = a && b ? Math.max(16, b.t - a.t) / 1000 : 1
        flyVX = a && b ? Math.max(-3200, Math.min(3200, (b.x - a.x) / dt)) : 0
        flyVY = a && b ? Math.max(-3200, Math.min(3200, (b.y - a.y) / dt)) : 0
        bounces = 0
        st.sx = 1; st.sy = 1
        st.flying = true
        // thrown hard he is frightened, the harder the more
        const speed = Math.hypot(flyVX, flyVY)
        if (speed > 1100) st.feel("scared", speed > 1900 ? 3 : 2)
        else st.mood = speed > 900 ? "surprised" : "neutral"
        flyT = Date.now()
        flight.start()
    }
    // a throw: gravity, the side walls and the floor; he spins with his speed
    Timer {
        id: flight
        interval: 16
        repeat: true
        onTriggered: brain.flyStep()
    }
    function flyStep() {
        const now = Date.now()
        const dt = Math.min(0.04, (now - flyT) / 1000)
        flyT = now
        flyVY += 2600 * dt
        let x = st.x0 + flyVX * dt, y = st.y0 + flyVY * dt
        const top = world.insets.top + st.size
        if (x < st.minX) { x = st.minX; flyVX = Math.abs(flyVX) * 0.5; st.jolt() }
        if (x > st.maxX) { x = st.maxX; flyVX = -Math.abs(flyVX) * 0.5; st.jolt() }
        if (y < top) { y = top; flyVY = Math.abs(flyVY) * 0.3 }
        st.rot += flyVX * dt * 0.55
        st.lean *= 0.9
        if (y >= world.floorY) {
            y = world.floorY
            if (flyVY > 520 && bounces < 3) {
                bounces++
                flyVY = -flyVY * 0.42
                flyVX *= 0.7
                st.x0 = x; st.y0 = y
                st.jolt()
                return
            }
            st.x0 = x; st.y0 = y
            thrownLanded()
            return
        }
        st.x0 = x; st.y0 = y
    }
    function thrownLanded() {
        flight.stop()
        st.flying = false
        st.lean = 0
        st.settle()
        st.place = "stage"
        st.restX = st.x0
        st.y0 = world.floorY
        st.bob()
        // a hard throw makes him cross (crosser with every one), a gentle one is
        // fun, and his own jump from the top makes him proud
        if (stunt) { stunt = false; st.mood = "proud"; st.cheer() }
        else if (bounces >= 2) st.feel("angry", bounces)
        else st.mood = "happy"
        moodBackLater.restart()
        doing = "back"
        homeAfterLanding.interval = 3200
        homeAfterLanding.restart()
    }

    // ── teasing each other ────────────────────────────────────────
    property real lastTease: 0
    property real lastQuarrel: 0

    // rolled or hopped over a dome in the frame: the one below is annoyed,
    // the one above grins
    property var steppedOn: null
    Timer {
        interval: 80; repeat: true
        running: brain.st.moving && (brain.st.place === "home" || brain.st.place === "stage") && brain.others.length > 0
        onTriggered: {
            for (const o of brain.others) {
                if (o.place !== "dock" || o.dockSide !== "frame" || o.dockRise < 0.5) continue
                const d = Math.abs(o.x0 - brain.st.x0)
                if (d < o.size * 0.4 && brain.steppedOn !== o) {
                    brain.steppedOn = o
                    if (o.brain) o.brain.trodden(brain.st)
                    brain.st.mood = "smug"
                    moodBack.restart()
                } else if (d > o.size && brain.steppedOn === o) brain.steppedOn = null
            }
        }
    }
    function trodden(by) {
        if (doing === "sleep") { wake(true) }
        st.gazeX = by.x0 > st.x0 ? 1 : -1
        // again and again: annoyed, angry, furious
        st.feel("angry")
        st.jolt()
        angryBack.restart()
    }

    // ── leaving the frame before doing anything else ───────────────
    // an action asked for while he is melted in (by hand, IPC): he hops out
    // first, then does it
    property var pendingAction: null
    property int stageIdle: 0
    // a command from the chat window for him while he sits in it: the
    // window folds into him, he jumps out, does it, and once he is idle again
    // jumps back in and the window opens as it was
    property bool backToChat: false
    property real chatAway: 0
    property real chatHold: 0            // a command is still under way until then (Commands.qml)
    function leaveChatFor(f) {
        pendingAction = f
        backToChat = true
        chatAway = Date.now()
        // out of the corner, the window stays open
        world.chatHopOut(st)
    }
    Timer {
        interval: 500; repeat: true
        running: brain.backToChat
        property int calm: 0
        onTriggered: {
            const free = brain.doing === "idle" && !brain.st.moving && !brain.pendingAction
                         && (brain.st.place === "home" || brain.st.place === "stage") && Date.now() > brain.chatHold
            calm = free ? calm + 1 : 0
            // a little while idle (the kiss is over), or it took too long
            if (calm >= 3 || Date.now() - brain.chatAway > 30000) {
                calm = 0
                brain.backToChat = false
                // the window still open (or opened again): back into it
                if (brain.world.chatOpen && brain.st.place !== "chat") brain.openChat()
            }
        }
    }
    function whenFree(f, front) {
        // up in the top frame: down first, then it (landed runs it)
        if (st.place === "dock" && st.dockSide === "top") { pendingAction = f; drop(); return }
        if (st.place === "dock") {
            noDockUntil = Date.now() + 90000
            pendingAction = f
            doing = "undock"
            st.undock(front ? "stage" : "home")
            return
        }
        // in front of the windows, where it can be seen
        if (front && st.place === "home") {
            pendingAction = f
            doing = "toFront"
            if (!st.moving) st.dive("stage"); else pendingStage.start()
            return
        }
        if (st.place === "home" || st.place === "stage") f()
    }
    // walks over to another one and starts a quarrel there
    property var quarrelTarget: null
    function quarrelWith(o) {
        quarrelTarget = o
        doing = "toQuarrel"
        const side = o.x0 > st.x0 ? -1 : 1
        walkTarget = Math.max(st.minX, Math.min(st.maxX, o.x0 + side * (o.size + st.size) * 0.5))
        nextHop()
    }

    // ── an outing from the frame: out, over to a neighbour's dome, a poke,
    // back and in again; all in front of the windows
    property var outingTo: null
    property real outingFrom: 0
    function outing() {
        const n = others.find(o => o.brain && o.place === "dock" && o.dockSide === "frame" && o.brain.doing === "dock"
                                   && Math.abs(o.x0 - st.x0) < 900)
        if (!n || st.place !== "dock" || st.dockSide !== "frame") return false
        outingTo = n
        outingFrom = st.x0
        lastTease = Date.now()
        const side = n.x0 > st.x0 ? -1 : 1
        walkTarget = Math.max(st.minX, Math.min(st.maxX, n.x0 + side * n.size * 0.9))
        doing = "outing"
        st.mood = "smug"
        st.undock("stage")
        return true
    }
    function outingPoke() {
        const n = outingTo
        outingTo = null
        if (n && n.place === "dock") {
            const dir = n.x0 > st.x0 ? 1 : -1
            st.gazeX = dir
            st.poke(dir)
            outingAnswer.target = n
            outingAnswer.restart()
        }
        backFromOuting.restart()
    }
    Timer {
        id: outingAnswer
        property var target: null
        interval: 380
        onTriggered: {
            if (!target) return
            target.jolt()
            target.gazeX = target.x0 > brain.st.x0 ? -1 : 1
            target.mood = Math.random() < 0.6 ? "angry" : "happy"
            if (target.brain) target.brain.moodBackLater()
            brain.st.mood = target.mood === "angry" ? "surprised" : "happy"
            moodBack.restart()
        }
    }
    Timer {
        id: backFromOuting
        interval: 1100
        onTriggered: {
            brain.doing = "outingBack"
            brain.walkTarget = brain.outingFrom
            brain.nextHop()
        }
    }

    // two domes side by side in the frame: they look at each other, and then
    // one nudges the other, they giggle, or one sulks
    function dockChatter() {
        const n = others.find(o => o.brain && o.place === "dock" && o.dockSide === st.dockSide
                                   && o.brain.doing === "dock" && Math.abs((st.dockSide === "bar" || st.dockSide === "far" ? o.barDockY - st.barDockY : o.x0 - st.x0)) < 520)
        if (!n) return
        const dir = (st.dockSide === "bar" || st.dockSide === "far" ? n.barDockY - st.barDockY : n.x0 - st.x0) > 0 ? 1 : -1
        st.gazeX = dir; n.gazeX = -dir
        chatterWith = n
        chatterTimer.restart()
    }
    property var chatterWith: null
    Timer {
        id: chatterTimer; interval: 700
        onTriggered: {
            const n = brain.chatterWith, me = brain.st
            brain.chatterWith = null
            if (!n || n.place !== "dock") return
            const r = Math.random()
            if (r < 0.4) {
                // a nudge: a hand comes out of his dome, the other one jolts,
                // cross or amused
                me.pokeFromDock(me.gazeX)
                me.mood = "smug"
                n.jolt(); n.mood = Math.random() < 0.5 ? "angry" : "happy"
            } else if (r < 0.75) {
                me.mood = "happy"; n.mood = "happy"
                me.jolt(); n.jolt()
            } else {
                me.mood = "sad"; n.mood = "smug"
            }
            moodBack.restart()
            if (n.brain) n.brain.moodBackLater()
        }
    }

    // sneaks up to another one and pokes it
    function tease(target) {
        const near = target ? [target] : others.filter(o => o.brain && (o.place === st.place || (o.place === "dock" && o.dockSide === "frame"))
                                         && ["idle", "dock", "sleep"].indexOf(o.brain.doing) >= 0)
        if (near.length === 0) { startWalk(false); return }
        friend = near[Math.floor(Math.random() * near.length)]
        lastTease = Date.now()
        doing = "tease"
        st.mood = "smug"
        const side = friend.x0 > st.x0 ? -1 : 1
        walkTarget = Math.max(st.minX, Math.min(st.maxX, friend.x0 + side * (friend.size + st.size) * 0.5))
        nextHop()
    }
    function pokeFriend() {
        doing = "idle"
        const f = friend
        friend = null
        if (!f || Math.abs(f.x0 - st.x0) > (f.size + st.size)) return
        const dir = f.x0 > st.x0 ? 1 : -1
        st.gazeX = dir
        st.poke(dir)
        pokeAnswer.target = f
        pokeAnswer.restart()
    }
    Timer {
        id: pokeAnswer
        property var target: null
        interval: 380
        onTriggered: {
            if (!target || !target.brain) return
            const angry = target.brain.poked(brain.st)
            // the poked one is cross: he jumps back, caught
            if (angry) { brain.st.mood = "surprised"; brain.st.hop(brain.st.x0 - Math.sign(target.x0 - brain.st.x0) * 34, 16) }
            else { brain.st.mood = "happy"; brain.st.cheer() }
            moodBack.restart()
        }
    }
    // returns true when he is cross about it
    function poked(by) {
        const wasAsleep = doing === "sleep"
        if (wasAsleep) wake(true)
        st.gazeX = by.x0 > st.x0 ? 1 : -1
        const angry = wasAsleep || Math.random() < 0.5
        if (st.place === "dock") { st.jolt(); if (angry) st.feel("angry"); else st.mood = "happy" }
        else if (angry) { st.feel("angry"); st.jump(10) }
        else { st.mood = "happy"; st.jump(14) }
        if (angry) angryBack.restart(); else moodBack.restart()
        return angry
    }

    // walked into each other: they glare, bump a few times, then one grins
    // and the other walks off in a huff
    property var rival: null
    property int quarrelStep: 0
    function startQuarrel(o) {
        lastQuarrel = Date.now()
        rival = o
        doing = "quarrel"
        o.brain.joinQuarrel(st)
        st.gazeX = o.x0 > st.x0 ? 1 : -1
        st.feel("angry", 1)
        quarrelStep = 0
        quarrelTimer.start()
    }
    function joinQuarrel(by) {
        lastQuarrel = Date.now()
        if (doing === "play") stopPlay()
        doing = "quarrel"
        st.gazeX = by.x0 > st.x0 ? 1 : -1
        st.feel("angry", 1)
    }
    Timer {
        id: quarrelTimer
        interval: 430; repeat: true
        onTriggered: {
            const me = brain.st, o = brain.rival
            if (!o || !o.brain || o.brain.doing !== "quarrel") { stop(); brain.doing = "idle"; me.mood = "neutral"; return }
            brain.quarrelStep++
            // it heats up: annoyed, angry, and at the end both furious
            if (brain.quarrelStep === 2 || brain.quarrelStep === 4) { me.feel("angry"); o.feel("angry") }
            if (brain.quarrelStep <= 5) {
                // in turns: a little hop towards the other
                const who = brain.quarrelStep % 2 ? me : o
                const toward = (who === me ? o.x0 - me.x0 : me.x0 - o.x0) > 0 ? 1 : -1
                // in turns: a hop towards the other, or a poke with the hand
                if (brain.quarrelStep % 4 < 2) who.hop(who.x0 + toward * 4, 9 + brain.quarrelStep)
                else { who.poke(toward); (who === me ? o : me).jolt() }
                return
            }
            stop()
            const meWins = Math.random() < 0.5
            const winner = meWins ? me : o, loser = meWins ? o : me
            winner.mood = "smug"
            // now and then the loser cries
            loser.feel("sad", Math.random() < 0.4 ? 3 : 2)
            brain.rival = null
            brain.doing = "idle"
            o.brain.doing = "idle"
            winner.brain.moodBackLater()
            // the loser walks off the other way
            const away = loser.x0 > winner.x0 ? 1 : -1
            loser.brain.walkAway(away)
        }
    }
    function moodBackLater() { moodBack.restart() }
    function walkAway(dir) {
        doing = "walk"
        walkTarget = Math.max(st.minX, Math.min(st.maxX, st.x0 + dir * (160 + Math.random() * 160)))
        nextHop()
        sulk.restart()
    }
    Timer { id: sulk; interval: 4000; onTriggered: if (!brain.st.calm("sad")) restart() }

    // ── playing with the ball ─────────────────────────────────────
    property int playTicks: 0
    function startPlay() {
        if (!world.ballOut) world.throwIn(st.x0 + (Math.random() < 0.5 ? -90 : 90))
        joinPlay()
    }
    // over to where they play (in front or behind the windows), then in
    function joinGame() {
        const p = others.find(o => o.brain && o.brain.doing === "play")
        const where = world.ballHolder ? world.ballHolder.place : (p ? p.place : st.place)
        if (where === st.place) { joinPlay(); return }
        const f = () => { if (world.ballOut && world.players > 0) joinPlay() }
        if (st.place === "stage" && where === "home") { pendingAction = f; doing = "back"; st.dive("home"); return }
        whenFree(f, where === "stage")
    }
    function joinPlay() {
        doing = "play"
        playTicks = 0
        st.mood = "happy"
        world.players++
        playTimer.start()
    }
    function stopPlay() {
        if (doing !== "play") return
        playTimer.stop()
        // holding it: he drops it
        st.stopBall()
        if (world.ballHolder === st) world.throwBall(st, 0, 120)
        world.players = Math.max(0, world.players - 1)
        if (world.players === 0) world.takeAway()
        st.mood = "neutral"
        doing = "idle"
        energy = Math.max(energy, 0.2)
    }
    Timer {
        id: playTimer
        interval: 180 + Math.random() * 60; repeat: true
        onTriggered: if (!brain.st.moving) brain.playStep()
    }
    function playStep() {
        if (doing !== "play" || st.moving || st.busyWithBall) return
        const holder = world.ballHolder
        if (holder === st) return
        // in the user's hand: they watch it
        if (world.ballInHand) { st.gazeX = Math.max(-1, Math.min(1, (world.ballX - st.x0) / 160)); return }
        const mates = others.filter(o => o.brain && o.brain.doing === "play" && o.place === st.place)
        // hands still up from a catch that did not come
        if (world.ballH <= 2 && st.handLY < -1 && !holder) st.handsDown()
        // a mate has it: keep some room to catch a throw
        if (holder) {
            st.gazeX = holder.x0 > st.x0 ? 0.8 : -0.8
            if (Math.abs(holder.x0 - st.x0) < 220) {
                const away = st.x0 + (st.x0 > holder.x0 ? 1 : -1) * 70
                if (!blocked(away)) st.hop(Math.max(st.minX, Math.min(st.maxX, away)), 14)
            }
            return
        }
        // only the nearest goes for it; one about as near races him for it
        const goal = world.ballH > 2 ? world.landingX(st.size * 1.05) : world.ballX
        if (goal === null) return
        if (Date.now() < stunnedUntil) return
        const rivals = mates.filter(o => !o.busyWithBall).map(o => ({ o: o, d: Math.abs(goal - o.x0) }))
        const mine = Math.abs(goal - st.x0)
        const nearer = rivals.filter(r => r.d < mine)
        if (nearer.length > 1 || nearer.length === 1 && mine - nearer[0].d > Math.max(120, nearer[0].d * 0.3)) {
            // not his: watch, and keep a little room around him
            st.gazeX = Math.max(-1, Math.min(1, (world.ballX - st.x0) / 160))
            const close = mates.find(o => Math.abs(o.x0 - st.x0) < 130)
            if (close && Math.random() < 0.3) {
                const away = st.x0 + (st.x0 >= close.x0 ? 1 : -1) * 60
                if (away > st.minX && away < st.maxX && !blocked(away)) st.hop(away, 12)
            }
            return
        }
        // racing: right beside the other one now and then he shoves him
        const racer = nearer[0] ? nearer[0].o : rivals.find(r => r.d - mine < Math.max(120, mine * 0.3))?.o
        if (racer && Math.abs(racer.x0 - st.x0) < st.size * 1.3 && Math.random() < 0.3 && Date.now() > shovedAt + 1500) {
            shovedAt = Date.now()
            st.poke(racer.x0 > st.x0 ? 1 : -1)
            st.mood = "smug"
            racer.brain.shoved(st)
            return
        }
        // in the air: to where it comes down, hands up when it is near
        if (world.ballH > 2) {
            const lx = goal
            const d = lx - st.x0
            st.gazeX = Math.max(-1, Math.min(1, (world.ballX - st.x0) / 120))
            if (Math.abs(d) > 280) { st.roll(lx); return }
            if (Math.abs(d) > st.size * 0.35) st.hop(st.x0 + Math.sign(d) * Math.min(Math.abs(d), 70), 10)
            else st.handsUp()
            return
        }
        // on the floor: far off he rolls, near he hops; there he picks it up
        const d = world.ballX - st.x0
        st.gazeX = Math.max(-1, Math.min(1, d / 120))
        if (Math.abs(d) > 280 && Math.abs(world.ballVX) < 400) { st.roll(world.ballX - Math.sign(d) * st.size * 0.3); return }
        if (Math.abs(d) > st.size * 0.5) {
            const step = st.x0 + Math.sign(d) * Math.min(Math.abs(d) - st.size * 0.3, 60)
            if (blocked(step)) { st.jump(10); return }
            st.hop(step, 12 + Math.random() * 10)
            return
        }
        // still rolling fast: a kick; at rest: into his hands
        if (Math.abs(world.ballVX) > 150) {
            const dir = mates.length ? (mates[0].x0 > st.x0 ? 1 : -1) : (Math.random() < 0.5 ? 1 : -1)
            world.kick(dir, 0.3 + Math.random() * 0.4)
            st.jump(16)
            return
        }
        if (others.some(o => o.busyWithBall)) return
        st.pickUp(world.ballX - st.x0, world.ballR)
    }
    // he has it: at a mate (who tries to catch it) or against the screen's edge
    function throwOff() {
        const mates = others.filter(o => o.brain && o.brain.doing === "play" && o.place === st.place && o !== world.ballHolder)
        if (mates.length && Math.random() < 0.8) {
            const m = mates[Math.floor(Math.random() * mates.length)]
            throwTarget = { x: m.x0, h: m.lift + m.size * 1.05 }
            st.throwBall(m.x0 > st.x0 ? 1 : -1, 250 + Math.random() * 450)
        } else {
            // against the edge, hard, so it comes back
            const lo = world.insets.left, hi = world.areaW - world.insets.right
            const dir = (st.x0 - lo < hi - st.x0) === (Math.random() < 0.7) ? -1 : 1
            throwTarget = { wall: dir }
            st.throwBall(dir, 300 + Math.random() * 400)
        }
    }
    property var throwTarget: null
    // racing for the ball
    property real stunnedUntil: 0
    property real shovedAt: 0
    function shoved(by) {
        stunnedUntil = Date.now() + 650
        st.jolt()
        st.mood = "angry"
        st.lean = by.x0 > st.x0 ? -10 : 10
        leanBack.restart()
        moodBackLater.restart()
    }
    Timer { id: leanBack; interval: 300; onTriggered: brain.st.lean = 0 }
    Connections {
        target: brain.st
        function onBallGrabbed() {
            if (brain.doing !== "play") return
            brain.world.holdBall(brain.st)
            brain.st.mood = "happy"
            brain.throwOff()
        }
        function onBallReleased() {
            if (brain.world.ballHolder !== brain.st) return
            const t = brain.throwTarget
            if (t && t.wall !== undefined) {
                brain.world.throwBall(brain.st, t.wall * (750 + Math.random() * 450), 180 + Math.random() * 260)
            } else if (t) {
                const v = brain.world.lob(brain.st, t.x, t.h)
                brain.world.throwBall(brain.st, v.vx, v.vy)
            } else brain.world.throwBall(brain.st, 0, 300)
            brain.throwTarget = null
        }
    }
    // the ball reaches his hands in flight: mostly he catches it
    Connections {
        target: brain.world
        function onBallNear(c) {
            if (c !== brain.st || brain.doing !== "play" || brain.world.ballHolder || brain.st.busyWithBall) return
            if (Math.random() < 0.75) {
                brain.world.holdBall(brain.st)
                brain.st.handsUp()
                brain.st.bob()
                brain.st.mood = "happy"
                brain.throwOff()
            } else {
                // missed: it bounces off him
                brain.world.ballVX = -brain.world.ballVX * 0.5
                brain.world.ballVY = Math.abs(brain.world.ballVY) * 0.4
                brain.world.ballThrower = brain.st
                brain.world.ballThrownAt = Date.now()
                brain.st.jolt()
                brain.st.mood = "surprised"
            }
        }
    }
    Timer { id: handBack; interval: 260; onTriggered: brain.st.handRX = 0 }

    // ── sleeping ──────────────────────────────────────────────────
    function goSleep(byHand) {
        tucked = !!byHand
        if (doing === "play") stopPlay()
        doing = "sleep"
        st.mood = "sleepy"
        st.sleeping = true
    }
    function wake(quiet) {
        if (doing !== "sleep") return
        tucked = false
        st.sleeping = false
        st.mood = "neutral"
        boredom = 0
        // napping in the top frame: awake, he lets go and drops down
        if (st.place === "dock" && st.dockSide === "top") { doing = "topDock"; drop(); return }
        if (st.place === "dock") { doing = "dock"; return }
        doing = "idle"
        if (!quiet) { st.jump(10); st.cheer() }
    }
    function toggleSleep() { if (st.sleeping) wake(false); else goSleep(true) }

    // ── the stage: over the windows ───────────────────────────────
    property string stageMood: "neutral"
    property int stageMs: 6000
    function toStage(title, text, mood, ms, chat) {
        // the chat window has him; notifications go into the chat there
        if (main && (world.chatOpen || st.place === "chat")) return
        bubbleTitle = title
        bubbleText = text
        bubbleChat = chat
        stageMood = mood
        stageMs = ms
        if (doing === "play") stopPlay()
        if (st.sleeping) st.sleeping = false
        doing = chat ? "chat" : (title !== "" ? "notify" : "visit")
        if (st.place === "stage" && st.sink === 0) { arrived(); return }
        if (st.place === "dock") { backToDock = !pinned; st.undock("stage"); return }
        // behind a window: lifts its bottom edge like a cloth and steps out
        // from under it, instead of diving under the frame
        if (st.place === "home" && !st.moving && !world.clothBusy && !world.fullscreen && world.windowOver(st.x0, st.size * 0.5)) {
            clothArrive = true
            clothWait.up = true
            clothWait.start()
            return
        }
        if (!st.moving) st.dive("stage")
        else pendingStage.start()
    }
    property bool clothArrive: false     // out from under the cloth for a message: it shows when he is there
    Timer { id: pendingStage; interval: 100; repeat: true; onTriggered: if (!brain.st.moving) { stop(); brain.st.dive("stage") } }
    function placeDone() {
        if (st.place === "dock") { if (st.sink === 1 && st.dockRise < 0.5) st.riseInDock(); return }
        if (st.sink === 1) { st.surface(); return }
        if (pendingAction && (st.place === "home" || st.place === "stage")) {
            const f = pendingAction; pendingAction = null; doing = "idle"; f(); return
        }
        if (st.place === "chat") {
            if (doing === "chat") world.chatJumpIn(st); else world.chatJumpOut(st)
            return
        }
        if (st.place === "stage" && doing === "outing") { nextHop(); return }
        if (st.place === "stage" && doing !== "idle" && doing !== "back") arrived()
        else {
            const was = doing
            bubbleShown = false; doing = "idle"; st.mood = "neutral"
            if (was === "undock") st.jump(10)
        }
    }
    function arrived() {
        if (stageMood === "angry") st.feel("angry")
        else st.mood = stageMood
        if (bubbleText !== "" || bubbleChat) bubbleShown = true
        if (stageMood === "happy") st.wave()
        if (stageMood === "angry") st.jump(8)
        if (bubbleChat) wantFocus()
        stageTimer.interval = stageMs
        stageTimer.restart()
    }
    // came out of the frame for a message: goes back into it afterwards
    property bool backToDock: false
    function leaveStage() {
        stageTimer.stop()
        bubbleShown = false
        bubbleChat = false
        st.thinking = false
        const toDock = backToDock && world.dock !== "off"
        backToDock = false
        if (pinned) { doing = "idle"; st.mood = "neutral"; return }
        if (st.place !== "stage") return
        if (toDock) { doing = "dock"; st.dive("dock") }
        // a window over his place: back under it the way he came, lifting it
        else if (!world.clothBusy && !world.fullscreen && !st.moving && world.windowOver(st.x0, st.size * 0.5)) {
            doing = "visit"
            clothWait.up = false
            clothWait.start()
        }
        else st.dive("home")
    }
    Timer {
        id: stageTimer
        onTriggered: {
            if (brain.stageHeld || brain.st.thinking) { interval = 1500; restart(); return }
            brain.leaveStage()
        }
    }
    function holdStage(ms) { stageTimer.interval = ms; stageTimer.restart() }

    // front: stays over the windows and lives there
    // in and out under the cloth when it is free, else the plain dive
    function setFront(on) {
        if (on === pinned) return
        pinned = on
        if (doing === "play") stopPlay()
        if (st.sleeping) wake(true)
        bubbleShown = false
        // in the frame: he comes out of it straight onto the stage
        if (on && st.place === "dock") { toStage("", main ? say("front") : "", "happy", 2500, false); return }
        // nothing in front of him: he is visible anyway, just change sides
        if (!world.windowOver(st.x0, st.size * 0.5)) {
            st.place = on ? "stage" : "home"
            st.jump(12)
            if (on) toStage("", main ? say("front") : "", "happy", 2500, false)
            else { doing = "idle"; st.mood = "neutral" }
            return
        }
        if (!world.clothBusy) {
            doing = "visit"
            clothWait.up = on
            clothWait.start()
            return
        }
        if (on) toStage("", main ? say("front") : "", "happy", 2500, false)
        else toHomeLater.start()
    }
    Timer {
        id: clothWait
        property bool up: true
        interval: 50; repeat: true
        onTriggered: {
            if (brain.st.moving) return
            stop()
            // somebody else holds the cloth right now: the plain way
            if (brain.world.clothBusy) {
                if (up && brain.clothArrive) { brain.clothArrive = false; brain.st.dive("stage") }
                else if (up) brain.toStage("", brain.main ? brain.say("front") : "", "happy", 2500, false)
                else toHomeLater.start()
                return
            }
            brain.world.clothRequest(brain.st, up)
        }
    }
    Connections {
        target: brain.world
        function onClothDone(who, up) {
            if (who !== brain.st) return
            if (up && brain.clothArrive) { brain.clothArrive = false; brain.arrived(); return }
            if (up) brain.toStage("", brain.main ? brain.say("front") : "", "happy", 2500, false)
            else { brain.doing = "idle"; brain.st.mood = "neutral" }
        }
    }
    Timer { id: toHomeLater; interval: 50; repeat: true; onTriggered: if (!brain.st.moving) { stop(); if (brain.st.place === "stage") { brain.doing = "visit"; brain.st.dive("home") } } }

    function visit() { toStage("", say("visit"), Math.random() < 0.5 ? "curious" : "happy", 4500, false) }
    function hello() { toStage("", say("hello"), "happy", 4000, false) }
    function notify(n) {
        if (!world.notifications || world.dnd) return
        const urgent = n.urgency >= 2
        const text = n.body ? n.summary + "\n" + n.body : n.summary
        toStage(n.app || "", text, urgent ? "surprised" : "curious", Math.min(12000, 5000 + text.length * 40), false)
    }
    // ── popouts from the bar push him aside ───────────────────────
    Connections {
        target: brain.world
        function onPopoutChanged() { brain.makeRoom() }
    }
    function makeRoom() {
        const p = world.popout
        if (st.place !== "dock") return
        if (st.dockSide === "bar" && !world.barFlat) {
            const at = st.barDockY
            const covers = p && p.side === world.barEdge && at >= p.y - 10 && at <= p.y + p.h + 10
            const edge = world.barEdge === "left" ? world.insets.left : world.areaW - world.insets.right
            const to = !covers ? 0 : world.barEdge === "left" ? p.x + p.w - edge : edge - p.x
            // DMS moves his dome out with the popout's edge; where it would stick
            // out past the popout's end, onto that corner as a round bump
            // (dms-leiste-patch 14, the same rule)
            if (covers) {
                const half = Math.round(st.size * 1.2) / 2 + Math.round(st.size * 0.3)
                st.cornerMode = at - half < p.y || at + half > p.y + p.h
                const rr = st.size * 1.2 * 0.55, ci = -rr * 0.25
                st.cornerX = world.barEdge === "left" ? p.x + p.w - ci : p.x + ci
                st.cornerY = at - p.y < p.y + p.h - at ? p.y + ci : p.y + p.h - ci
            }
            if (to > 0 || st.dockShift > 0) {
                if (to > 0 && st.dockShift <= 0 && !st.held) surprised()
                st.shiftDock(Math.max(0, to))
            }
            return
        }
        // in the bottom frame: shoved out from under it along the floor
        if (st.dockSide === "frame" && p && p.y + p.h > world.floorY - 30
                && st.x0 > p.x - st.size * 0.6 && st.x0 < p.x + p.w + st.size * 0.6) {
            const left = p.x - st.size * 0.9, right = p.x + p.w + st.size * 0.9
            const to = (right <= st.maxX && (st.x0 - p.x > p.x + p.w - st.x0 || left < st.minX)) || left < st.minX ? right : left
            surprised()
            st.shove(to)
        }
    }
    function surprised() {
        st.mood = "surprised"
        surpriseBack.restart()
    }
    Timer { id: surpriseBack; interval: 1600; onTriggered: if (brain.st.mood === "surprised") brain.st.mood = "neutral" }

    // ── music: he dances to the beat when he has nothing else to do ─
    readonly property bool dancing: world.music && world.dance
                                    && (doing === "idle" || doing === "dock") && !st.sleeping
    property int beats: 0
    Connections {
        target: brain.world
        function onBeat(strength) {
            // a figure not on screen hears the beat too: it must not dance, or it
            // asks a visible one to a duet and holds her there (Nr. 27)
            if (!brain.st.active) return
            // dancing as a pair: the leader moves both, the partner waits for him
            if (brain.doing === "duet") { if (brain.duetLead) brain.duetStep(strength); return }
            if (!brain.dancing) return
            brain.beats++
            if (brain.wantDuet()) return
            // on battery with the saver on: every other beat only
            if (brain.saving && brain.beats % 2) return
            if (brain.st.place !== "dock") brain.st.mood = "happy"
            brain.danceStep(strength)
        }
        function onMusicChanged() {
            if (!brain.world.music && (brain.doing === "duet" || brain.doing === "toDuet")) brain.endDuet(false)
            brain.st.danceRest()
            if (!brain.world.music && brain.doing === "idle" && brain.st.mood === "happy") {
                brain.st.mood = "neutral"; brain.st.gazeX = 0
            }
        }
    }

    // ── dancing together ──────────────────────────────────────────
    // Two on the floor while music plays: now and then one hops over to the
    // other and they dance as a pair for 24–40 beats. The leader picks the
    // move for both every eight beats (four when it is fast):
    //   mirror  both bounce, arms up towards each other in turns
    //   call    one punches towards the other, who ducks; then the other way
    //   bump    both lean in and bump on the beat
    //   twirl   one holds a hand up, the other turns under it
    //   swap    one jumps over the other in a high arc
    //   five    a high five on every fourth beat
    property var partner: null
    property bool duetLead: false
    property int duetBeats: 0
    property int duetLength: 24
    property string duetMove: ""
    property real lastDuet: 0
    function wantDuet() {
        if (doing !== "idle" || (st.place !== "home" && st.place !== "stage") || st.moving) return false
        if (beats < 12 || beats % 8 !== 4 || Date.now() - lastDuet < 45000) return false
        const free = others.filter(o => o.brain && o.brain.doing === "idle" && samePlace(o) && !o.sleeping
                                         && !o.moving && Date.now() - o.brain.lastDuet > 45000)
        if (free.length === 0 || Math.random() > 0.45) return false
        startDuet(free[Math.floor(Math.random() * free.length)])
        return true
    }
    function startDuet(o) {
        partner = o
        duetLead = true
        lastDuet = Date.now()
        o.brain.joinDuet(st)
        doing = "toDuet"
        const side = o.x0 > st.x0 ? -1 : 1
        // an arm's length apart, so leaning in and punching do not overlap them
        walkTarget = Math.max(st.minX, Math.min(st.maxX, o.x0 + side * (o.size + st.size) * 0.9))
        st.mood = "happy"
        nextHop()
    }
    // the partner may still be on his way (toDuet) for a moment: not cut short
    Timer { id: duetGrace; interval: 1500 }
    function joinDuet(by) {
        duetGrace.restart()
        if (doing === "play") stopPlay()
        partner = by
        duetLead = false
        lastDuet = Date.now()
        doing = "duet"
        st.gazeX = by.x0 > st.x0 ? 1 : -1
        st.mood = "happy"
        st.wave()
    }
    function beginDuet() {
        if (!partner || !partner.brain || partner.brain.doing !== "duet") { doing = "idle"; partner = null; return }
        doing = "duet"
        duetBeats = 0
        duetLength = 24 + Math.floor(Math.random() * 3) * 8
        duetMove = ""
        st.gazeX = partner.x0 > st.x0 ? 1 : -1
        partner.gazeX = -st.gazeX
    }
    // the leader ends it for both: a bow (a little squat), a heart for Kuro and Shiro
    function endDuet(nice) {
        const o = partner
        if (o && o.brain && (o.brain.doing === "duet" || o.brain.doing === "toDuet")) {
            o.brain.partner = null
            o.brain.doing = "idle"
            o.danceRest()
            if (nice) { o.squat(); o.mood = "happy"; o.brain.moodBackLater() }
        }
        partner = null
        duetLead = false
        doing = "idle"
        st.danceRest()
        if (nice && o) {
            st.squat()
            if (st.skin === "kuro" && o.skin === "shiro" || st.skin === "shiro" && o.skin === "kuro") { st.towards = o.x0 > st.x0 ? 1 : -1; st.pop("heart") }
            else { st.towards = o.x0 > st.x0 ? 1 : -1; st.pop("star") }
            moodBack.restart()
        }
    }
    readonly property var duetMoves: ({
        fast: { mirror: 3, call: 3, bump: 3, five: 2, twirl: 1, swap: 1 },
        mid:  { mirror: 2, call: 2, bump: 2, five: 2, twirl: 3, swap: 2 },
        slow: { mirror: 3, bump: 2, twirl: 3, five: 1, swap: 1 }
    })
    function duetStep(strength) {
        const o = partner
        if (!o || !o.brain || o.brain.doing !== "duet" || o.held || st.held || !samePlace(o)) { endDuet(false); return }
        duetBeats++
        if (duetBeats > duetLength) { endDuet(true); return }
        const bpm = world.bpm > 0 ? world.bpm : 120
        const p = bpm >= 150 ? "fast" : bpm < 100 ? "slow" : "mid"
        if ((duetBeats - 1) % (p === "fast" ? 4 : 8) === 0) {
            let m = pick(duetMoves[p])
            if (m === duetMove) m = pick(duetMoves[p])
            duetMove = m
        }
        // fast music: the pair moves on every other beat and nods in between
        if (p === "fast" && duetBeats % 2) { st.bang(); o.bang(); return }
        const me = st
        const toO = o.x0 > me.x0 ? 1 : -1      // from me towards the partner
        // an arm's length apart: whoever drifted too close hops back out
        const gap = (o.size + me.size) * 0.9, dist = Math.abs(o.x0 - me.x0)
        if (dist < gap * 0.8 && !me.moving && !o.moving) {
            const mid = (o.x0 + me.x0) / 2
            o.hop(mid + toO * gap / 2, 10); me.hop(mid - toO * gap / 2, 10)
            return
        }
        me.gazeX = toO; o.gazeX = -toO
        const n = p === "fast" ? duetBeats >> 1 : duetBeats
        switch (duetMove) {
        case "mirror":
            if (n % 2) { me.armUp(toO, strength); o.armUp(-toO, strength) }
            else { me.armUp(-toO, strength); o.armUp(toO, strength) }
            me.bob(); o.bob()
            break
        case "call":
            if (n % 2) { me.punch(toO); o.squat() }
            else { o.punch(-toO); me.squat() }
            break
        case "bump":
            if (n % 2) { me.sway(toO); o.sway(-toO); me.jolt(); o.jolt(); if (n % 4 === 1) { me.towards = toO; me.pop("star") } }
            else { me.danceRest(); o.danceRest(); me.bob(); o.bob() }
            break
        case "twirl":
            me.armUp(toO, 0.8)
            if (n % 4 === 0) o.spin(-toO); else o.bob()
            break
        case "swap":
            // every fourth beat one jumps over the other, taking turns
            if (n % 4 === 0 && !me.moving && !o.moving) {
                const jumper = (n >> 2) % 2 ? o : me, stay = jumper === me ? o : me
                const dir = stay.x0 > jumper.x0 ? 1 : -1
                jumper.armUp(0, 1)
                jumper.hop(stay.x0 + dir * (stay.x0 - jumper.x0) * dir, 46)
                stay.squat()
            } else { me.bob(); o.bob() }
            break
        default:
            if (n % 4 === 0) { me.highFive(toO); o.highFive(-toO, true) }
            else { me.bob(); o.bob() }
        }
    }

    // a move for eight beats. The tempo decides which moves fit (fast music:
    // nods, claps, hands; slow: swaying and twisting; in between all of it),
    // what he likes weighs them. Figures next to each other mirror each other.
    property real lastBeatAt: 0
    property string move: "hop"
    property string pace: ""
    property bool wasDocked: false
    readonly property var paceMoves: ({
        fast: { bang: 3, clap: 2, arms: 2, bounce: 2, robot: 1, box: 3, jump: 2, squat: 2, spin: 1 },
        mid:  { hop: 3, step: 3, arms: 2, clap: 2, spin: 2, robot: 1, twist: 2, sway: 1, bounce: 1, box: 2, jump: 2, squat: 1, slide: 2 },
        slow: { sway: 4, twist: 3, arms: 2, step: 1, bounce: 1, robot: 1, slide: 3, squat: 2, spin: 1 }
    })
    // in the frame: hands out of the dome and the face
    readonly property var dockMoves: ({
        fast: { bob: 2, box: 4, up: 3, clap: 2, peek: 2, tilt: 2, spin: 1 },
        mid:  { up: 3, wave: 3, clap: 2, box: 3, peek: 2, spin: 2, tilt: 2 },
        slow: { wave: 4, tilt: 3, up: 2, peek: 2, clap: 1, spin: 1 }
    })
    function danceStep(strength) {
        const now = Date.now(), gap = now - lastBeatAt
        lastBeatAt = now
        const bpm = world.bpm > 0 ? world.bpm : gap > 0 && gap < 2000 ? 60000 / gap : 110
        const p = bpm >= 150 ? "fast" : bpm < 100 ? "slow" : "mid"
        const docked = st.place === "dock"
        // a new move every eight beats (four when it is fast, so there is more to see)
        if (beats % (p === "fast" ? 4 : 8) === 1 || gap > 2000 || p !== pace || docked !== wasDocked) {
            pace = p
            wasDocked = docked
            const set = docked ? dockMoves[p] : paceMoves[p]
            const w = {}
            for (const k in set) w[k] = set[k] * (docked || st.danceStyle[k] === undefined ? 1 : st.danceStyle[k])
            let m = pick(w)
            // not the same move twice in a row
            if (m === move) m = pick(w)
            move = m
        }
        if (docked) { st.dockMove(move, strength, (beats % 2 ? 1 : -1) * (st.slot % 2 ? -1 : 1), beats); return }
        if (move !== "sway" && move !== "twist" && st.lean !== 0) st.danceRest()
        const side = (beats % 2 ? 1 : -1) * (st.slot % 2 ? -1 : 1)
        // too fast to leave the ground in time: big moves on every other beat
        if (p === "fast" && ["hop", "step", "spin", "twist", "sway", "jump", "slide", "squat"].indexOf(move) >= 0 && beats % 2) { st.bob(); return }
        switch (move) {
        case "box": st.punch(side); break
        case "jump": if (beats % 4 === 0 || p !== "fast") st.bigJump(strength); else st.bob(); break
        case "squat": st.squat(); break
        case "slide": st.slide(side); break
        case "clap": st.clap(); st.bob(); break
        case "twist": st.twist(side); break
        case "step": st.stepSide(side); break
        case "bang": st.bang(); if (beats % 4 === 0) st.armUp(0, strength); break
        case "bounce": st.bounce(strength, side); break
        case "arms": st.armUp(strength > 0.75 ? 0 : side, strength); st.bob(); break
        case "sway": st.sway(side); if (strength > 0.6) st.armUp(0, strength * 0.6); break
        case "robot": st.robotStep(side); st.bob(); break
        case "spin":
            if (beats % 4 === 0 && strength > 0.3) st.spin(side)
            else st.beatStep(strength * 0.6, side)
            break
        default: st.beatStep(strength, side)
        }
    }

    // ── the machine: a crash or a failed service makes him angry ──
    // The main character says what broke, like a notification; the others
    // and he himself, wherever he is, just frown for a while.
    Connections {
        target: brain.world
        function onTrouble(kind, name) { brain.grumble(kind, name) }
    }
    function grumble(kind, name) {
        if (!world.moods || doing === "sleep" || st.sleeping || world.dnd) return
        if (main && world.notifications && !world.chatOpen && st.place !== "chat"
                && ["idle", "dock", "walk", "toDock"].indexOf(doing) >= 0) {
            toStage("", say(kind).replace("%1", name), "angry", 5500, false)
            return
        }
        // a second crash soon after: angrier
        st.feel("angry")
        angryBack.restart()
    }
    Timer {
        id: angryBack; interval: 5000
        onTriggered: if (!brain.st.calm("angry")) restart()
    }
    // ── the chat window: he jumps into it and out again ───────────
    function openChat() {
        if (!world.chat) { toStage("", say("nochat"), "happy", 3000, false); return }
        // open, and he is in it: just the keyboard
        if (world.chatOpen && st.place === "chat") { wantFocus(); return }
        if (doing === "play") stopPlay()
        lookAnim.stop()
        stageTimer.stop()
        bubbleShown = false
        bubbleChat = false
        if (st.sleeping) { st.sleeping = false; tucked = false }
        doing = "chat"
        world.chatOpen = true
        chatOpened()
        if (st.place === "dock") st.undock("chat")
        else if (st.place === "chat") world.chatJumpIn(st)
        else chatWait.start()
    }
    Timer { id: chatWait; interval: 50; repeat: true; onTriggered: if (!brain.st.moving) { stop(); if (brain.doing === "chat") brain.st.dive("chat") } }
    function closeChat() {
        if (!world.chatOpen) return
        world.chatOpen = false
        st.thinking = false
        chatWait.stop()
        doing = "back"
        if (st.place === "chat") world.chatJumpOut(st)
        else if (!st.moving) { doing = "idle"; st.mood = "neutral" }
    }
    Connections {
        target: brain.world
        function onChatSeated(who) {
            if (who !== brain.st) return
            brain.st.mood = "happy"
            brain.st.wave()
            brain.wantFocus()
        }
        function onChatLeft(who) {
            if (who !== brain.st) return
            // out of the window that stays open: he landed in front of the windows
            if (brain.world.chatAway) {
                brain.st.place = "stage"
                brain.st.y0 = brain.world.floorY
                brain.st.restX = brain.st.x0
                brain.doing = "idle"
                if (brain.pendingAction) { const f = brain.pendingAction; brain.pendingAction = null; f() }
                return
            }
            brain.doing = "back"
            brain.st.dive(brain.pinned ? "stage" : "home")
        }
    }
    // answers live in the chat window; he only shows how he feels
    function reply(text, mood, level) {
        st.thinking = false
        if (level) st.feel(mood, level)
        else st.mood = mood
        if (mood === "happy" || mood === "proud") st.cheer()
    }
    function failed() {
        st.thinking = false
        st.mood = "sad"
    }
}
