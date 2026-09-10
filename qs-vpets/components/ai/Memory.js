.import "Personality.js" as Personality

// Episodic thoughts, spatial memory (global coordinates), window preferences,
// and relationships with other pets. Everything here decays; nothing is
// permanent except what keeps getting reinforced.

var VISITED_CELL_SIZE = 200;
var PLACE_CELL_SIZE = 400;
var THOUGHTS_LIMIT = 250;
var FAVORITE_AFFECT_MIN = 0.2;
var FAVORITE_VISITS_MIN = 2;
var AVOID_AFFECT_MAX = -0.3;
var PETTED_WINDOW_MS = 30000;
var WOKE_WINDOW_MS = 45000;
var CELL_DECAY_CHANCE = 0.15;
var PREF_DECAY_TO_NEUTRAL = 0.02;
var PLACE_DECAY = 0.995;
var PLACE_PURGE_AFFECT = 0.02;
var PLACE_PURGE_CHANCE = 0.05;
var REL_AFFINITY_DECAY = 0.999;  // per decay pass, toward 0.5
var RECENT_DEFAULT_MS = 30000;

function remember(pet, type, data) {
    var thought = {
        type: type,
        time: Date.now(),
        x: Math.round(pet.screenX() + pet.worldX),
        y: Math.round(pet.screenY() + pet.worldY),
        state: pet.state_,
        mood: Math.round(pet.mood * 100) / 100,
        drives: {
            rest: Math.round(pet.restDrive * 100) / 100,
            explore: Math.round(pet.exploreDrive * 100) / 100,
            social: Math.round(pet.socialDrive * 100) / 100,
            play: Math.round(pet.playDrive * 100) / 100,
        },
    };
    if (data) {
        var keys = Object.keys(data);
        for (var i = 0; i < keys.length; i++) thought[keys[i]] = data[keys[i]];
    }
    pet.thoughts.push(thought);
    if (pet.thoughts.length > THOUGHTS_LIMIT) pet.thoughts.shift();
}

function recent(pet, type, withinMs) {
    var cutoff = Date.now() - (withinMs || RECENT_DEFAULT_MS);
    for (var i = pet.thoughts.length - 1; i >= 0; i--) {
        if (pet.thoughts[i].time <= cutoff) return null;
        if (pet.thoughts[i].type === type) return pet.thoughts[i];
    }
    return null;
}

function wasRecentlyPetted(pet) { return !!recent(pet, "petted", PETTED_WINDOW_MS); }
function justWokeUp(pet) { return !!recent(pet, "well_rested", WOKE_WINDOW_MS); }

// --- window preferences ---

function windowFamiliarity(pet, cls) {
    var n = 0;
    for (var i = 0; i < pet.thoughts.length; i++)
        if (pet.thoughts[i].windowClass === cls) n++;
    return n;
}

function recordWindowPref(pet, cls, delta) {
    if (!cls) return;
    var cur = pet.windowPrefs[cls] !== undefined ? pet.windowPrefs[cls] : 0.5;
    pet.windowPrefs[cls] = Math.max(0, Math.min(1, cur + delta));
}

function getWindowPref(pet, cls) {
    if (!cls) return 0.5;
    return pet.windowPrefs[cls] !== undefined ? pet.windowPrefs[cls] : 0.5;
}

// --- spatial memory (global coordinates) ---

function _cellKey(x, y, size) {
    return Math.floor(x / size) + "," + Math.floor(y / size);
}

function trackPosition(pet) {
    if (pet.state_ !== "walk" && pet.state_ !== "wander" && pet.state_ !== "zoomies") return;
    var now = Date.now();
    if (now - (pet._lastTrackTime || 0) < 5000) return;
    pet._lastTrackTime = now;
    var key = _cellKey(pet.screenX() + pet.worldX, pet.screenY() + pet.worldY, VISITED_CELL_SIZE);
    pet.visitedCells[key] = (pet.visitedCells[key] || 0) + 1;
}

function visitsAt(pet, gx, gy) {
    return pet.visitedCells[_cellKey(gx, gy, VISITED_CELL_SIZE)] || 0;
}

// Pick an exploration target: sample points across all screens, prefer
// less-visited cells that aren't dreaded, discount far-away ones a little.
// This is what makes pets organically roam onto other monitors.
function explorationTarget(pet) {
    var screens = pet.allScreens();
    if (!screens || screens.length === 0) return null;
    var gx = pet.screenX() + pet.worldX, gy = pet.screenY() + pet.worldY;
    var margin = 60;
    var best = null, bestScore = -Infinity;
    var samples = 7;
    for (var i = 0; i < samples; i++) {
        var s = screens[Math.floor(Math.random() * screens.length)];
        var tx = s.x + margin + Math.random() * Math.max(1, s.width - margin * 2);
        var ty = s.y + margin + Math.random() * Math.max(1, s.height - margin * 2);
        var visits = visitsAt(pet, tx, ty);
        var dist = Math.sqrt((tx - gx) * (tx - gx) + (ty - gy) * (ty - gy));
        if (dist < 150) continue;
        var affect = placeAffectAt(pet, tx, ty);
        if (affect < AVOID_AFFECT_MAX && Math.random() < 0.8) continue;
        var score = -visits - dist / 2500 + affect * 2 + Math.random() * 1.5;
        if (score > bestScore) {
            bestScore = score;
            best = { gx: tx, gy: ty, visits: visits, otherScreen: s.x !== pet.screenX() || s.y !== pet.screenY() };
        }
    }
    return best;
}

function decayPreferences(pet) {
    var prefKeys = Object.keys(pet.windowPrefs);
    for (var i = 0; i < prefKeys.length; i++) {
        var v = pet.windowPrefs[prefKeys[i]];
        pet.windowPrefs[prefKeys[i]] = v + (0.5 - v) * PREF_DECAY_TO_NEUTRAL;
    }
    var cellKeys = Object.keys(pet.visitedCells);
    for (var j = 0; j < cellKeys.length; j++) {
        if (Math.random() < CELL_DECAY_CHANCE) {
            if (--pet.visitedCells[cellKeys[j]] <= 0) delete pet.visitedCells[cellKeys[j]];
        }
    }
}

// --- place affect (emotional memory of locations, global coords) ---

function recordPlaceAffect(pet, valence) {
    if (!pet.placeMemory) pet.placeMemory = ({});
    var key = _cellKey(pet.screenX() + pet.worldX, pet.screenY() + pet.worldY, PLACE_CELL_SIZE);
    var e = pet.placeMemory[key] || { affect: 0, visits: 0, lastVisit: 0 };
    var weight = Math.min(0.3, 1.0 / (e.visits + 2));
    e.affect = e.affect * (1 - weight) + valence * weight;
    e.visits++;
    e.lastVisit = Date.now();
    pet.placeMemory[key] = e;
}

function placeAffectAt(pet, gx, gy) {
    if (!pet.placeMemory) return 0;
    var e = pet.placeMemory[_cellKey(gx, gy, PLACE_CELL_SIZE)];
    return e ? e.affect : 0;
}

function favoriteSpot(pet) {
    if (!pet.placeMemory) return null;
    var best = null, bestScore = FAVORITE_AFFECT_MIN;
    var keys = Object.keys(pet.placeMemory);
    for (var i = 0; i < keys.length; i++) {
        var e = pet.placeMemory[keys[i]];
        if (e.affect > bestScore && e.visits >= FAVORITE_VISITS_MIN) {
            bestScore = e.affect;
            var parts = keys[i].split(",");
            var half = PLACE_CELL_SIZE / 2;
            best = {
                gx: parseInt(parts[0]) * PLACE_CELL_SIZE + half,
                gy: parseInt(parts[1]) * PLACE_CELL_SIZE + half,
                affect: e.affect,
            };
        }
    }
    return best;
}

function decayPlaceMemory(pet) {
    if (!pet.placeMemory) return;
    var keys = Object.keys(pet.placeMemory);
    for (var i = 0; i < keys.length; i++) {
        var e = pet.placeMemory[keys[i]];
        e.affect *= PLACE_DECAY;
        if (Math.abs(e.affect) < PLACE_PURGE_AFFECT && Math.random() < PLACE_PURGE_CHANCE)
            delete pet.placeMemory[keys[i]];
    }
}

// --- learned user rhythm ---
//
// A 24-bucket EWMA of "was the user at the keyboard this hour". Converges over
// a few days, so pets slowly learn the user's schedule: they sink into deeper
// sleep during hours the user is reliably away and stay lighter when the user
// tends to be around.

var RHYTHM_ALPHA = 0.005;   // per ~5s observation; time constant of a few days

function observeUser(pet, perc) {
    if (!pet.userRhythm) pet.userRhythm = ({});
    var cur = pet.userRhythm[perc.hour] !== undefined ? pet.userRhythm[perc.hour] : 0.5;
    pet.userRhythm[perc.hour] = cur + ((perc.userIdle ? 0 : 1) - cur) * RHYTHM_ALPHA;
}

// 0..1, defaults to 0.5 until the pet has lived here a while
function usualUserActivity(pet, hour) {
    if (!pet.userRhythm) return 0.5;
    var v = pet.userRhythm[hour];
    return v !== undefined ? v : 0.5;
}

// --- relationships with other pets ---

// Returns the relationship record for another pet, creating it lazily.
// otherPersonality (optional) seeds first impressions from compatibility.
function relationWith(pet, name, otherPersonality) {
    if (!pet.relationships) pet.relationships = ({});
    var r = pet.relationships[name];
    if (!r) {
        var prior = 0.5;
        if (otherPersonality)
            prior = 0.5 + Personality.compatibility(pet.personality, otherPersonality) * 0.15;
        r = { affinity: prior, familiarity: 0, lastInteract: 0 };
        pet.relationships[name] = r;
    }
    return r;
}

function adjustRelation(pet, name, affinityDelta, familiarityDelta) {
    var r = relationWith(pet, name);
    r.affinity = Math.max(0, Math.min(1, r.affinity + affinityDelta));
    r.familiarity = Math.max(0, Math.min(1, r.familiarity + (familiarityDelta || 0)));
    r.lastInteract = Date.now();
}

function decayRelationships(pet) {
    if (!pet.relationships) return;
    var keys = Object.keys(pet.relationships);
    for (var i = 0; i < keys.length; i++) {
        var r = pet.relationships[keys[i]];
        r.affinity = 0.5 + (r.affinity - 0.5) * REL_AFFINITY_DECAY;
        r.familiarity *= 0.9995;
    }
}
