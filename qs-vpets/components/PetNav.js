.import "ai/Memory.js" as Memory
.import "ai/Brain.js" as Brain

// Navigation in global (multi-monitor) coordinates. A journey aims straight
// at its global target; when the straight line leaves the current screen the
// pet walks off the edge and PetWindow hops it to the adjacent monitor, after
// which the same global target still applies. If a wall blocks the way twice,
// the pet gives up (Brain.onBlocked) — trying and failing is fine, dithering
// forever is not.

var ARRIVAL_TOLERANCE = 60;
var MAX_BLOCKS = 2;

function globalX(pet) { return pet.screenX() + pet.worldX; }
function globalY(pet) { return pet.screenY() + pet.worldY; }

function distToGlobal(pet, gx, gy) {
    var dx = globalX(pet) - gx, dy = globalY(pet) - gy;
    return Math.sqrt(dx * dx + dy * dy);
}

function inHomeArea(pet) {
    return distToGlobal(pet, pet.homeGX, pet.homeGY) < pet.homeRadius;
}

function _setAngle(pet, a) {
    pet.moveAngle = a;
    pet.facingRight = Math.cos(a) >= 0;
    pet.sprite.setDirection(a);
}

function _aimLeg(pet) {
    _setAngle(pet, Math.atan2(pet.targetGY - globalY(pet), pet.targetGX - globalX(pet)));
}

function journeyToGlobal(pet, gx, gy) {
    pet.onJourney = true;
    pet.journeyBlocked = 0;
    pet.targetGX = gx;
    pet.targetGY = gy;
    if (pet.intention) pet.intention.travel = true;
    _aimLeg(pet);
    pet.enterState("walk");
}

function resumeJourney(pet) {
    pet.journeyBlocked = 0;
    _aimLeg(pet);
    pet.enterState("walk");
}

function wanderStart(pet, angle) {
    pet.onJourney = false;
    _setAngle(pet, angle !== undefined ? angle : Math.random() * 2 * Math.PI);
    pet.enterState("wander");
}

function fleeFrom(pet, gx, gy, dist) {
    var away = Math.atan2(globalY(pet) - gy, globalX(pet) - gx);
    away += (Math.random() - 0.5) * 0.6;
    var tx = globalX(pet) + Math.cos(away) * dist;
    var ty = globalY(pet) + Math.sin(away) * dist;
    // keep the flight on the current screen
    var sx = pet.screenX(), sy = pet.screenY();
    tx = Math.max(sx, Math.min(sx + pet.screenW() - pet.width, tx));
    ty = Math.max(sy, Math.min(sy + pet.screenH() - pet.height, ty));
    pet.onJourney = true;
    pet.journeyBlocked = 0;
    pet.targetGX = tx;
    pet.targetGY = ty;
    _aimLeg(pet);
    pet.enterState("walk");
}

function randomDir(pet) {
    _setAngle(pet, Math.random() * 2 * Math.PI);
}

// Called at the end of each walk leg (walkTimer) and on target snap.
function walkArrived(pet) {
    if (!pet.onJourney) {
        Memory.remember(pet, "strolled");
        pet.enterState("idle");
        return;
    }

    // moving goals (cursor, windows, other pets) refresh their target
    if (!Brain.retarget(pet)) {
        pet.onJourney = false;
        Brain.onBlocked(pet);
        return;
    }

    if (distToGlobal(pet, pet.targetGX, pet.targetGY) < ARRIVAL_TOLERANCE) {
        pet.onJourney = false;
        Brain.onArrived(pet);
        return;
    }

    _aimLeg(pet);
    pet.restartWalk();
}

function reflectOffWall(pet, hitX, hitY) {
    var a = pet.moveAngle;
    if (hitX) a = Math.PI - a;
    if (hitY) a = -a;

    if (pet.onJourney) {
        pet.journeyBlocked = (pet.journeyBlocked || 0) + 1;
        // Is the target beyond this wall? Then a straight line can't get there.
        var beyondX = hitX && Math.abs(pet.targetGX - globalX(pet)) > 40
                   && Math.sign(pet.targetGX - globalX(pet)) === Math.sign(Math.cos(pet.moveAngle));
        var beyondY = hitY && Math.abs(pet.targetGY - globalY(pet)) > 40
                   && Math.sign(pet.targetGY - globalY(pet)) === Math.sign(Math.sin(pet.moveAngle));
        if (pet.journeyBlocked > MAX_BLOCKS || beyondX || beyondY) {
            pet.onJourney = false;
            Brain.onBlocked(pet);
            return;
        }
    }
    _setAngle(pet, a);
}
