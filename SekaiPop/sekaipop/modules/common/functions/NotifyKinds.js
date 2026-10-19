.pragma library

// Which of the five Project SEKAI attribute colours a shell notification's
// badge wears (ShellBadge.qml). A notification that carries a
// "material:<glyph>" icon is one the shell (or one of its scripts) sent
// itself -- a screenshot, a recording, a timer -- as opposed to an app or a
// browser, which send their own icon or none. The glyph name decides the
// colour, so the same kind of event always looks the same:
//
//   0 Cool        screenshots, copy, text recognition, image search
//   1 Cute        recording, errors
//   2 Happy       timers and alarms
//   3 Mysterious  terminal, VPN, music recognition, the odd one out
//   4 Pure        updates, wallpapers, "done"
//
// A glyph that is not listed gets a colour from its name (the same one every
// time), so a script that sends `-i material:anything_it_likes` still gets a
// proper badge without touching this file. Pass the result to
// Theme.attributeColors[...].
var KINDS = {
    // Cool
    photo_camera: 0, screenshot_region: 0, screenshot: 0, content_copy: 0,
    content_paste: 0, image_search: 0, draw: 0, document_scanner: 0,
    text_snippet: 0, colorize: 0,
    // Cute
    videocam: 1, fiber_manual_record: 1, error: 1, warning: 1,
    image_not_supported: 1, report: 1,
    // Happy
    alarm: 2, timer: 2, schedule: 2, notifications: 2, bolt: 2,
    // Mysterious
    terminal: 3, vpn_lock: 3, vpn_key: 3, music_cast: 3, view_carousel: 3,
    memory: 3, extension: 3,
    // Pure
    system_update: 4, check_circle: 4, download: 4, done: 4, wallpaper: 4,
    palette: 4, update: 4
};

function index(glyph) {
    var g = String(glyph === undefined || glyph === null ? "" : glyph);
    if (Object.prototype.hasOwnProperty.call(KINDS, g))
        return KINDS[g];
    var h = 7;
    for (var i = 0; i < g.length; i++)
        h = (h * 31 + g.charCodeAt(i)) % 9973;
    return h % 5;
}
