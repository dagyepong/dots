.pragma library

// What the welcome screen says, in one place. WelcomePage.qml shows one entry
// at a time; to change a word, a slide's look or the order, edit it here (the
// counter in the corner follows the length of the list).
//
//   kind   which hero the slide has (see WelcomePage.qml):
//            "logo"    the SekaiPop logo springing in (the video's first slide)
//            "glyph"   one big icon sticker that is built up layer by layer
//            "units"   a full-width black band with one sticker per unit theme
//            "frame"   a framed picture (the desktop's own wallpaper)
//            "credits" no hero: a left-aligned block of text (the video's last slide)
//   title  bold line(s) ("\n" starts a new line). Words blur in one by one.
//   sub    grey line(s) under it.
//   top    the caption sits above the hero (only the first slide); else below it.
//   ghost  the huge faint logo behind the page (the video has it on the first
//          and the last slide only).
//   glyph  the Material Symbols name of a "glyph" hero; glyphFill 0 draws it as an
//          outline icon, 1 as a solid one (an outline icon keeps its screen hole
//          after the rim is added, a solid one with holes goes muddy).
//   lines  the grey lines of a "credits" slide.
//
// Everything said here is true of this shell: the phone is the Quick Panel +
// launcher + wallpapers + overview + settings (QuickPanel.qml, `ipc call phone`),
// the unit themes are ThemeService.baseGroups, Edit Desktop is in Settings >
// Desktop, and `ipc call welcome show` is WelcomeService.qml.

var SLIDES = [
    {
        kind: "logo",
        title: "Welcome to SekaiPop,\nyour Project SEKAI desktop",
        sub: "",
        top: true,
        ghost: true
    },
    {
        kind: "glyph",
        glyph: "phone_iphone",
        glyphFill: 0,
        title: "The Phone",
        sub: "Quick settings, apps, wallpapers and overview\nare all screens of one phone",
        top: false,
        ghost: false
    },
    {
        kind: "units",
        title: "Pick Your Unit",
        sub: "Six unit themes, or let matugen follow your wallpaper",
        top: false,
        ghost: false
    },
    {
        kind: "frame",
        title: "Make It Yours",
        sub: "Move the bar, dock and widgets in Edit Desktop",
        top: false,
        ghost: false
    },
    {
        kind: "credits",
        title: "You're All Set!",
        lines: [
            "Open the phone: qs -c sekaipop ipc call phone toggle",
            "Settings and themes are on the phone",
            "See this again: qs -c sekaipop ipc call welcome show"
        ],
        top: false,
        ghost: true
    }
];

// How long each kind of hero takes to come in, in ms (the page animates one
// 0..1 number over this long; the hero spreads its own parts across it).
//
// The reference video is a sped-up breakdown (its logo is built in about a
// second), which is too quick to enjoy on a welcome screen. So the logo takes
// 2.8 s here: a letter every ~175 ms, each one popping on its own and building
// its own layers (outline, extrusion, halftone, shine), then the stroke grows
// round them and the sparkles come last (WelcomeMath.js has how
// the run is shared out). Every other hero lands in well under a second, on
// the spring in WelcomeMath.js (about 0.6 s).
var HERO_MS = { logo: 3200, glyph: 650, units: 650, frame: 650, credits: 1 };

// How long a hero takes to go out, in ms. The logo's exit is a collapse into its
// own middle, letter by letter (WelcomeMath.js LOGO_LEAVE_MS); the others just
// blur and fade away, quickly.
var LEAVE_MS = { logo: 560 };

function leaveMs(kind) {
    return LEAVE_MS[kind] !== undefined ? LEAVE_MS[kind] : 180;
}

// Where a hero starts from, as it lands (the video's slides all arrive from
// small, low and tilted, or opening up from a thin line):
//   scale   starting size (1 = full size)
//   openY   starting height, as a fraction of its own (the band and the picture
//           open up from a line; everything else keeps its shape)
//   rotate  starting tilt, in degrees
//   rise    how far below its place it starts, in design units
//   rate    how quickly it springs (1 = the icons' pace)
//
// The logo has no pose of its own: its letters do the popping (WelcomePopLetter
// .qml), so the logo as a whole stays at full size, in place and sharp.
var HERO_POSE = {
    logo:    { scale: 1,    openY: 1,    rotate: 0,  rise: 0,  rate: 1 },
    glyph:   { scale: 0.58, openY: 0.58, rotate: 12, rise: 44, rate: 1 },
    units:   { scale: 1,    openY: 0.08, rotate: 0,  rise: 0,  rate: 1 },
    frame:   { scale: 1,    openY: 0.12, rotate: 0,  rise: 26, rate: 1 },
    credits: { scale: 1,    openY: 1,    rotate: 0,  rise: 0,  rate: 1 }
};

function heroPose(kind) {
    return HERO_POSE[kind] !== undefined ? HERO_POSE[kind] : HERO_POSE.glyph;
}

function heroMs(kind) {
    return HERO_MS[kind] !== undefined ? HERO_MS[kind] : 700;
}

// The grey text under a slide's title: its `sub`, or the lines of a credits slide.
function subOf(slide) {
    if (!slide)
        return "";
    if (slide.lines && slide.lines.length > 0)
        return slide.lines.join("\n");
    return slide.sub || "";
}

// Where the middle of the hero sits, as a fraction of the screen's height. The
// numbers follow the reference video (page 768 tall), with the logo lower to leave room for its kana line and sparkles: the logo at 52%, a
// full-width band or a framed picture at 50%.
function heroCenter(kind) {
    return kind === "glyph" ? 0.47 : (kind === "logo" ? 0.52 : 0.5);
}
