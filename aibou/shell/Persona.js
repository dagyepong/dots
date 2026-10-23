.pragma library

// Who each figure is: what it likes, how it moves, what it says. Brain reads
// the traits (1 = like Kuro), Brain.voice() the lines; a missing line falls
// back to the shared one.
//
//   step     how far a walking hop goes        hopH     how high it hops
//   restless how soon boredom makes it move (lower = sooner)
//   social   meeting and teasing the others    playful  games and the ball
//   sleepy   how soon it gets tired (lower = sooner)
//   pointer  how keen it is on the pointer (range of the lunge, cool-down)
//   climb, grapple, snack   weights when bored     hobby  its own pastime
//   napTop   naps up in the top frame instead of on the floor
var traits = {
    kuro:   { step: 1.0, hopH: 1.0,  restless: 1.0, social: 1.0, playful: 1.0, sleepy: 1.0, pointer: 1.0, climb: 5,  grapple: 10, snack: 1.5, hobby: "polish", napTop: false },
    shiro:  { step: 1.0, hopH: 1.1,  restless: 0.9, social: 1.3, playful: 1.2, sleepy: 1.4, pointer: 0.8, climb: 12, grapple: 3,  snack: 1.5, hobby: "juggle", napTop: false },
    mochi:  { step: 0.85, hopH: 0.8, restless: 1.4, social: 1.1, playful: 0.8, sleepy: 0.6, pointer: 0.6, climb: 2,  grapple: 1,  snack: 4,   hobby: "",       napTop: true },
    momo:   { step: 0.95, hopH: 0.9, restless: 1.2, social: 1.2, playful: 0.9, sleepy: 1.0, pointer: 0.8, climb: 9,  grapple: 3,  snack: 2,   hobby: "yoga",   napTop: false },
    robo:   { step: 1.1, hopH: 0.7,  restless: 0.9, social: 0.8, playful: 1.0, sleepy: 1.6, pointer: 1.0, climb: 3,  grapple: 5,  snack: 2,   hobby: "",       napTop: false },
    bao:    { step: 0.8, hopH: 0.75, restless: 1.5, social: 1.2, playful: 0.7, sleepy: 0.5, pointer: 0.5, climb: 0,  grapple: 0.5, snack: 9,  hobby: "",       napTop: false },
    // the cat: restless, keen on the pointer above all, climbs well, naps often
    neko:   { step: 1.1, hopH: 1.2,  restless: 0.7, social: 0.7, playful: 1.4, sleepy: 0.7, pointer: 1.8, climb: 10, grapple: 3,  snack: 3,   hobby: "polish", napTop: false },
    // the cloud: calm and dreamy, drifts slowly, naps up in the sky
    kumo:   { step: 1.0, hopH: 1.0,  restless: 1.7, social: 1.0, playful: 0.6, sleepy: 0.8, pointer: 0.4, climb: 6,  grapple: 0,  snack: 1,   hobby: "yoga",   napTop: true },
    // the octopus: the best climber, handy, juggles with all its arms
    tako:   { step: 0.9, hopH: 0.8,  restless: 0.9, social: 1.0, playful: 1.1, sleepy: 1.2, pointer: 1.0, climb: 14, grapple: 4,  snack: 2,   hobby: "juggle", napTop: false },
    // the chick: lots of tiny quick hops, excitable, loves to peck seeds
    hiyoko: { step: 0.55, hopH: 0.65, restless: 0.6, social: 1.4, playful: 1.3, sleepy: 0.9, pointer: 1.2, climb: 3, grapple: 1,  snack: 6,   hobby: "",       napTop: false },
    // the raccoon: clever and curious, tidies up, likes the grappling gun
    arai:   { step: 1.0, hopH: 0.9,  restless: 0.8, social: 0.9, playful: 1.1, sleepy: 1.3, pointer: 1.1, climb: 9,  grapple: 6,  snack: 5,   hobby: "polish", napTop: false }
}

function trait(skin, key) {
    const t = traits[skin] || traits.kuro
    return t[key] !== undefined ? t[key] : traits.kuro[key]
}

// lines by figure: hi (greeting a newcomer, %1 the name), happy (a jump
// for joy), scared, gotIt (caught the pointer), snack, tickle, slip (on the
// peel), yawn, idle (to itself now and then), tidy (Arai's peel)
var lines = {
    de: {
        kuro:   { hi: ["Yo, %1!", "Hallo %1!"], happy: ["Yatta!"], gotIt: ["Hab dich!"], idle: ["Hmm~", "Alles im Blick."] },
        shiro:  { hi: ["Hallo %1~!", "Kyaa, %1!"], happy: ["Wiii~!", "Yay~"], scared: ["Kyaa!"], tickle: ["Kihihi~"], idle: ["La la la~", "Hübsch hier~"] },
        mochi:  { hi: ["Mochi mochi, %1!"], happy: ["Mochi!"], snack: ["Dango!", "Mampf!"], yawn: ["*gääähn* … Nickerchen?"], idle: ["Weich und rund~", "Ehehe~"] },
        momo:   { hi: ["Hallöchen, %1!"], happy: ["Hihi~"], idle: ["So ein schöner Tag~", "Pfirsichsüß~"] },
        robo:   { hi: ["Hallo, Einheit %1.", "Neuer Kontakt: %1."], happy: ["Freude: 100 %!"], scared: ["Fehler 404!", "Alarm!"], gotIt: ["Ziel erfasst."], snack: ["Gluck gluck!"], tickle: ["Hihi … Sensoren überlastet!"], idle: ["Piep. Boop.", "Systeme normal."] },
        bao:    { hi: ["Hallo %1! Schon gegessen?"], happy: ["Lecker Tag!"], snack: ["Mampf!", "Mmh, Brötchen!"], yawn: ["*gähn* … nach dem Essen müde."], idle: ["Pause machen nicht vergessen~", "Hunger …"] },
        neko:   { hi: ["Miau, %1!", "Nya~ %1!"], happy: ["Nya~!"], scared: ["Fauch!", "Mrrau!"], gotIt: ["Erwischt! Nya!"], snack: ["Fisch!", "Mjam, Fisch!"], tickle: ["*schnurr*", "Prrr~"], slip: ["Miaaau!"], yawn: ["*gähn* … Katzenschläfchen."], idle: ["*putz*", "Nya?", "*schnurr*"] },
        kumo:   { hi: ["Hallo %1~", "Schwebe-Hallo, %1!"], happy: ["Fluff~!"], scared: ["Huch!"], tickle: ["Hihi, das pustet!"], yawn: ["*gähn* … ab in den Himmel."], idle: ["Schwebe, schwebe~", "Fluff~", "Ganz leicht heute."] },
        tako:   { hi: ["Blub, %1!", "Acht Arme Hallo, %1!"], happy: ["Blub blub!"], scared: ["*Tinte!*", "Blub?!"], gotIt: ["Festgesaugt!"], tickle: ["Hihi, alle Arme kitzeln!"], idle: ["Blub.", "Acht Arme, null Sorgen."] },
        hiyoko: { hi: ["Piep, %1!", "Piep piep, Hallo %1!"], happy: ["Piep piep!"], scared: ["Piiieep!"], gotIt: ["Piep! Hab dich!"], snack: ["Pick pick!", "Körner!"], tickle: ["Piepiepiep!"], slip: ["Piiiep!"], idle: ["Piep?", "Piep!"] },
        arai:   { hi: ["Hehehe, hallo %1!", "Na, %1?"], happy: ["Hehehe!"], scared: ["Iiik!"], gotIt: ["Geschnappt!"], snack: ["Gefunden und gefuttert!"], tickle: ["Hehe, nicht da!"], tidy: ["Aufgeräumt!", "Wieder sauber."], idle: ["Was liegt denn da?", "*schnüffel*"] }
    },
    en: {
        kuro:   { hi: ["Yo, %1!", "Hi %1!"], happy: ["Yatta!"], gotIt: ["Got you!"], idle: ["Hmm~", "All in view."] },
        shiro:  { hi: ["Hi %1~!", "Kyaa, %1!"], happy: ["Wheee~!", "Yay~"], scared: ["Kyaa!"], tickle: ["Kihihi~"], idle: ["La la la~", "Pretty here~"] },
        mochi:  { hi: ["Mochi mochi, %1!"], happy: ["Mochi!"], snack: ["Dango!", "Nom!"], yawn: ["*yaaawn* … nap time?"], idle: ["Soft and round~", "Ehehe~"] },
        momo:   { hi: ["Hello there, %1!"], happy: ["Hehe~"], idle: ["What a lovely day~", "Peachy~"] },
        robo:   { hi: ["Hello, unit %1.", "New contact: %1."], happy: ["Joy: 100 %!"], scared: ["Error 404!", "Alert!"], gotIt: ["Target acquired."], snack: ["Glug glug!"], tickle: ["Hehe … sensors overloaded!"], idle: ["Beep. Boop.", "All systems normal."] },
        bao:    { hi: ["Hi %1! Have you eaten?"], happy: ["Yummy day!"], snack: ["Nom!", "Mmm, buns!"], yawn: ["*yawn* … sleepy after food."], idle: ["Don't forget your break~", "Hungry …"] },
        neko:   { hi: ["Meow, %1!", "Nya~ %1!"], happy: ["Nya~!"], scared: ["Hiss!", "Mrrow!"], gotIt: ["Caught it! Nya!"], snack: ["Fish!", "Yum, fish!"], tickle: ["*purr*", "Prrr~"], slip: ["Meeeow!"], yawn: ["*yawn* … cat nap."], idle: ["*groom*", "Nya?", "*purr*"] },
        kumo:   { hi: ["Hi %1~", "A floaty hello, %1!"], happy: ["Fluff~!"], scared: ["Oh!"], tickle: ["Hehe, that tickles my fluff!"], yawn: ["*yawn* … up to the sky."], idle: ["Float, float~", "Fluff~", "Feeling light today."] },
        tako:   { hi: ["Blub, %1!", "An eight-armed hello, %1!"], happy: ["Blub blub!"], scared: ["*Ink!*", "Blub?!"], gotIt: ["Suckered on!"], tickle: ["Hehe, all my arms tickle!"], idle: ["Blub.", "Eight arms, zero worries."] },
        hiyoko: { hi: ["Cheep, %1!", "Cheep cheep, hi %1!"], happy: ["Cheep cheep!"], scared: ["Cheeeep!"], gotIt: ["Cheep! Got you!"], snack: ["Peck peck!", "Seeds!"], tickle: ["Cheepeepeep!"], slip: ["Cheeep!"], idle: ["Cheep?", "Cheep!"] },
        arai:   { hi: ["Hehehe, hi %1!", "Well, %1?"], happy: ["Hehehe!"], scared: ["Eek!"], gotIt: ["Snatched!"], snack: ["Found it, ate it!"], tickle: ["Hehe, not there!"], tidy: ["All tidy!", "Clean again."], idle: ["What's lying there?", "*sniff*"] }
    },
    ja: {
        kuro:   { hi: ["よっ、%1!", "やっほー、%1!"], happy: ["やった!"], gotIt: ["つかまえた!"], idle: ["ふむ~", "ぜんぶ見えてるよ。"] },
        shiro:  { hi: ["%1、こんにちは~!", "きゃー、%1!"], happy: ["わーい~!", "やったぁ~"], scared: ["きゃっ!"], tickle: ["きゃははっ~"], idle: ["ららら~", "いい感じ~"] },
        mochi:  { hi: ["もちもち、%1!"], happy: ["もちっ!"], snack: ["おだんご!", "もぐもぐ!"], yawn: ["*ふあぁぁ* … おひるね?"], idle: ["やわらかまるまる~", "えへへ~"] },
        momo:   { hi: ["%1、こんにちは!"], happy: ["うふふ~"], idle: ["いいお天気~", "ももいろ気分~"] },
        robo:   { hi: ["コンニチハ、ユニット %1。", "新しい接続: %1。"], happy: ["ヨロコビ: 100 %!"], scared: ["エラー 404!", "警告!"], gotIt: ["目標捕捉。"], snack: ["ごくごく!"], tickle: ["ハハ … センサー過負荷!"], idle: ["ピッ。ポッ。", "システム正常。"] },
        bao:    { hi: ["%1、ごはん食べた?"], happy: ["おいしい一日!"], snack: ["もぐもぐ!", "んー、肉まん!"], yawn: ["*ふあぁ* … 食べたらねむい。"], idle: ["休憩わすれないでね~", "おなかすいた …"] },
        neko:   { hi: ["にゃー、%1!", "にゃ~ %1!"], happy: ["にゃ~!"], scared: ["シャーッ!", "ふにゃっ!"], gotIt: ["つかまえたにゃ!"], snack: ["おさかな!", "おさかな、おいしい!"], tickle: ["*ゴロゴロ*", "ごろにゃ~"], slip: ["にゃあぁ!"], yawn: ["*ふあぁ* … ねこのおひるね。"], idle: ["*ぺろぺろ*", "にゃ?", "*ゴロゴロ*"] },
        kumo:   { hi: ["%1、やっほ~", "ふわふわこんにちは、%1!"], happy: ["ふわっ~!"], scared: ["わっ!"], tickle: ["えへへ、ふわふわがくすぐったい!"], yawn: ["*ふあぁ* … お空でおやすみ。"], idle: ["ふわふわ~", "ふわっ~", "今日はからだが軽い。"] },
        tako:   { hi: ["ぶくっ、%1!", "八本の手でこんにちは、%1!"], happy: ["ぶくぶく!"], scared: ["*スミ!*", "ぶくっ?!"], gotIt: ["吸いついた!"], tickle: ["えへへ、ぜんぶの手がくすぐったい!"], idle: ["ぶくっ。", "手は八本、なやみはゼロ。"] },
        hiyoko: { hi: ["ピヨ、%1!", "ピヨピヨ、%1こんにちは!"], happy: ["ピヨピヨ!"], scared: ["ピヨーッ!"], gotIt: ["ピヨ! つかまえた!"], snack: ["つんつん!", "おこめ!"], tickle: ["ピヨピヨピヨッ!"], slip: ["ピヨォッ!"], idle: ["ピヨ?", "ピヨ!"] },
        arai:   { hi: ["へへへ、やっほー%1!", "おや、%1?"], happy: ["へへへ!"], scared: ["ひゃっ!"], gotIt: ["いただき!"], snack: ["みーつけた、いただきます!"], tickle: ["へへ、そこはだめ!"], tidy: ["おかたづけ完了!", "ピカピカになった。"], idle: ["なにか落ちてる?", "*くんくん*"] }
    }
}

// a line for this figure, or "" when it has none of that kind
function line(skin, lang, key, arg) {
    const byLang = lines[lang] || lines.en
    const l = (byLang[skin] || {})[key]
    if (!l || !l.length) return ""
    const s = l[Math.floor(Math.random() * l.length)]
    return arg !== undefined ? s.replace("%1", arg) : s
}
