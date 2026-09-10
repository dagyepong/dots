.import "Memory.js" as Memory

// Builds the pet's view of the world for one decision. All positions are in
// global (multi-monitor) coordinates unless suffixed "local".

var NEARBY_PET_DIST = 6000; // pets sense each other across monitors

function perceive(pet) {
    var now = Date.now();
    var sx = pet.screenX(), sy = pet.screenY();
    var sw = pet.screenW(), sh = pet.screenH();
    var petGX = sx + pet.worldX;
    var petGY = sy + pet.worldY;

    // --- active window ---
    var wp = pet.windowTracker.activeWindowPos;
    var win = null;
    if (wp) {
        var cx = wp.x + wp.w / 2, cy = wp.y + wp.h / 2;
        var lx = cx - sx, ly = cy - sy;
        win = {
            gx: cx, gy: cy, w: wp.w, h: wp.h,
            top: wp.y, bottom: wp.y + wp.h,
            cls: pet.windowTracker.activeWindowClass,
            title: pet.windowTracker.activeWindowTitle,
            localX: lx, localY: ly,
            onMyScreen: lx > 50 && lx < sw - 50 && ly > 50 && ly < sh - 50,
            dist: Math.sqrt((cx - petGX) * (cx - petGX) + (cy - petGY) * (cy - petGY)),
        };
    }

    // --- cursor ---
    var cgx = pet.inputTracker.cursorX, cgy = pet.inputTracker.cursorY;
    var cursor = {
        gx: cgx, gy: cgy,
        localX: cgx - sx, localY: cgy - sy,
        onMyScreen: cgx >= sx && cgx < sx + sw && cgy >= sy && cgy < sy + sh,
        dist: Math.sqrt((cgx - petGX) * (cgx - petGX) + (cgy - petGY) * (cgy - petGY)),
        active: pet.inputTracker.userActive,
    };

    // --- other pets ---
    var others = [];
    var allPets = pet.petManager.pets;
    for (var i = 0; i < allPets.length; i++) {
        var o = allPets[i];
        if (o === pet) continue;
        var ogx = o.screenX() + o.worldX;
        var ogy = o.screenY() + o.worldY;
        var dx = ogx - petGX, dy = ogy - petGY;
        var dist = Math.sqrt(dx * dx + dy * dy);
        if (dist > NEARBY_PET_DIST) continue;
        var rel = Memory.relationWith(pet, o.petData.name, o.personality);
        others.push({
            pet: o,
            name: o.petData.name,
            gx: ogx, gy: ogy,
            dist: dist,
            state: o.state_,
            resting: o.state_ === "sit" || o.state_ === "deepsleep",
            playing: o.state_ === "zoomies" || (o.intention && o.intention.name === "play_with"),
            sameScreen: o.screenX() === sx && o.screenY() === sy,
            affinity: rel.affinity,
            familiarity: rel.familiarity,
            sinceInteract: now - rel.lastInteract,
        });
    }
    others.sort(function(a, b) { return a.dist - b.dist; });

    var dHome = Math.sqrt((petGX - pet.homeGX) * (petGX - pet.homeGX)
                        + (petGY - pet.homeGY) * (petGY - pet.homeGY));

    return {
        now: now,
        hour: pet._hour,
        isNight: pet.isNighttime,
        systemBusy: pet.systemMonitor.isUnderLoad,
        userBusy: pet.windowTracker.isUserBusy,
        userIdle: !pet.inputTracker.userActive,
        windowCount: pet.windowTracker.windowCount,
        fullscreen: pet.windowTracker.isFullscreen,
        win: win,
        cursor: cursor,
        petGX: petGX, petGY: petGY,
        screen: { x: sx, y: sy, w: sw, h: sh },
        distFromHome: dHome,
        atHome: dHome < pet.homeRadius,
        others: others,
        nearest: others.length > 0 ? others[0] : null,
        placeAffectHere: Memory.placeAffectAt(pet, petGX, petGY),
    };
}
