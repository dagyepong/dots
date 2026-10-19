.pragma library
.import "../../sekai/launcher/Calc.js" as Calc

// The launcher extras' decisions, as plain JavaScript (no QML, no Quickshell)
// so they can be tried on their own. Three jobs:
//
//   route(text)         what does the search box's text ask for?
//   parseColor / ...    colour parsing and formats for the colour card
//   matchActions(text)  system actions ("lock", "dark mode", ...) to list
//
// ExtrasSource.qml is the system side that runs things; the cards are pure UI.

// The name `qs -c <this>` runs under -- used when an action calls back into
// the shell over IPC (lock, quick panel, wallpapers). Change it if you
// installed the config under another folder name.
var qsConfig = "sekaipop";

// ===== what the box is asking for =====
var LONG = {
    calc: "calc", calculator: "calc", calculate: "calc",
    clip: "clip", clipboard: "clip", clipboardhistory: "clip",
    color: "color", colour: "color", colors: "color", colours: "color",
    emoji: "emoji", emojis: "emoji", emoticon: "emoji", emoticons: "emoji",
    web: "web", search: "web", google: "web:google", duckduckgo: "web:ddg",
    youtube: "web:youtube", github: "web:github", wikipedia: "web:wiki"
};
var SHORT = {
    cb: "clip", cliphist: "clip", col: "color", emo: "emoji",
    g: "web:google", ddg: "web:ddg", duck: "web:ddg", yt: "web:youtube",
    gh: "web:github", wiki: "web:wiki", arch: "web:arch", aw: "web:arch"
};

// [id, name, address bar host, search URL ("%s" = the encoded query), home page]
var ENGINES = [
    { id: "ddg",     name: "DuckDuckGo", host: "duckduckgo.com",      url: "https://duckduckgo.com/?q=%s",                    home: "https://duckduckgo.com" },
    { id: "google",  name: "Google",     host: "google.com",          url: "https://www.google.com/search?q=%s",              home: "https://www.google.com" },
    { id: "youtube", name: "YouTube",    host: "youtube.com",         url: "https://www.youtube.com/results?search_query=%s", home: "https://www.youtube.com" },
    { id: "github",  name: "GitHub",     host: "github.com",          url: "https://github.com/search?q=%s",                  home: "https://github.com" },
    { id: "wiki",    name: "Wikipedia",  host: "wikipedia.org",       url: "https://en.wikipedia.org/w/index.php?search=%s",  home: "https://en.wikipedia.org" },
    { id: "arch",    name: "ArchWiki",   host: "wiki.archlinux.org",  url: "https://wiki.archlinux.org/index.php?search=%s",  home: "https://wiki.archlinux.org" }
];

function engineIndex(id) {
    for (var i = 0; i < ENGINES.length; i++)
        if (ENGINES[i].id === id) return i;
    return 0;
}

function searchUrl(engine, query) {
    return ENGINES[engine].url.replace("%s", encodeURIComponent(query));
}

// Something the address bar would just open rather than search for.
function looksLikeUrl(q) {
    var s = q.trim();
    if (/\s/.test(s) || s.length < 3) return false;
    if (/^[a-z][a-z0-9+.-]*:\/\/\S+$/i.test(s)) return true;
    return /^(www\.)?[a-z0-9-]+(\.[a-z0-9-]+)*\.(com|org|net|io|dev|app|co|me|gg|tv|xyz|edu|gov|uk|de|jp|fr|ph|ai|sh|so|cc|info|wiki)(:\d+)?(\/\S*)?$/i.test(s);
}

function urlFor(q) {
    var s = q.trim();
    return /^[a-z][a-z0-9+.-]*:\/\//i.test(s) ? s : "https://" + s;
}

// Result: { mode, arg, prefix, engine, terminal }
//   mode    "" | "calc" | "clip" | "color" | "emoji" | "web" | "shell"
//   arg     the part after the trigger (the expression / filter / query)
//   prefix  the text before arg, so the keypad can rebuild "calc 12+3"
function route(text) {
    var raw = String(text);
    var t = raw.replace(/^\s+/, "");
    var none = { mode: "", arg: "", prefix: "", engine: 0, terminal: false };
    if (t === "") return none;

    // symbol prefixes
    var c = t.charAt(0);
    if (c === ">" || c === "$") {
        var terminal = c === "$" || t.charAt(1) === ">";
        var body = t.replace(/^(>>|>|\$)\s*/, "");
        return { mode: "shell", arg: body, prefix: t.slice(0, t.length - body.length), engine: 0, terminal: terminal };
    }
    if (c === "?" ) return sym(t, "web");
    if (c === ":" && !/^:\s*$/.test(t) || t === ":") return sym(t, "emoji");
    if (c === "=") return sym(t, "calc");

    // word triggers
    var m = /^(\S+)(\s+)?([\s\S]*)$/.exec(t);
    var word = m[1].toLowerCase();
    var hasSpace = m[2] !== undefined;
    var rest = m[3];
    var hit = LONG[word] || (hasSpace ? SHORT[word] : undefined);
    if (hit) {
        var parts = hit.split(":");
        var prefix = hasSpace ? t.slice(0, t.length - rest.length) : m[1] + " ";
        return { mode: parts[0], arg: rest, prefix: prefix, engine: parts.length > 1 ? engineIndex(parts[1]) : 0, terminal: false };
    }

    // things that are plainly a sum or a colour
    if (Calc.looksLikeMath(t)) return { mode: "calc", arg: t, prefix: "", engine: 0, terminal: false };
    if (parseColor(t, false)) return { mode: "color", arg: t, prefix: "", engine: 0, terminal: false };
    return none;

    function sym(s, mode) {
        var body = s.slice(1).replace(/^\s+/, "");
        return { mode: mode, arg: body, prefix: s.slice(0, s.length - body.length), engine: 0, terminal: false };
    }
}

// ===== colour =====
var NAMES = {
    black: "#000000", white: "#ffffff", red: "#ff0000", green: "#008000", blue: "#0000ff",
    yellow: "#ffff00", cyan: "#00ffff", magenta: "#ff00ff", orange: "#ffa500", purple: "#800080",
    pink: "#ffc0cb", hotpink: "#ff69b4", brown: "#a52a2a", gray: "#808080", grey: "#808080",
    silver: "#c0c0c0", gold: "#ffd700", navy: "#000080", teal: "#008080", lime: "#00ff00",
    maroon: "#800000", olive: "#808000", aqua: "#00ffff", coral: "#ff7f50", salmon: "#fa8072",
    crimson: "#dc143c", indigo: "#4b0082", violet: "#ee82ee", turquoise: "#40e0d0", tomato: "#ff6347",
    skyblue: "#87ceeb", lavender: "#e6e6fa", mint: "#00ffcb", beige: "#f5f5dc", khaki: "#f0e68c",
    orchid: "#da70d6", plum: "#dda0dd", chocolate: "#d2691e", tan: "#d2b48c", ivory: "#fffff0",
    transparent: "#00000000"
};

function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }

function num(s) {              // "50%" -> 127.5 of 255, "12" -> 12
    s = String(s).trim();
    return s.charAt(s.length - 1) === "%" ? parseFloat(s) * 2.55 : parseFloat(s);
}

// -> { r, g, b (0..255), a (0..1) } or null. `loose` also accepts a bare
// "ff8800" (colour card only -- as a launcher query it would eat words like
// "bad" or "add").
function parseColor(input, loose) {
    var s = String(input).trim().toLowerCase();
    if (s === "") return null;
    if (NAMES.hasOwnProperty(s) && loose) s = NAMES[s];

    var m = /^#?([0-9a-f]{3,8})$/.exec(s);
    if (m && (s.charAt(0) === "#" || loose) && [3, 4, 6, 8].indexOf(m[1].length) >= 0) {
        var h = m[1];
        if (h.length <= 4)
            h = h.split("").map(function (d) { return d + d; }).join("");
        return {
            r: parseInt(h.substr(0, 2), 16), g: parseInt(h.substr(2, 2), 16),
            b: parseInt(h.substr(4, 2), 16), a: h.length === 8 ? parseInt(h.substr(6, 2), 16) / 255 : 1
        };
    }

    m = /^(rgba?|hsla?)\(\s*([^)]*)\)?$/.exec(s);
    if (m) {
        var p = m[2].split(/[\s,\/]+/).filter(function (x) { return x !== ""; });
        if (p.length < 3) return null;
        var a = p.length > 3 ? (String(p[3]).indexOf("%") >= 0 ? parseFloat(p[3]) / 100 : parseFloat(p[3])) : 1;
        if (isNaN(a)) return null;
        if (m[1].charAt(0) === "r") {
            var r = num(p[0]), g = num(p[1]), b = num(p[2]);
            if (isNaN(r) || isNaN(g) || isNaN(b)) return null;
            return { r: clamp(Math.round(r), 0, 255), g: clamp(Math.round(g), 0, 255), b: clamp(Math.round(b), 0, 255), a: clamp(a, 0, 1) };
        }
        var hh = parseFloat(p[0]), ss = parseFloat(p[1]), ll = parseFloat(p[2]);
        if (isNaN(hh) || isNaN(ss) || isNaN(ll)) return null;
        var rgb = hslToRgb(hh, clamp(ss, 0, 100) / 100, clamp(ll, 0, 100) / 100);
        rgb.a = clamp(a, 0, 1);
        return rgb;
    }
    return null;
}

function hslToRgb(h, s, l) {
    h = ((h % 360) + 360) % 360 / 360;
    function f(n) {
        var k = (n + h * 12) % 12;
        var a = s * Math.min(l, 1 - l);
        return l - a * Math.max(-1, Math.min(k - 3, 9 - k, 1));
    }
    return { r: Math.round(f(0) * 255), g: Math.round(f(8) * 255), b: Math.round(f(4) * 255), a: 1 };
}

function rgbToHsl(c) {
    var r = c.r / 255, g = c.g / 255, b = c.b / 255;
    var mx = Math.max(r, g, b), mn = Math.min(r, g, b);
    var l = (mx + mn) / 2, h = 0, s = 0;
    if (mx !== mn) {
        var d = mx - mn;
        s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn);
        if (mx === r) h = (g - b) / d + (g < b ? 6 : 0);
        else if (mx === g) h = (b - r) / d + 2;
        else h = (r - g) / d + 4;
        h *= 60;
    }
    return { h: Math.round(h), s: Math.round(s * 100), l: Math.round(l * 100) };
}

function hex2(n) { var s = clamp(Math.round(n), 0, 255).toString(16); return s.length < 2 ? "0" + s : s; }

function toHex(c) {
    return "#" + hex2(c.r) + hex2(c.g) + hex2(c.b) + (c.a < 1 ? hex2(c.a * 255) : "");
}

function toRgb(c) {
    var a = Math.round(c.a * 100) / 100;
    return c.a < 1 ? "rgba(" + c.r + ", " + c.g + ", " + c.b + ", " + a + ")" : "rgb(" + c.r + ", " + c.g + ", " + c.b + ")";
}

function toHslString(c) {
    var h = rgbToHsl(c);
    var a = Math.round(c.a * 100) / 100;
    return c.a < 1 ? "hsla(" + h.h + ", " + h.s + "%, " + h.l + "%, " + a + ")" : "hsl(" + h.h + ", " + h.s + "%, " + h.l + "%)";
}

// The same hue at a different lightness (0..100), for the shades strip.
function withLightness(c, l) {
    var h = rgbToHsl(c);
    var o = hslToRgb(h.h, h.s / 100, l / 100);
    o.a = c.a;
    return o;
}

// Black or white, whichever reads on this colour.
function inkFor(c) {
    return (0.299 * c.r + 0.587 * c.g + 0.114 * c.b) > 150 ? "#555473" : "#ffffff";
}

// ===== actions =====
var ACTIONS = [
    { id: "lock",      title: "Lock screen",          sub: "Lock with the shell's lockscreen",  glyph: "lock",               keys: "lock screen security",             ipc: ["lock", "lock"] },
    { id: "sleep",     title: "Sleep",                sub: "Suspend to RAM",                    glyph: "bedtime",            keys: "suspend sleep",                    argv: ["systemctl", "suspend"] },
    { id: "hibernate", title: "Hibernate",            sub: "Suspend to disk",                   glyph: "downloading",        keys: "hibernate",                        argv: ["systemctl", "hibernate"], confirm: true },
    { id: "reboot",    title: "Restart",              sub: "Reboot the computer",               glyph: "restart_alt",        keys: "reboot restart",                   argv: ["systemctl", "reboot"], confirm: true },
    { id: "poweroff",  title: "Shut down",            sub: "Power the computer off",            glyph: "power_settings_new", keys: "poweroff power off shutdown",      argv: ["systemctl", "poweroff"], confirm: true },
    { id: "logout",    title: "Log out",              sub: "End the Hyprland session",          glyph: "logout",             keys: "logout log out sign out exit",     argv: ["sh", "-c", "hyprctl dispatch 'hl.dsp.exit()' >/dev/null 2>&1; sleep 1; hyprctl dispatch exit >/dev/null 2>&1; sleep 1; if [ -n \"$XDG_SESSION_ID\" ]; then loginctl terminate-session \"$XDG_SESSION_ID\"; else loginctl terminate-user \"$USER\"; fi"], confirm: true },
    { id: "firmware",  title: "Reboot to firmware",   sub: "Restart into BIOS / UEFI setup",    glyph: "memory",             keys: "bios uefi firmware setup",         argv: ["systemctl", "reboot", "--firmware-setup"], confirm: true },
    { id: "panel",     title: "Quick Panel",          sub: "Open or close the phone panel",     glyph: "smartphone",         keys: "phone panel notifications quick",  ipc: ["quickpanel", "toggle"] },
    { id: "wallpaper", title: "Wallpapers",           sub: "Open the wallpaper board",          glyph: "photo_library",      keys: "wallpaper background picker",      ipc: ["wallpaperpicker", "toggle"] },
    { id: "shot",      title: "Screenshot region",    sub: "Select an area; saved and copied",  glyph: "screenshot_region",  keys: "screenshot screen capture snip grim", delay: 0.5,
      argv: ["bash", "-c", "d=\"$HOME/Pictures/Screenshots\"; mkdir -p \"$d\"; f=\"$d/$(date +%Y-%m-%d_%H-%M-%S).png\"; g=$(slurp) || exit 0; grim -g \"$g\" \"$f\" && wl-copy < \"$f\" && notify-send -a sekaipop -i material:photo_camera 'Screenshot saved' \"$f\""] },
    { id: "pickcolor", title: "Pick a colour",        sub: "Eyedropper anywhere on screen",     glyph: "colorize",           keys: "color colour picker eyedropper hyprpicker", special: "colorpick" },
    { id: "mutespk",   title: "Mute / unmute speakers", sub: "Toggle the default output",       glyph: "volume_off",         keys: "mute speaker volume sound audio",  argv: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"] },
    { id: "mutemic",   title: "Mute / unmute microphone", sub: "Toggle the default input",      glyph: "mic_off",            keys: "mute microphone mic input",        argv: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"] },
    { id: "theme",     title: "Dark / light mode",    sub: "Flip the system colour scheme",     glyph: "contrast",           keys: "dark light theme mode appearance", 
      argv: ["sh", "-c", "case \"$(gsettings get org.gnome.desktop.interface color-scheme)\" in *dark*) gsettings set org.gnome.desktop.interface color-scheme prefer-light;; *) gsettings set org.gnome.desktop.interface color-scheme prefer-dark;; esac"] },
    { id: "wifi",      title: "Wi-Fi on / off",       sub: "Toggle the Wi-Fi radio",            glyph: "wifi",               keys: "wifi wi-fi wireless network internet",
      argv: ["sh", "-c", "if nmcli radio wifi | grep -q enabled; then nmcli radio wifi off; else nmcli radio wifi on; fi"] },
    { id: "bluetooth", title: "Bluetooth on / off",   sub: "Toggle the Bluetooth adapter",      glyph: "bluetooth",          keys: "bluetooth bt",
      argv: ["sh", "-c", "if bluetoothctl show | grep -q 'Powered: yes'; then bluetoothctl power off; else bluetoothctl power on; fi"] },
    { id: "clipwipe",  title: "Clear clipboard history", sub: "Delete everything cliphist saved", glyph: "delete_sweep",      keys: "clipboard clear wipe history cliphist", argv: ["cliphist", "wipe"], confirm: true }
];

// Actions matching the box, best first. Needs two letters so a lone "l"
// does not list Lock above your apps.
function matchActions(text) {
    var q = String(text).trim().toLowerCase();
    if (q.length < 2) return [];
    var out = [];
    for (var i = 0; i < ACTIONS.length; i++) {
        var a = ACTIONS[i];
        var title = a.title.toLowerCase();
        var score = 0;
        if (title === q) score = 100;
        else if (title.indexOf(q) === 0) score = 80;
        else if ((" " + a.keys).indexOf(" " + q) >= 0) score = 60;
        else if (title.indexOf(q) >= 0) score = 50;
        else if (a.keys.indexOf(q) >= 0) score = 30;
        if (score > 0) out.push({ score: score, action: a });
    }
    out.sort(function (x, y) { return y.score - x.score; });
    return out.map(function (o) { return { score: o.score, action: o.action }; });
}

// ===== running shell commands =====
function backgroundArgv(cmd) {
    return ["sh", "-c",
        "out=$(eval \"$1\" 2>&1); rc=$?; "
        + "if [ -n \"$out\" ] || [ \"$rc\" -ne 0 ]; then "
        + "notify-send -a sekaipop -i material:terminal \"$1 (exit $rc)\" \"$(printf %s \"$out\" | head -c 600)\"; fi",
        "sh", cmd];
}

function terminalArgv(cmd) {
    return ["sh", "-c",
        "t=\"${TERMINAL:-}\"; if [ -z \"$t\" ]; then for c in kitty foot alacritty wezterm ghostty konsole gnome-terminal xterm; do "
        + "command -v \"$c\" >/dev/null 2>&1 && t=$c && break; done; fi; "
        + "run='eval \"$1\"; printf \"\\n[exit %s] press Enter to close \" \"$?\"; read _'; "
        + "case \"$t\" in "
        + "kitty|foot) exec \"$t\" sh -c \"$run\" sh \"$1\";; "
        + "wezterm) exec wezterm start -- sh -c \"$run\" sh \"$1\";; "
        + "gnome-terminal) exec gnome-terminal -- sh -c \"$run\" sh \"$1\";; "
        + "\"\") notify-send -a sekaipop -i material:terminal 'No terminal found' 'Set $TERMINAL or install kitty / foot / alacritty'; exit 1;; "
        + "*) exec \"$t\" -e sh -c \"$run\" sh \"$1\";; esac",
        "sh", cmd];
}

// ===== small shared helpers =====
function oneLine(s, max) {
    var t = String(s).replace(/\s+/g, " ").trim();
    return t.length > max ? t.slice(0, max - 1) + "\u2026" : t;
}

// Parse `cliphist list` output ("<id>\t<preview>" per line).
function parseClipList(text) {
    var out = [];
    var lines = String(text).split("\n");
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i];
        var tab = line.indexOf("\t");
        if (tab <= 0) continue;
        var id = line.slice(0, tab);
        if (!/^\d+$/.test(id)) continue;
        var preview = line.slice(tab + 1);
        var isImage = /^\[\[\s*binary data/.test(preview);
        out.push({ id: id, preview: preview, image: isImage, line: line });
    }
    return out;
}

// The row / info text of a copied picture: cliphist's own description of it
// ("[[ binary data 1.2 MiB png 1920x1080 ]]" -> "Image \u00b7 1.2 MiB png 1920x1080").
function imageLabel(preview) {
    var d = String(preview).replace(/^\[\[\s*binary data\s*/, "").replace(/\s*\]\]$/, "").trim();
    return d === "" ? "Image" : "Image \u00b7 " + d;
}
