// Continuous internal state: five drives plus alertness, boredom, mood and
// happiness. Everything integrates against real elapsed seconds (dt), so
// timer cadence never changes behavior tuning.
//
// Rough timescales (personality shifts these):
//   restDrive:   builds over 2-7h awake, drains over 4-6h of sleeping
//   alertness:   fades over 5-13h awake (faster at night), recovers over a
//                night's sleep — a real day/night arc, with lazy pets adding
//                siestas on top
//   explore:     reaches "itchy feet" in 20-60min, relieved by journeys
//   social:      builds over 30-90min, relieved by petting / pet interactions
//   play:        builds over 20-60min of alert time, discharged by play states
//   boredom:     ~30min of nothing-happening, reset by events and arrivals
//   mood:        fast valence, relaxes toward happiness in ~10min
//   happiness:   slow baseline, relaxes toward 0.45 over hours

function clamp01(v) { return Math.max(0, Math.min(1, v)); }

function _relax(current, target, dt, tau) {
    return current + (target - current) * (1 - Math.exp(-dt / tau));
}

function integrate(pet, perc, dt) {
    var p = pet.personality;
    var s = pet.state_;
    var resting = s === "sit" || s === "deepsleep";
    var deep = s === "deepsleep";
    var moving = s === "walk" || s === "wander" || s === "zoomies";
    var playing = s === "zoomies" || s === "attack" || s === "hop" || s === "shoot" || s === "charge";

    // --- rest ---
    if (resting) {
        // sleepy pets nap longer: their rest need drains slower
        var drain = (0.00007 - p.sleepiness * 0.00003) * (deep ? 1.3 : 1);
        pet.restDrive = clamp01(pet.restDrive - drain * dt);
    } else {
        var build = 0.00004 + p.sleepiness * 0.00008;
        if (perc.isNight) build *= 1.8;
        if (perc.systemBusy) build *= 1.2;
        if (moving) build *= 1.3;
        pet.restDrive = clamp01(pet.restDrive + build * dt);
    }

    // --- alertness ---
    if (resting) {
        // recovery takes most of a night's sleep, so waking feels earned,
        // not like a timer going off
        var recover = (0.00005 + p.energy * 0.00005) * (deep ? 1.5 : 1);
        pet.alertness = clamp01(pet.alertness + recover * dt);
    } else {
        var fade = 0.00002 + (1 - p.energy) * 0.00004;
        if (perc.isNight) fade *= 2.5;
        pet.alertness = clamp01(pet.alertness - fade * dt);
    }

    // --- explore ---
    if (moving) {
        pet.exploreDrive = clamp01(pet.exploreDrive - 0.0005 * dt);
    } else if (resting) {
        pet.exploreDrive = clamp01(pet.exploreDrive - 0.0001 * dt);
    } else {
        var er = 0.0001 + p.curiosity * 0.00025;
        er *= 0.3 + pet.alertness * 0.7;
        if (perc.windowCount > 3) er *= 1.3;
        if (perc.userBusy) er *= 1.5;   // user's busy, pet entertains itself
        pet.exploreDrive = clamp01(pet.exploreDrive + er * dt);
    }

    // --- social ---
    if (resting) {
        pet.socialDrive = clamp01(pet.socialDrive - 0.00005 * dt);
    } else {
        var sr = (0.00008 + p.sociability * 0.0003);
        if ((perc.hour >= 7 && perc.hour <= 10) || (perc.hour >= 18 && perc.hour <= 22)) sr *= 1.3;
        pet.socialDrive = clamp01(pet.socialDrive + sr * dt);
    }
    // company is quietly satisfying
    if (perc.nearest && perc.nearest.dist < 250)
        pet.socialDrive = clamp01(pet.socialDrive - 0.0002 * (0.5 + perc.nearest.affinity) * dt);

    // --- play ---
    if (playing) {
        pet.playDrive = clamp01(pet.playDrive - 0.004 * dt);
    } else {
        var pr = 0.00006 + p.playfulness * 0.0003;
        pr *= 0.2 + pet.alertness * 0.8;
        if (pet.happiness > 0.6) pr *= 1.4;
        pet.playDrive = clamp01(pet.playDrive + pr * dt);
    }

    // --- boredom ---
    if (resting) {
        pet.boredom = clamp01(pet.boredom - 0.0005 * dt);
    } else {
        pet.boredom = clamp01(pet.boredom + 0.00025 * (0.5 + p.energy * 0.8) * dt);
    }

    // --- comfort (homesickness), fast-tracking toward current need ---
    var homeNeed = clamp01((perc.distFromHome - 250) / 600) * (1 - p.boldness * 0.6);
    if (perc.fullscreen)
        homeNeed = Math.max(homeNeed, 0.35 + (1 - p.boldness) * 0.4);
    homeNeed += (1 - pet.alertness) * 0.1 * (1 - p.boldness);
    pet.comfortDrive = clamp01(_relax(pet.comfortDrive, homeNeed, dt, 45));

    // --- mood and happiness ---
    pet.mood = clamp01(_relax(pet.mood, pet.happiness, dt, 600));
    pet.happiness = clamp01(_relax(pet.happiness, 0.45, dt, 14400));
    if (perc.atHome && resting)
        pet.happiness = clamp01(pet.happiness + 0.00004 * (1 + p.patience) * dt);
}

// Sudden arousal from an event: perks the pet up and piques interest.
function stimulate(pet, amount) {
    pet.alertness = clamp01(pet.alertness + amount);
    pet.exploreDrive = clamp01(pet.exploreDrive + amount * 0.3);
    pet.playDrive = clamp01(pet.playDrive + amount * 0.15);
    pet.boredom = clamp01(pet.boredom - amount);
}

// Something happened; life is less boring.
function eventful(pet, amount) {
    pet.boredom = clamp01(pet.boredom - amount);
}

// Joy with diminishing returns: an already-content pet barely notices one more
// treat, so happiness settles into a band instead of pinning at 1.0.
function happier(pet, amount) {
    pet.happiness = clamp01(pet.happiness + amount * (1 - pet.happiness));
}
