// Pet state persistence. Schema 2 stores positions in global (multi-monitor)
// coordinates; legacy (schema-less) files migrate what still makes sense and
// drop spatial memory that was keyed to screen-local coordinates.

var SCHEMA = 2;

function save(pet) {
    var state = {
        schema: SCHEMA,
        gx: pet.screenX() + pet.worldX,
        gy: pet.screenY() + pet.worldY,
        homeGX: pet.homeGX,
        homeGY: pet.homeGY,
        happiness: pet.happiness,
        mood: pet.mood,
        restDrive: pet.restDrive,
        exploreDrive: pet.exploreDrive,
        socialDrive: pet.socialDrive,
        comfortDrive: pet.comfortDrive,
        playDrive: pet.playDrive,
        alertness: pet.alertness,
        boredom: pet.boredom,
        thoughts: pet.thoughts,
        visitedCells: pet.visitedCells,
        windowPrefs: pet.windowPrefs,
        placeMemory: pet.placeMemory,
        relationships: pet.relationships,
        learnedTraits: pet.learnedTraits,
        userRhythm: pet.userRhythm,
    };
    pet._statePendingJson = JSON.stringify(state, null, 2);
    pet._stateMkdir.running = true;
}

function _onAnyScreen(pet, gx, gy) {
    var screens = pet.allScreens();
    for (var i = 0; i < screens.length; i++) {
        var s = screens[i];
        if (gx >= s.x && gx < s.x + s.width && gy >= s.y && gy < s.y + s.height) return true;
    }
    return false;
}

function load(pet) {
    try {
        var saved = JSON.parse(pet._stateFileView.text());

        if (saved.happiness !== undefined) pet.happiness = saved.happiness;
        if (saved.mood !== undefined) pet.mood = saved.mood;
        if (saved.restDrive !== undefined) pet.restDrive = saved.restDrive;
        if (saved.exploreDrive !== undefined) pet.exploreDrive = saved.exploreDrive;
        if (saved.socialDrive !== undefined) pet.socialDrive = saved.socialDrive;
        if (saved.comfortDrive !== undefined) pet.comfortDrive = saved.comfortDrive;
        if (saved.playDrive !== undefined) pet.playDrive = saved.playDrive;
        if (saved.boredom !== undefined) pet.boredom = saved.boredom;
        if (saved.alertness !== undefined) pet.alertness = saved.alertness + (0.5 - saved.alertness) * 0.5;
        if (saved.thoughts && saved.thoughts.length) pet.thoughts = saved.thoughts;
        if (saved.windowPrefs) pet.windowPrefs = saved.windowPrefs;
        if (saved.relationships) pet.relationships = saved.relationships;
        if (saved.learnedTraits) pet.learnedTraits = saved.learnedTraits;
        else if (saved.traits) pet.learnedTraits = saved.traits;   // legacy name
        if (saved.userRhythm) pet.userRhythm = saved.userRhythm;

        if (saved.schema >= 2) {
            if (saved.visitedCells) pet.visitedCells = saved.visitedCells;
            if (saved.placeMemory) pet.placeMemory = saved.placeMemory;
            if (saved.gx !== undefined && saved.gy !== undefined && pet.petWindow)
                pet.petWindow.moveToGlobal(saved.gx, saved.gy);
            if (saved.homeGX !== undefined && saved.homeGY !== undefined
                    && _onAnyScreen(pet, saved.homeGX, saved.homeGY)) {
                pet.homeGX = saved.homeGX;
                pet.homeGY = saved.homeGY;
            } else {
                pet.homeGX = pet.screenX() + pet.worldX;
                pet.homeGY = pet.screenY() + pet.worldY;
            }
        } else {
            // legacy: x/y and home were screen-local; spatial memory keys were
            // local too, so it starts fresh
            var maxX = pet.screenW() - pet.width, maxY = pet.screenH() - pet.height;
            if (saved.x !== undefined && saved.y !== undefined) {
                pet.worldX = Math.max(0, Math.min(maxX, saved.x));
                pet.worldY = Math.max(0, Math.min(maxY, saved.y));
            }
            if (saved.homeX !== undefined && saved.homeY !== undefined) {
                pet.homeGX = pet.screenX() + Math.max(0, Math.min(maxX, saved.homeX));
                pet.homeGY = pet.screenY() + Math.max(0, Math.min(maxY, saved.homeY));
            }
        }
    } catch (e) {
        console.warn("qs-vpets: failed to load pet state:", e);
    }
}
