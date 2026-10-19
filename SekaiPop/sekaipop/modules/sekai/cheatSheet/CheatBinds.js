.pragma library

// Pure logic for the keybind cheatsheet (no Quickshell imports).
// build(json) turns `hyprctl -j binds` into a list of notes:
//   { id, title, kind, icon, rows: [{ mods, mask, caps, label, dup, text }] }
// Top-level values use `var` on purpose: QML JS libraries don't reliably
// export top-level const/let.
//
// Binds are grouped like Illogical Impulse's cheatsheet:
//   Shell, Utilities, Windows, Workspaces, Session, Screen, Media, Apps
//
// Hyprland's Lua config reports every bind as "__lua", so the dispatcher says
// nothing about what a bind does. The group therefore comes from the bind's
// description, written "Group: sentence" (see hypr/hyprland/keybinds.lua):
//   "Windows: Close window"        -> Windows note, row "Close window"
//   "Windows (more): Close window" -> same, but only shown after "+N more"
// Rows with the same group, modifiers, sentence and kind of key fold into one
// (← ↑ → ↓ in one keycap, 1..0 as "#", PgUp / PgDn as "PgUp/Dn").
// Binds without a "Group:" prefix still go through the older dispatcher rules.
// (plus an "Other" note that only shows up if a bind fits none of them),
// and every row reads as a plain sentence: "Toggle overview",
// "Focus window in direction", "Send to workspace # (1–5)", "Browser" ...
//
// Like Illogical Impulse, it only lists what you should know. Left out unless
// build(raw, shellOnly, true) asks for everything:
//   - hardware keys (XF86 volume / brightness / media / power) and lid switches
//   - cosmetic or one-off shell calls (bar style / position, theme refresh,
//     to-do lock, gamma, get / list ...) and show / hide when a toggle exists
//   - window-group / z-order corner cases, extras like power profile or WARP
//   - binds it can't put a name to (group "Other")
//   - a second key that opens a panel / app that is already listed
// A bind that has a description (bindd) is one you wrote up yourself, so it
// always stays.

var NOTE_W = 400;
var ROW_H = 30;
var CHUNK = 16;  // rows per note before it continues on a second one

// Display order + hyprland's modmask bits.
var MODS = [["Super", 64], ["Ctrl", 4], ["Alt", 8], ["Shift", 1]];
var MOD_MASK = 77;

var CATS = [
    { id: "shell",      title: "Shell",      kind: "sticky",   icon: "dashboard" },
    { id: "utilities",  title: "Utilities",  kind: "pink",     icon: "construction" },
    { id: "windows",    title: "Windows",    kind: "index",    icon: "web_asset" },
    { id: "workspaces", title: "Workspaces", kind: "notebook", icon: "grid_view" },
    { id: "session",    title: "Session",    kind: "mint",     icon: "power_settings_new" },
    { id: "screen",     title: "Screen",     kind: "sticky",   icon: "desktop_windows" },
    { id: "media",      title: "Media",      kind: "polaroid", icon: "music_note" },
    { id: "apps",       title: "Apps",       kind: "pink",     icon: "apps" },
    { id: "other",      title: "Other",      kind: "mint",     icon: "more_horiz" }
];

var KEY_NAMES = {
    "return": "Enter", "escape": "Esc", "space": "Space", "tab": "Tab",
    "backspace": "Bksp", "delete": "Del", "print": "PrtSc", "insert": "Ins",
    "home": "Home", "end": "End", "caps_lock": "Caps",
    "page_up": "PgUp", "page_down": "PgDn", "prior": "PgUp", "next": "PgDn",
    "left": "←", "right": "→", "up": "↑", "down": "↓",
    "minus": "-", "equal": "=", "comma": ",", "period": ".", "slash": "/",
    "semicolon": ";", "grave": "`", "bracketleft": "[", "bracketright": "]",
    "backslash": "\\", "apostrophe": "'",
    "xf86audioraisevolume": "Vol+", "xf86audiolowervolume": "Vol−",
    "xf86audiomute": "Mute", "xf86audiomicmute": "Mic",
    "xf86monbrightnessup": "Bright+", "xf86monbrightnessdown": "Bright−",
    "xf86audioplay": "Play", "xf86audionext": "Next", "xf86audioprev": "Prev",
    "xf86audiostop": "Stop",
    "mouse:272": "LMB", "mouse:273": "RMB", "mouse:274": "MMB",
    "mouse:275": "Back", "mouse:276": "Fwd", "super_l": "tap", "super_r": "tap",
    "mouse_down": "Wheel↓", "mouse_up": "Wheel↑"
};

// ===== Dispatchers that belong to Workspaces / Windows =====
var WS = {
    workspace: 1, focusworkspaceoncurrentmonitor: 1, movetoworkspace: 1,
    movetoworkspacesilent: 1, togglespecialworkspace: 1, focusmonitor: 1,
    movecurrentworkspacetomonitor: 1, swapactiveworkspaces: 1
};

var WIN = {
    killactive: 1, togglefloating: 1, fullscreen: 1, fullscreenstate: 1,
    movefocus: 1, movewindow: 1, swapwindow: 1, resizeactive: 1, resizewindow: 1,
    pin: 1, togglesplit: 1, splitratio: 1, pseudo: 1, cyclenext: 1, focuswindow: 1,
    centerwindow: 1, togglegroup: 1, changegroupactive: 1, movewindoworgroup: 1,
    moveactive: 1, setfloating: 1, settiled: 1, bringactivetotop: 1, alterzorder: 1,
    focusurgentorlast: 1, focuscurrentorlast: 1, layoutmsg: 1, movegroupwindow: 1
};

// Window binds for corner cases; hidden until "show all".
var WIN_MINOR = {
    bringactivetotop: 1, alterzorder: 1, movegroupwindow: 1, changegroupactive: 1,
    movewindoworgroup: 1, focusurgentorlast: 1, focuscurrentorlast: 1, layoutmsg: 1
};

var DIR_WORD = { l: "left", r: "right", u: "up", d: "down" };
var ARROW_ORDER = ["←", "↑", "→", "↓"];

// Keys that come as a pair: Super+PgUp / Super+PgDn become one row.
var REL_PAIR = {
    left: "arrows", right: "arrows",
    page_up: "page", prior: "page", page_down: "page", next: "page",
    mouse_up: "wheel", mouse_down: "wheel",
    bracketleft: "brackets", bracketright: "brackets",
    comma: "comma", period: "comma"
};

var LAYOUT_MSG = {
    togglesplit: "Toggle split direction", swapsplit: "Swap split",
    movetoroot: "Move window to root", rollnext: "Roll layout forward",
    rollprev: "Roll layout back", swapwithmaster: "Swap with master",
    focusmaster: "Focus master window", cyclenext: "Focus next window",
    cycleprev: "Focus previous window", addmaster: "Add to master",
    removemaster: "Remove from master", orientationnext: "Next layout orientation",
    orientationprev: "Previous layout orientation"
};

function cap1(s) {
    s = String(s || "");
    return s.charAt(0).toUpperCase() + s.slice(1);
}

function words(s) {
    return String(s).replace(/([a-z])([A-Z])/g, "$1 $2").toLowerCase();
}

function modNames(mask) {
    var out = [];
    for (var i = 0; i < MODS.length; i++)
        if ((mask & MODS[i][1]) !== 0)
            out.push(MODS[i][0]);
    return out;
}

function keyName(raw) {
    var k = String(raw || "");
    var low = k.toLowerCase();
    if (KEY_NAMES[low])
        return KEY_NAMES[low];
    var m = low.match(/^code:(\d+)$/);
    if (m) {
        var n = Number(m[1]);
        if (n >= 10 && n <= 18) return String(n - 9);   // top-row digits, standard layout
        if (n === 19) return "0";
        return "#" + n;
    }
    if (low.indexOf("xf86") === 0) return k.slice(4);
    if (k.length === 1) return k.toUpperCase();
    return k.charAt(0).toUpperCase() + k.slice(1);
}

// ===== Workspace + window wording =====
function wsLabel(d, arg) {
    var move = d.indexOf("movetoworkspace") === 0;
    if (d === "togglespecialworkspace")
        return "Toggle scratchpad" + (arg && arg !== "special" && arg !== "magic" ? ": " + arg : "");
    if (d === "focusmonitor")
        return "Focus monitor" + (arg ? " " + (DIR_WORD[arg] || arg) : "");
    if (d === "movecurrentworkspacetomonitor")
        return "Send workspace to monitor" + (arg ? " " + (DIR_WORD[arg] || arg) : "");
    if (d === "swapactiveworkspaces")
        return "Swap monitor workspaces";

    if (/^special/.test(arg))
        return move ? "Send to scratchpad" : "Toggle scratchpad";
    var rel = arg.match(/^[emr]?([+-])\d+$/);
    if (rel) {
        var way = rel[1] === "+" ? "next" : "previous";
        return move ? "Send to " + way + " workspace" : cap1(way) + " workspace";
    }
    if (/^previous/.test(arg))
        return move ? "Send to last workspace" : "Last workspace";
    if (/^empty/.test(arg))
        return move ? "Send to empty workspace" : "Go to empty workspace";

    var base = move ? "Send to workspace" : "Focus workspace";
    var out = arg ? base + " " + arg.replace(/^name:/, "") : base;
    return d === "movetoworkspacesilent" ? out + " (stay)" : out;
}

function range(nums) {
    var seen = {};
    var u = [];
    for (var i = 0; i < nums.length; i++)
        if (!seen[nums[i]]) { seen[nums[i]] = 1; u.push(nums[i]); }
    u.sort(function (a, b) { return a - b; });
    var run = u.length >= 3;
    for (var k = 1; run && k < u.length; k++)
        if (u[k] !== u[k - 1] + 1) run = false;
    return run ? u[0] + "–" + u[u.length - 1] : u.join(", ");
}

function wsFoldLabel(d, nums) {
    var move = d.indexOf("movetoworkspace") === 0;
    var tail = range(nums) + (d === "movetoworkspacesilent" ? ", stay" : "");
    return (move ? "Send to workspace # (" : "Focus workspace # (") + tail + ")";
}

function relFoldLabel(d) {
    return d.indexOf("movetoworkspace") === 0
        ? "Send to previous/next workspace" : "Previous/next workspace";
}

function winLabel(d, arg, mouse) {
    var dir = DIR_WORD[arg];
    switch (d) {
    case "killactive":         return "Close window";
    case "togglefloating":     return "Float / tile window";
    case "fullscreen":         return arg === "1" ? "Maximize window" : "Fullscreen";
    case "fullscreenstate":    return "Fullscreen spoof";
    case "movefocus":          return dir ? "Focus window " + dir : "Focus window";
    case "movewindow":
        if (mouse) return "Move window (drag)";
        if (dir) return "Move window " + dir;
        return /^mon:/.test(arg) ? "Move window to monitor" : "Move window";
    case "swapwindow":         return dir ? "Swap window " + dir : "Swap window";
    case "resizeactive":       return "Resize window";
    case "resizewindow":       return "Resize window (drag)";
    case "pin":                return "Pin window";
    case "togglesplit":        return "Toggle split direction";
    case "splitratio":         return "Adjust split ratio";
    case "pseudo":             return "Toggle pseudo-tiling";
    case "cyclenext":          return /prev/.test(arg) ? "Focus previous window" : "Focus next window";
    case "focuswindow":
        return arg ? "Focus " + arg.replace(/^(class|title|initialclass|initialtitle|address):/, "") + " window"
                   : "Focus window";
    case "centerwindow":       return "Center window";
    case "togglegroup":        return "Toggle window group";
    case "changegroupactive":
        return (arg === "b" || /back|prev/.test(arg)) ? "Previous tab in group" : "Next tab in group";
    case "movewindoworgroup":  return dir ? "Move window / group " + dir : "Move window / group";
    case "movegroupwindow":    return arg === "b" ? "Move tab back" : "Move tab forward";
    case "moveactive":         return "Move window";
    case "setfloating":        return "Float window";
    case "settiled":           return "Tile window";
    case "bringactivetotop":   return "Raise window";
    case "alterzorder":        return /bottom/.test(arg) ? "Lower window" : "Raise window";
    case "focusurgentorlast":  return "Focus urgent / last window";
    case "focuscurrentorlast": return "Focus last window";
    case "layoutmsg":
        var word = arg.split(/\s+/)[0];
        return LAYOUT_MSG[word] || ("Layout: " + arg);
    }
    return "Window: " + d;
}

function dirFoldLabel(d) {
    if (d === "movefocus")  return "Focus window in direction";
    if (d === "movewindow") return "Move window in direction";
    if (d === "swapwindow") return "Swap window in direction";
    if (d === "splitratio") return "Adjust split ratio";
    return "Resize window";
}

// ← ↑ → ↓ in one keycap, whatever order the binds came in.
function joinArrows(caps) {
    var all = true;
    for (var i = 0; i < caps.length; i++)
        if (ARROW_ORDER.indexOf(caps[i]) < 0) all = false;
    if (!all) return caps.join("/");
    var out = [];
    for (var k = 0; k < ARROW_ORDER.length; k++)
        if (caps.indexOf(ARROW_ORDER[k]) >= 0) out.push(ARROW_ORDER[k]);
    return out.join("/");
}

// PgUp + PgDn -> PgUp/Dn, Wheel↑ + Wheel↓ -> Wheel↑/↓, ← + → -> ←/→
function joinPair(a, b) {
    var n = 0;
    while (n < a.length && n < b.length && a.charAt(n) === b.charAt(n)) n++;
    if (n > 0 && n < a.length && n < b.length && /[A-Za-z]/.test(a.charAt(0)))
        return a + "/" + b.slice(n);
    return a + "/" + b;
}

// ===== "Group: sentence" descriptions =====
var GROUP_WORD = {
    shell: "shell", utilities: "utilities", utility: "utilities",
    windows: "windows", window: "windows", workspaces: "workspaces", workspace: "workspaces",
    session: "session", screen: "screen", media: "media", apps: "apps", app: "apps"
};

// -> { cat, label, minor } or null when the description has no known group.
function descGroup(b) {
    if (!b.has_description) return null;
    var m = String(b.description || "").match(/^\s*([A-Za-z]+)\s*(\(more\))?\s*:\s*(\S[\s\S]*?)\s*$/);
    if (!m) return null;
    var cat = GROUP_WORD[m[1].toLowerCase()];
    if (!cat) return null;
    return { cat: cat, label: m[3], minor: !!m[2] };
}

// Keys that fold into one row when the sentence is the same. Anything not
// listed only folds with itself.
var DESC_FAMILY = {
    left: "arrows", right: "arrows", up: "arrows", down: "arrows",
    page_up: "page", prior: "page", page_down: "page", next: "page",
    mouse_up: "wheel", mouse_down: "wheel",
    bracketleft: "brackets", bracketright: "brackets",
    semicolon: "split", apostrophe: "split", comma: "comma", period: "comma"
};

function familyOf(low) {
    if (/^[0-9]$/.test(low)) return "num";
    return DESC_FAMILY[low] || low;
}

// The keycaps of a folded row: 1..0 -> "#", ← ↑ → ↓, PgUp/Dn, Wheel↑/↓, ;/'
function foldCaps(caps) {
    var digits = true;
    var arrows = true;
    for (var i = 0; i < caps.length; i++) {
        if (!/^\d+$/.test(caps[i])) digits = false;
        if (ARROW_ORDER.indexOf(caps[i]) < 0) arrows = false;
    }
    if (digits && caps.length >= 3) return "#";
    if (arrows) return joinArrows(caps);
    if (caps.length === 2) {
        // "Up" before "Down" whatever order the binds came in (PgUp/Dn, Wheel↑/↓)
        var up = /(Up|↑)$/;
        if (!up.test(caps[0]) && up.test(caps[1])) caps = [caps[1], caps[0]];
        return joinPair(caps[0], caps[1]);
    }
    return caps.join("/");
}

// ===== This shell's own binds =====
function isShell(b) {
    var d = String(b.dispatcher || "").toLowerCase();
    var arg = String(b.arg || "");
    if (b.has_description && /^\s*shell\s*(\(more\))?\s*:/i.test(String(b.description || ""))) return true;
    if (d === "global" && /^quickshell:/i.test(arg)) return true;
    if (d.indexOf("exec") === 0 && /\b(qs|quickshell)\b[^|;&]*\bipc call\b/.test(arg)) return true;
    return false;
}

// A target listed here decides the group outright; anything else (a
// `global` dispatch, a target added later) falls through to word rules.
var SHELL_TARGET = {
    overview: "shell", applauncher: "shell", quickpanel: "shell",
    phone: "shell", launcherphone: "shell", overviewphone: "shell", wallpaperphone: "shell",
    cheatsheet: "shell", wallpaperpicker: "shell", theme: "shell", palette: "shell",
    barstyle: "shell", barposition: "shell", todo: "shell", notes: "shell", clock: "shell", usercard: "shell", weathercard: "shell", image: "shell", calendarcard: "shell", palettecard: "shell", lyrics: "shell",
    lock: "session",
    scale: "screen"
    // osd is split by function, see shellCategory()
};

function shellCategory(b) {
    var arg = String(b.arg || "");
    var m = arg.match(/ipc call (\S+)\s*(\S*)/);
    var target = m ? m[1].toLowerCase() : "";
    var fn = words(m ? m[2] : arg.replace(/^quickshell:/i, ""));

    if (target && SHELL_TARGET[target])
        return SHELL_TARGET[target];

    var n = (target + " " + fn).trim();
    if (/volume|mute|\bmic\b|audio|media|player|music/.test(n)) return "media";
    if (/bright|gamma|night|scale|zoom|magnif/.test(n)) return "screen";
    if (/screenshot|screen shot|record|snip|colou?r pick|\bocr\b|calc/.test(n)) return "utilities";
    if (/\block\b|logout|suspend|sleep|shutdown|power ?off|reboot/.test(n)) return "session";
    return "shell";
}

var IPC_NAME = {
    overview: "overview", applauncher: "app launcher", quickpanel: "quick panel",
    phone: "phone", launcherphone: "apps", overviewphone: "overview", wallpaperphone: "wallpapers",
    cheatsheet: "cheatsheet", wallpaperpicker: "wallpaper picker", theme: "theme picker", palette: "palette",
    barstyle: "bar style", barposition: "bar position", todo: "to-do", notes: "sticky notes", clock: "clock", usercard: "user card", weathercard: "weather card", image: "images", calendarcard: "calendar", palettecard: "palette card", lyrics: "lyrics", lock: "lock screen", scale: "UI scale", osd: "OSD"
};

var IPC_VERB = {
    toggle: "Toggle", show: "Show", hide: "Hide", open: "Open", close: "Close",
    lock: "Lock", unlock: "Unlock", cycle: "Cycle", reset: "Reset", set: "Set",
    refresh: "Refresh", focus: "Focus",
    go: "Go to", back: "Back", home: "Home"
};

// "<target> <fn>" (lowercase) -> the sentence to show.
var IPC_FIXED = {
    "wallpaperpicker toggle": "Change wallpaper",
    "lock lock": "Lock screen",
    "theme toggle": "Toggle theme picker",
    "theme darktoggle": "Toggle dark mode",
    "theme darkon": "Dark mode on",
    "theme darkoff": "Light mode on",
    "theme modecycle": "Cycle light / dark mode",
    "theme cycle": "Cycle theme",
    "theme refresh": "Refresh theme colors",
    "theme discord": "Regenerate Discord theme",
    "barstyle cycle": "Cycle bar style",
    "barposition cycle": "Cycle bar position",
    "todo resetposition": "Reset to-do position",
    "notes create": "New sticky note",
    "notes arrange": "Tidy sticky notes",
    "clock resetposition": "Reset clock position",
    "clock toggleformat": "Clock 12h / 24h",
    "usercard resetposition": "Reset user card position",
    "weathercard resetposition": "Reset weather card position",
    "weathercard refresh": "Refresh weather card",
    "weathercard style": "Weather card style (minimal / classic)",
    "image toggle": "Show / hide custom images",
    "image add": "Add an empty image frame (drop files on it)",
    "image resetposition": "Reset custom image positions",
    "calendarcard resetposition": "Reset calendar position",
    "palettecard resetposition": "Reset palette card position",
    "palettecard shuffle": "Shuffle the palette card",
    "lyrics resetposition": "Reset lyrics position",
    "lyrics nudge": "This song's lyrics earlier / later (milliseconds)",
    "lyrics nudgeall": "Every song's lyrics earlier / later (milliseconds)",
    "lyrics refresh": "Fetch the lyrics again",
    "lyrics debug": "Show the lyrics clock's numbers (timing check)",
    "scale reset": "Reset UI scale",
    "osd volumeup": "Volume up", "osd volumedown": "Volume down",
    "osd togglemute": "Mute / unmute", "osd togglemicmute": "Mute / unmute mic",
    "osd brightnessup": "Brightness up", "osd brightnessdown": "Brightness down",
    "osd gammaup": "Gamma up", "osd gammadown": "Gamma down"
};

// Shell calls that aren't worth a line on the sheet. `toggled` has the
// targets that also have a toggle bound, which makes show / hide redundant.
function ipcMinor(target, fn, toggled) {
    fn = String(fn || "").toLowerCase();
    if (/^(get|list|modeget|darkget)$/.test(fn)) return true;     // only print something
    if (target === "barstyle" || target === "barposition") return true;
    if (target === "theme") return !/^(toggle|darktoggle)$/.test(fn);
    if (target === "palette") return fn !== "toggle";
    if (target === "todo" || target === "notes" || target === "clock" || target === "usercard" || target === "weathercard" || target === "image" || target === "calendarcard" || target === "palettecard" || target === "lyrics") return fn !== "toggle" && fn !== "pick" && !(target === "image" && fn === "add") && !(target === "notes" && fn === "create");
    if (target === "osd") return /^(gamma|setgamma|hide)/.test(fn);
    if (target === "scale") return fn !== "bump";
    if (target === "lock") return fn === "focus";
    if (/^(show|hide|open|close)$/.test(fn) && toggled[target]) return true;
    return false;
}

function globalLabel(name) {
    var w = words(name).replace(/\s+/g, " ").trim();
    w = w.replace(/\bsidebar (left|right)\b/, "$1 sidebar");
    var m = w.match(/^(.*?)\s*\b(toggle|show|hide|open|close)$/);
    if (m && m[1]) return cap1(m[2]) + " " + m[1];
    return cap1(w || "shell");
}

function shellLabel(b) {
    var arg = String(b.arg || "").trim();
    var m = arg.match(/ipc call (\S+)\s*(\S*)\s*(.*)$/);
    if (!m)
        return globalLabel(arg.replace(/^quickshell:/i, ""));

    var target = m[1].toLowerCase();
    var fn = m[2];
    var rest = m[3].trim();
    var fixed = IPC_FIXED[target + " " + fn.toLowerCase()];
    if (fixed) return fixed;

    if (target === "scale" && fn === "bump") {
        var delta = parseFloat(rest.split(/\s+/).pop());
        return delta < 0 ? "UI scale down" : "UI scale up";
    }
    var noun = IPC_NAME[target] || words(target);
    if (!fn) return cap1(noun);
    var verb = IPC_VERB[fn.toLowerCase()];
    if (verb) return verb + " " + noun + (fn === "set" && rest ? ": " + rest : "");
    return cap1(noun) + ": " + words(fn) + (rest ? " " + rest : "");
}

// ===== `exec` binds =====

function stripWrappers(c) {
    c = String(c || "").trim();
    var prev;
    do {
        prev = c;
        c = c.replace(/^\s*(?:sh|bash|zsh|fish)\s+-l?c\s+(['"])([\s\S]*)\1\s*$/, "$2");
        c = c.replace(/^\s*(?:uwsm[\s-]app(?:\s+--)?|app2unit(?:\s+--)?|systemd-run\s+--user(?:\s+--\S+)*|env|nohup|setsid|exec|command)\s+/, "");
        c = c.replace(/^\s*[A-Za-z_][A-Za-z0-9_]*=\S*\s+/, "");
        c = c.replace(/^\s*hyprctl\s+dispatch\s+exec\s+/, "");
        c = c.replace(/^\s*\[[^\]]*\]\s*/, "");
    } while (c !== prev);
    return c.trim();
}

// -> { name, ids }: what to show, and the names to look up a role by.
function programOf(c) {
    var toks = String(c || "").split(/\s+/);
    var p = (toks[0] || "").replace(/^["']|["']$/g, "").split("/").pop();
    var name = p;
    var ids = [p.toLowerCase()];
    if ((p === "flatpak" && toks[1] === "run") || p === "gtk-launch" || p === "gio") {
        for (var i = 1; i < toks.length; i++) {
            if (toks[i].charAt(0) === "-" || toks[i] === "run" || toks[i] === "launch") continue;
            var id = toks[i];
            name = id.split(".").pop();
            ids = [name.toLowerCase(), id.toLowerCase()];
            break;
        }
    }
    return { name: name, ids: ids };
}

// [program regex, sentence, group]
var APP_ROLES = [
    [/^(foot|footclient|kitty|alacritty|wezterm|ghostty|konsole|gnome-terminal|xterm|urxvt|rxvt|terminator|tilix|xfce4-terminal|lxterminal|sakura|termite|cool-retro-term|xdg-terminal-exec|ptyxis|blackbox|st|rio|contour)$/, "Terminal"],
    [/^(nautilus|thunar|dolphin|nemo|pcmanfm|pcmanfm-qt|caja|spacefm|krusader|doublecmd|yazi|ranger|lf|nnn|vifm|mc)$/, "File manager"],
    [/^(firefox|librewolf|floorp|chromium|google-chrome|chrome|brave|vivaldi|microsoft-edge|opera|thorium|tor-browser|mullvad-browser)([-\w]*)$/, "Browser"],
    [/^(zen|zen-browser|qutebrowser|epiphany|falkon|helium|midori)$/, "Browser"],
    [/^(code|code-oss|codium|vscodium|vscode|cursor|zed|zeditor|windsurf|subl|sublime_text|idea|pycharm|webstorm|clion|goland|rider|android-studio|intellij-idea[-\w]*)$/, "Code editor"],
    [/^(libreoffice|soffice|lowriter|localc|loimpress|onlyoffice|onlyoffice-desktopeditors|desktopeditors|wps|wpsoffice|et|wpp|freeoffice|calligra[-\w]*)$/, "Office software"],
    [/^(gnome-text-editor|gedit|kate|kwrite|mousepad|pluma|xed|leafpad|featherpad|notepadqq|nano|vim|nvim|neovim|helix|hx|micro|emacs|emacsclient)$/, "Text editor"],
    [/^(pavucontrol|pavucontrol-qt|pwvucontrol)$/, "Volume mixer"],
    [/^(easyeffects)$/, "Audio effects"],
    [/^(helvum|qpwgraph|coppwr)$/, "Audio patchbay"],
    [/^(gnome-control-center|systemsettings|systemsettings5|xfce4-settings-manager|lxqt-config|cinnamon-settings|unity-control-center)$/, "Settings app"],
    [/^(gnome-system-monitor|ksysguard|plasma-systemmonitor|missioncenter|mission-center|resources|btop|htop|btm|bottom|bpytop|glances|top|xfce4-taskmanager|lxtask|stacer)$/, "Task manager"],
    [/^(nm-connection-editor)$/, "Network settings"],
    [/^(nmtui|nmtui-connect)$/, "Network manager"],
    [/^(blueman-manager|blueberry|bluetui|bluetoothctl)$/, "Bluetooth manager"],
    [/^(nwg-look|lxappearance)$/, "Appearance settings"],
    [/^(qt5ct|qt6ct)$/, "Qt appearance settings"],
    [/^(discord|vesktop|webcord|legcord|armcord)$/, "Discord"],
    [/^(telegram-desktop|telegram|kotatogram)$/, "Telegram"],
    [/^(signal-desktop|signal)$/, "Signal"],
    [/^(element-desktop|element)$/, "Element"],
    [/^(slack|zoom|teams-for-linux)$/, "Chat / meetings"],
    [/^(spotify|spotify-launcher)$/, "Spotify"],
    [/^(mpv|vlc|celluloid|totem|haruna|smplayer|parole)$/, "Video player"],
    [/^(strawberry|rhythmbox|lollypop|amberol|cider|youtube-music|feishin)$/, "Music player"],
    [/^(obs|obs-studio|com\.obsproject\.studio)$/, "OBS Studio"],
    [/^(steam|steam-runtime)$/, "Steam"],
    [/^(heroic|lutris|prismlauncher|bottles|minecraft-launcher)$/, "Game launcher"],
    [/^(gimp|gimp-[\d.]+)$/, "GIMP"],
    [/^(inkscape|krita|blender|kdenlive|darktable|shotcut|audacity|obsidian|logseq)$/, "__name__"],
    [/^(evince|okular|zathura|atril|papers|sioyek|mupdf|xreader|foxitreader)$/, "PDF viewer"],
    [/^(eog|imv|loupe|gwenview|feh|nsxiv|sxiv|swayimg|ristretto|viewnior|qimgv)$/, "Image viewer"],
    [/^(thunderbird|geary|evolution|kmail|mailspring|betterbird)$/, "Email"],
    [/^(keepassxc|bitwarden|1password)$/, "Password manager"],
    [/^(baobab)$/, "Disk usage"],
    [/^(gnome-disks)$/, "Disks"],
    [/^(gnome-software|plasma-discover|discover|pamac-manager|bazaar)$/, "Software center"],
    [/^(gnome-calculator|kcalc|qalculate-gtk|qalculate-qt|qalculate|galculator|speedcrunch|qalc)$/, "Calculator", "utilities"]
];

function roleOf(pr) {
    for (var i = 0; i < APP_ROLES.length; i++)
        for (var k = 0; k < pr.ids.length; k++)
            if (APP_ROLES[i][0].test(pr.ids[k]))
                return { label: APP_ROLES[i][1] === "__name__" ? cap1(pr.name) : APP_ROLES[i][1],
                         cat: APP_ROLES[i][2] || "apps" };
    return null;
}

function appInfo(c) {
    var pr = programOf(c);
    var role = roleOf(pr);
    if (role && role.label === "Terminal") {
        var m = c.match(/\s(?:-e|-x|--exec|--command|--)\s+(.+)$/);
        if (m) {
            var sub = programOf(stripWrappers(m[1]));
            var r2 = roleOf(sub);
            return r2 || { label: "Run " + sub.name + " in terminal", cat: "apps" };
        }
    }
    if (role) return role;

    if (/^(qs|quickshell)$/.test(pr.ids[0])) {
        var q = c.match(/\s(?:-p|-c|--path|--config)\s+(\S+)/);
        var w = q ? q[1].split("/").pop().replace(/\.qml$/, "") : "";
        return { label: /settings/i.test(w) ? "Settings app" : (w ? "Open " + w : "Open shell"), cat: "apps" };
    }
    if (/\.(sh|py|lua|fish|js)$/.test(pr.name))
        return { label: "Run " + pr.name, cat: "apps" };
    if (!pr.name)
        return { label: "Run command", cat: "apps" };
    return { label: "Open " + cap1(pr.name), cat: "apps" };
}

function zoomLabel(t, low) {
    if (/reset|=\s*1\b/.test(t) || /^(0|backspace)$/.test(low)) return "Reset zoom";
    if (/minus|mouse_down/.test(low) || /\bout\b|\bdec|\*\s*0\.|-\s*0\.\d/.test(t)) return "Zoom out";
    return "Zoom in";
}

function brightLabel(t, low) {
    var up = /\+\s*\d|\d+%?\s*\+|\bup\b|\binc|\braise|\s-a\b/.test(t) || /up$/.test(low);
    var down = /\d+%?\s*-(?!\w)|[\s@]-\d|\bdown\b|\bdec|\blower|\s-u\b/.test(t) || /down$/.test(low);
    if (up && !down) return "Brightness up";
    if (down && !up) return "Brightness down";
    return "Brightness";
}

function volumeLabel(t, low) {
    var mic = /source|\bmic\b|capture|microphone/.test(t) || /micmute/.test(low);
    if (/set-sink-mute|set-source-mute|set-mute|toggle-mute|unmute|\s-t\b|\bmute\b|\btoggle\b/.test(t) || /mute/.test(low))
        return mic ? "Mute / unmute mic" : "Mute / unmute";
    var up = /\+\s*\d|\d+%?\s*\+|\s-i\b|\binc|\braise|\bup\b/.test(t) || /raise|up$/.test(low);
    var down = /\d+%?\s*-(?!\w)|[\s@]-\d|\s-d\b|\bdec|\blower|\bdown\b/.test(t) || /lower|down$/.test(low);
    var noun = mic ? "Mic volume" : "Volume";
    if (up && !down) return noun + " up";
    if (down && !up) return noun + " down";
    return noun;
}

function transportLabel(t) {
    if (/\bnext\b/.test(t)) return "Next track";
    if (/\b(prev|previous)\b/.test(t)) return "Previous track";
    if (/play-pause|play_pause|\btoggle\b/.test(t)) return "Play/pause media";
    if (/\bstop\b/.test(t)) return "Stop media";
    if (/\bpause\b/.test(t)) return "Pause media";
    if (/\bplay\b/.test(t)) return "Play media";
    return "Media control";
}

function shotLabel(t) {
    var region = /slurp|region|area|select|snip|\bgui\b|\s-g\b/.test(t);
    var win = /window|\bactive\b/.test(t);
    var clip = /wl-copy|clipboard|copysave|\bcopy\b/.test(t);
    var file = /copysave|\bsave\b|\btee\b|pictures|screenshots|\.png|\.jpe?g|--output-folder|\s-o\s|\$\(date/.test(t);
    var base = win ? "Snip window" : region ? "Snip region" : "Screenshot";
    var dest = clip && file ? " >> clipboard & file" : clip ? " >> clipboard" : file ? " >> file" : "";
    if (!dest && /satty|swappy/.test(t)) dest = " >> editor";
    return base + dest;
}

function recordLabel(t) {
    var region = /slurp|region|area|select|\s-g\b/.test(t);
    var base = region ? "Record region" : "Record screen";
    if (/wf-recorder|wl-screenrec|gpu-screen-recorder/.test(t))
        return base + (/\s(-a|--audio)\b|audio=|--audio/.test(t) ? " (with sound)" : " (no sound)");
    return base;
}

var XF86_INFO = {
    xf86audioraisevolume: ["media", "Volume up"], xf86audiolowervolume: ["media", "Volume down"],
    xf86audiomute: ["media", "Mute / unmute"], xf86audiomicmute: ["media", "Mute / unmute mic"],
    xf86audioplay: ["media", "Play/pause media"], xf86audiopause: ["media", "Pause media"],
    xf86audionext: ["media", "Next track"], xf86audioprev: ["media", "Previous track"],
    xf86audiostop: ["media", "Stop media"],
    xf86monbrightnessup: ["screen", "Brightness up"], xf86monbrightnessdown: ["screen", "Brightness down"],
    xf86poweroff: ["session", "Power off"], xf86sleep: ["session", "Sleep"],
    xf86calculator: ["utilities", "Calculator"], xf86mail: ["apps", "Email"],
    xf86www: ["apps", "Browser"], xf86homepage: ["apps", "Browser"],
    xf86explorer: ["apps", "File manager"]
};

function execInfo(b, low) {
    var cmd = stripWrappers(b.arg);
    var t = (cmd + " " + (b.has_description ? String(b.description || "") : "")).toLowerCase();
    var m;

    // -- windows
    if (/hyprctl\s+kill/.test(t))
        return { cat: "windows", label: "Forcefully zap a window" };

    // -- session
    if (/hyprlock|swaylock|gtklock|loginctl\s+lock-session|betterlockscreen|i3lock|waylock/.test(t))
        return { cat: "session", label: /suspend|sleep/.test(t) ? "Lock & sleep" : "Lock screen" };
    if (/wlogout|nwg-bar|wleave|archlinux-logout/.test(t))
        return { cat: "session", label: "Power menu" };
    if (/systemctl\s+hibernate|loginctl\s+hibernate/.test(t))
        return { cat: "session", label: "Hibernate" };
    if (/systemctl\s+suspend|loginctl\s+suspend|pm-suspend/.test(t))
        return { cat: "session", label: "Sleep" };
    if (/systemctl\s+poweroff|loginctl\s+poweroff|\bpoweroff\b|shutdown\s+(-h\s+)?now|\bhalt\b/.test(t))
        return { cat: "session", label: "Power off" };
    if (/systemctl\s+reboot|loginctl\s+reboot|\breboot\b/.test(t))
        return { cat: "session", label: "Reboot" };
    if (/uwsm\s+stop|hyprctl\s+dispatch\s+exit|loginctl\s+terminate-(user|session)|\blogout\b/.test(t))
        return { cat: "session", label: "Log out" };

    // -- shell
    if (/cliphist|clipman|copyq|clipse|greenclip/.test(t))
        return { cat: "shell", label: /wl-copy/.test(t) ? "Clipboard history >> clipboard" : "Clipboard history" };
    if (/bemoji|rofimoji|emote|wofi-emoji|emoji/.test(t))
        return { cat: "shell", label: "Emoji >> clipboard" };
    if (/(pkill|killall)\s+(-\w+\s+)?(qs|quickshell)\b|\b(qs|quickshell)\s+(-\S+\s+\S+\s+)*kill\b|restart.*(widgets|quickshell)/.test(t))
        return { cat: "shell", label: "Restart widgets" };

    // -- utilities
    if (/hyprpicker|wl-color-picker|colou?r-?pick|xcolor/.test(t))
        return { cat: "utilities", label: /\s-a\b|--autocopy|wl-copy|clipboard/.test(t) ? "Pick color >> clipboard" : "Pick color" };
    if (/tesseract|\bocr\b/.test(t))
        return { cat: "utilities", label: "OCR >> clipboard" };
    if (/\b(wf-recorder|wl-screenrec|gpu-screen-recorder|kooha|vokoscreen|screenrecord|recordmydesktop)\b|screen-?record|\brecord(ing|er)?\b/.test(t))
        return { cat: "utilities", label: recordLabel(t) };
    if (/\b(grim|grimblast|hyprshot|wayshot|flameshot|spectacle|gnome-screenshot|scrot|maim|shotman|satty|swappy)\b|screenshot/.test(t))
        return { cat: "utilities", label: shotLabel(t) };
    if (/dunstctl\s+close-all|makoctl\s+dismiss\s+(-a|--all)|swaync-client[^|;]*--close-all/.test(t))
        return { cat: "utilities", label: "Dismiss all notifications", minor: true };
    if (/dunstctl\s+history-pop|makoctl\s+restore/.test(t))
        return { cat: "utilities", label: "Restore last notification", minor: true };
    if (/dunstctl\s+close|makoctl\s+dismiss|swaync-client[^|;]*(--hide-latest|--close-latest)/.test(t))
        return { cat: "utilities", label: "Dismiss notification", minor: true };
    if (/dunstctl\s+set-paused|makoctl\s+mode|swaync-client[^|;]*(\s-d\b|--toggle-dnd)|do.not.disturb/.test(t))
        return { cat: "utilities", label: "Toggle do not disturb", minor: true };
    if (/swaync-client/.test(t))
        return { cat: "shell", label: "Toggle notification center" };
    if (/hyprctl\s+reload/.test(t))
        return { cat: "utilities", label: "Reload Hyprland config", minor: true };

    // -- extras from the quick-panel tiles
    if (/antiflashbang|anti-flashbang/.test(t))
        return { cat: "screen", label: "Cycle anti-flashbang", minor: true };
    if (/music-recognize|songrec/.test(t))
        return { cat: "utilities", label: "Recognize music", minor: true };
    if (/wvkbd|squeekboard|\bonboard\b/.test(t))
        return { cat: "shell", label: "Toggle on-screen keyboard" };
    if (/powerprofilesctl|power-profiles/.test(t))
        return { cat: "utilities", label: "Cycle power profile", minor: true };
    if (/warp-cli/.test(t))
        return { cat: "utilities", label: "Toggle WARP VPN", minor: true };

    // -- screen
    if (/cursor:zoom_factor|\bzoom\b|hyprmag|wooz|magnif/.test(t))
        return { cat: "screen", label: zoomLabel(t, low) };
    if (/brightnessctl|brillo|xbacklight|ddcutil|backlight|brightness/.test(t))
        return { cat: "screen", label: brightLabel(t, low) };
    if (/hyprsunset|gammastep|wlsunset|redshift|wluma|night-?light/.test(t))
        return { cat: "screen", minor: true, label: /toggle|pkill|killall|pidof/.test(t) ? "Toggle night light" : "Night light" };

    // -- media
    if (/\b(playerctl|mpc|cmus-remote|mpris-ctl)\b/.test(t))
        return { cat: "media", label: transportLabel(t) };
    if (/\b(wpctl|pactl|pamixer|amixer|pulsemixer|volumectl)\b|\bvolume\b|set-sink|set-source/.test(t))
        return { cat: "media", label: volumeLabel(t, low) };

    // -- launchers
    if (/\b(rofi|wofi|fuzzel|tofi|bemenu-run|anyrun|walker|ulauncher|albert|krunner|sherlock|vicinae|nwg-drawer)\b/.test(t))
        return { cat: "shell", label: /-show\s+window|--show\s+window/.test(t) ? "Window switcher"
                                      : /-show\s+run\b|--show\s+run\b/.test(t) ? "Run command" : "App launcher" };

    // -- apps (and calculators)
    var app = appInfo(cmd);
    if (app && app.label.indexOf("Open ") !== 0 && app.label.indexOf("Run ") !== 0)
        return app;

    // -- unknown program: a recognised XF86 key still tells us what it is
    var xf = XF86_INFO[low];
    if (xf) return { cat: xf[0], label: xf[1] };
    return app;
}

// ===== One bind =====
function classify(b, low, toggled) {
    var d = String(b.dispatcher || "").toLowerCase();
    var arg = String(b.arg || "").trim();

    var dg = descGroup(b);
    if (dg)
        return { cat: dg.cat, label: dg.label, minor: dg.minor, fromDesc: true };

    if (isShell(b)) {
        var sm = String(b.arg || "").match(/ipc call (\S+)\s*(\S*)/);
        return { cat: shellCategory(b), label: shellLabel(b),
                 minor: sm ? ipcMinor(sm[1].toLowerCase(), sm[2], toggled) : false };
    }
    if (WS[d])
        return { cat: "workspaces", label: wsLabel(d, arg) };
    if (WIN[d])
        return { cat: "windows", label: winLabel(d, arg, b.mouse), minor: !!WIN_MINOR[d] };
    if (d === "exit")
        return { cat: "session", label: "Exit Hyprland" };
    if (d === "dpms")
        return { cat: "screen", label: arg === "on" ? "Turn screen on" : arg === "off" ? "Turn screen off" : "Toggle screen" };
    if (d.indexOf("exec") === 0)
        return execInfo(b, low);

    var xf = XF86_INFO[low];
    if (xf) return { cat: xf[0], label: xf[1] };
    return { cat: "other", label: d ? cap1(d) + (arg ? ": " + arg : "") : "Unbound" };
}

// ---------------------------------------------------------------------------
var lastHiddenCount = 0;

// How many binds the last build() left out (to label the "show more" chip).
function lastHidden() {
    return lastHiddenCount;
}

// showAll = false (default): only what you should know, see the top of the file.
function build(raw, shellOnly, showAll) {
    if (shellOnly === undefined) shellOnly = false;
    var hidden = 0;
    var toggled = {};
    lastHiddenCount = 0;
    var binds;
    try { binds = JSON.parse(raw); } catch (e) { return []; }
    if (!Array.isArray(binds)) return [];

    // Pass 1: usable binds, and how many times each key combo appears.
    var count = {};
    var list = [];
    for (var i = 0; i < binds.length; i++) {
        var b = binds[i];
        if (b.submap) continue;
        if (shellOnly && !isShell(b)) continue;
        var key = String(b.key || "") || (b.keycode ? "code:" + b.keycode : "");
        if (!key) continue;
        var mods = (b.modmask | 0) & MOD_MASK;
        var id = mods + "|" + key.toLowerCase() + "|" + (b.release ? "r" : "p");
        count[id] = (count[id] || 0) + 1;
        list.push({ b: b, key: key, mods: mods, id: id });
        var sm = isShell(b) ? String(b.arg || "").match(/ipc call (\S+)\s*(\S*)/) : null;
        if (sm && sm[2].toLowerCase() === "toggle") toggled[sm[1].toLowerCase()] = true;
    }

    // Pass 2: sentence, group, and which binds fold into one row.
    var groups = {};
    var foldAt = {};
    for (var j = 0; j < list.length; j++) {
        var it = list[j];
        var bb = it.b;
        var low = it.key.toLowerCase();
        var d = String(bb.dispatcher || "").toLowerCase();
        var arg = String(bb.arg || "").trim();
        var info = classify(bb, low, toggled);
        var described = bb.has_description && bb.description;
        // A "Group:" description decides by itself: "(more)" is the only thing
        // that hides it. Anything else keeps the older rules.
        var hide = info.fromDesc ? !!info.minor
            : (!described && (info.minor || low.indexOf("xf86") === 0 || low.indexOf("switch:") === 0 || info.cat === "other"));
        if (!showAll && hide) {
            hidden++;
            continue;
        }
        var cap = keyName(it.key);
        var dup = count[it.id] > 1;
        var label = info.fromDesc ? info.label
            : (described ? String(bb.description).replace(/^\s*shell\s*:\s*/i, "") : info.label);

        var kind = "";
        var fk = "";
        var rel = arg.match(/^[emr]?([+-])\d+$/);
        var wsLike = d === "workspace" || d === "movetoworkspace" ||
                     d === "movetoworkspacesilent" || d === "focusworkspaceoncurrentmonitor";
        if (!described) {
            if (wsLike && /^\d+$/.test(arg)) {
                kind = "ws"; fk = it.mods + "|" + d + "|ws";
            } else if (wsLike && rel && REL_PAIR[low]) {
                kind = "rel"; fk = it.mods + "|" + d + "|rel|" + REL_PAIR[low];
            } else if ((d === "movefocus" || d === "swapwindow" || (d === "movewindow" && !bb.mouse)) &&
                       /^[lrud]$/.test(arg)) {
                kind = "dir"; fk = it.mods + "|" + d + "|dir";
            } else if (d === "resizeactive" || d === "splitratio") {
                kind = "dir"; fk = it.mods + "|" + d + "|dir";
            }
        }

        if (info.fromDesc) {
            kind = "desc";
            fk = "d|" + info.cat + "|" + it.mods + "|" + (info.minor ? 1 : 0) + "|" + label + "|" + familyOf(low);
        }

        var row = kind ? foldAt[fk] : null;
        if (row) {
            row.dup = row.dup || dup;
            if (kind === "ws") { row.nums.push(Number(arg)); row.caps.push(cap); }
            else if (kind === "rel") { if (rel[1] === "+") row.relNext = cap; else row.relPrev = cap; }
            else row.caps.push(cap);
            continue;
        }
        row = { mods: modNames(it.mods), mask: it.mods, caps: [cap], label: label,
                dup: dup, text: "", fold: kind, d: d, nums: [], relPrev: "", relNext: "" };
        if (kind === "ws") row.nums.push(Number(arg));
        if (kind === "rel") { if (rel[1] === "+") row.relNext = cap; else row.relPrev = cap; }
        if (kind) foldAt[fk] = row;
        (groups[info.cat] = groups[info.cat] || []).push(row);
    }

    // Pass 3: finish folded rows, build search text, cut into notes.
    var notes = [];
    for (var c = 0; c < CATS.length; c++) {
        var rows = groups[CATS[c].id];
        if (!rows) continue;
        for (var r = 0; r < rows.length; r++) {
            var rw = rows[r];
            if (rw.fold === "ws" && rw.nums.length > 1) {
                rw.caps = ["#"];
                rw.label = wsFoldLabel(rw.d, rw.nums);
            } else if (rw.fold === "dir" && rw.caps.length > 1) {
                rw.caps = [joinArrows(rw.caps)];
                rw.label = dirFoldLabel(rw.d);
            } else if (rw.fold === "rel" && rw.relPrev && rw.relNext) {
                rw.caps = [joinPair(rw.relPrev, rw.relNext)];
                rw.label = relFoldLabel(rw.d);
            } else if (rw.fold === "desc" && rw.caps.length > 1) {
                rw.caps = [foldCaps(rw.caps)];
            }
            rw.text = (rw.mods.join(" ") + " " + rw.caps.join(" ") + " "
                       + rw.label + " " + CATS[c].title).toLowerCase();
        }
        if (!showAll && CATS[c].id !== "windows" && CATS[c].id !== "workspaces") {
            // one line per action: a second key that opens the same panel / app
            // stays out. (Windows and Workspaces keep their alternate keys,
            // like Illogical Impulse lists PgUp/PgDn and the wheel separately.)
            var seen = {};
            var kept = [];
            for (var q = 0; q < rows.length; q++) {
                var lk = rows[q].label.toLowerCase();
                if (seen[lk]) { hidden++; continue; }
                seen[lk] = 1;
                kept.push(rows[q]);
            }
            rows = kept;
        }
        for (var s = 0; s < rows.length; s += CHUNK) {
            notes.push({
                id: CATS[c].id + s,
                title: CATS[c].title + (s > 0 ? " (" + (s / CHUNK + 1) + ")" : ""),
                kind: CATS[c].kind,
                icon: CATS[c].icon,
                rows: rows.slice(s, s + CHUNK)
            });
        }
    }
    lastHiddenCount = hidden;
    return notes;
}

function noteHeight(n) {
    return (n.kind === "polaroid" ? 72 : 16) + 50 + n.rows.length * ROW_H;
}

// Masonry: each note goes into the currently shortest column.
function place(notes, cols, gap) {
    var ys = [];
    for (var c = 0; c < cols; c++) ys.push(0);
    var items = [];
    for (var i = 0; i < notes.length; i++) {
        var col = 0;
        for (var k = 1; k < cols; k++)
            if (ys[k] < ys[col]) col = k;
        var h = noteHeight(notes[i]);
        items.push({ note: notes[i], x: col * (NOTE_W + gap), y: ys[col], h: h });
        ys[col] += h + gap;
    }
    return { items: items, height: Math.max.apply(null, ys) };
}

// Every typed word must appear in the row, and every active modifier chip
// must be part of the bind.
function matches(row, query, modFilter) {
    if ((row.mask & modFilter) !== modFilter) return false;
    var q = String(query || "").toLowerCase().trim();
    if (!q) return true;
    var parts = q.split(/\s+/);
    for (var i = 0; i < parts.length; i++)
        if (row.text.indexOf(parts[i]) < 0) return false;
    return true;
}
