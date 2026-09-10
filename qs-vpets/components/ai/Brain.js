.import "Perception.js" as Perception
.import "Drives.js" as Drives
.import "Memory.js" as Memory
.import "Social.js" as Social

// Utility-based decision engine. Every think tick the pet generates candidate
// actions from what it perceives, scores each from drives x personality x
// context x memory, and picks stochastically among the best (softmax). There
// are no scripted behaviors: a shy pet hides from fullscreen because low
// boldness inflates comfort, a playful pair chases each other because both
// keep scoring "play_with" highest. Intentions add commitment (hysteresis) so
// pets follow through instead of dithering.
//
// Pacing matters as much as choice: rest ticks consolidate naps into
// hours-long sleep, and a post-action "settled" period keeps pets from
// chaining actions back to back — alive, not busy.

var COMMIT_BONUS = 0.22;
var SCORE_NOISE = 0.12;
var CANDIDATE_WINDOW = 0.5;   // candidates further than this below max are dropped

// ---------------------------------------------------------------------------
// think: the main decision tick (called while idle)
// ---------------------------------------------------------------------------

function think(pet, nav) {
    if (pet.intention && Date.now() > pet.intention.until) clearIntention(pet);

    // A journey interrupted by a reaction resumes if the goal still stands.
    if (pet.onJourney) {
        if (pet.intention && pet.intention.travel && retarget(pet)) {
            nav.resumeJourney(pet);
            return;
        }
        pet.onJourney = false;
        clearIntention(pet);
    }

    var perc = Perception.perceive(pet);
    var cands = _candidates(pet, perc, nav);
    if (cands.length === 0) { pet.restartIdle(); return; }

    var choice = _softmaxPick(pet, cands);
    if (!choice) { pet.restartIdle(); return; }
    choice.exec();
}

function _softmaxPick(pet, cands) {
    var max = -Infinity;
    var committed = pet.intention && Date.now() < pet.intention.until;
    for (var i = 0; i < cands.length; i++) {
        cands[i].score += (Math.random() - 0.5) * SCORE_NOISE;
        if (committed && cands[i].name === pet.intention.name
                && cands[i].otherName === pet.intention.otherName)
            cands[i].score += COMMIT_BONUS;
        if (cands[i].score > max) max = cands[i].score;
    }
    var temp = 0.10 + (1 - pet.personality.patience) * 0.06;
    var total = 0, weights = [];
    for (var j = 0; j < cands.length; j++) {
        var d = cands[j].score - max;
        var w = d < -CANDIDATE_WINDOW ? 0 : Math.exp(d / temp);
        weights.push(w);
        total += w;
    }
    var r = Math.random() * total;
    for (var k = 0; k < cands.length; k++) {
        r -= weights[k];
        if (r <= 0) return cands[k];
    }
    return cands[cands.length - 1];
}

function _intend(pet, name, urgency, opts) {
    pet.intention = {
        name: name,
        urgency: Math.max(0, Math.min(1, urgency)),
        started: Date.now(),
        until: Date.now() + ((opts && opts.durationMs) || 120000),
        otherName: (opts && opts.otherName) || undefined,
        reason: (opts && opts.reason) || name,
    };
}

function clearIntention(pet) { pet.intention = null; }

// ---------------------------------------------------------------------------
// candidate generation
// ---------------------------------------------------------------------------

function _distCost(pet, dist) {
    return (dist / 2200) * (1.1 - pet.personality.energy * 0.5);
}

function _candidates(pet, perc, nav) {
    var p = pet.personality;
    var cands = [];
    var justWoke = Memory.justWokeUp(pet);
    var settled = Date.now() < (pet.calmUntil || 0);
    var quietHour = 1 - Memory.usualUserActivity(pet, perc.hour);
    var active = Math.max(0.3, 1 - (Math.max(0, p.sleepiness - 0.5) * 0.6 + (1 - p.energy) * 0.2));
    var nightMult = perc.isNight ? (0.45 + p.energy * 0.25) : 1;
    var fsCalm = perc.fullscreen ? 0.5 : 1;   // lay low during fullscreen
    var boredomBoost = 1 + pet.boredom * 0.8;
    var moodMult = 0.6 + pet.mood * 0.8;

    // --- do nothing, watch the world (the default that real needs must beat) ---
    cands.push({
        name: "idle_watch",
        score: 0.38 + p.patience * 0.18 - pet.boredom * 0.2
             + (justWoke ? 0.2 : 0) + (settled ? 0.25 : 0),
        exec: function() {
            _attendToSomething(pet, perc);
            pet.restartIdle(1.5 + p.patience);
        },
    });

    // --- rest here ---
    // a wide-awake pet doesn't nap no matter how comfy: waiting for alertness
    // to sag gives the day its awake/asleep rhythm instead of constant dozing
    if ((pet.restDrive > 0.35 && pet.alertness < 0.7) || pet.alertness < 0.15) {
        // alertness pushes back symmetrically with restTick's stay-asleep
        // pressure, so a freshly woken pet doesn't flop straight back down
        var restScore = pet.restDrive * (0.7 + p.sleepiness * 0.9)
                      + (1 - pet.alertness) * 0.35 - pet.alertness * 0.25
                      + perc.placeAffectHere * 0.3
                      + (perc.atHome ? 0.1 : 0);
        if (perc.isNight) restScore *= 1.35;
        // quiet hours (user reliably away, learned over days) invite sleep
        restScore *= 1 + (quietHour - 0.5) * 0.5;
        if (justWoke) restScore *= 0.2;
        cands.push({
            name: "rest",
            score: restScore,
            exec: function() {
                _intend(pet, "rest", pet.restDrive, { durationMs: 300000, reason: "tired" });
                var deep = pet.restDrive > 0.75 || (perc.isNight && pet.restDrive > 0.5);
                Memory.remember(pet, "resting");
                pet.enterState(deep ? "deepsleep" : "sit");
            },
        });

        // --- or trek home to rest ---
        if (!perc.atHome && pet.restDrive > 0.4) {
            cands.push({
                name: "go_home_rest",
                score: restScore * 0.85 + pet.comfortDrive * 0.3 - _distCost(pet, perc.distFromHome),
                exec: function() {
                    _intend(pet, "go_home_rest", Math.max(pet.restDrive, pet.comfortDrive),
                            { reason: "sleepy, heading home" });
                    Memory.remember(pet, "heading_home");
                    nav.journeyToGlobal(pet, pet.homeGX, pet.homeGY);
                },
            });
        }
    }

    // --- homesick ---
    if (!perc.atHome && pet.comfortDrive > 0.3) {
        cands.push({
            name: "go_home",
            score: pet.comfortDrive * (1.15 - p.boldness * 0.5)
                 - _distCost(pet, perc.distFromHome) * 0.5
                 + (perc.isNight ? 0.15 : 0),
            exec: function() {
                _intend(pet, "go_home", pet.comfortDrive, { reason: "homesick" });
                Memory.remember(pet, "homesick");
                nav.journeyToGlobal(pet, pet.homeGX, pet.homeGY);
            },
        });
    }

    // --- exploration ---
    if (pet.alertness > 0.3 && pet.exploreDrive > 0.25 && !justWoke) {
        var target = Memory.explorationTarget(pet);
        if (target && pet.exploreDrive > 0.3) {
            cands.push({
                name: "adventure",
                score: pet.exploreDrive * (0.55 + p.curiosity * 0.7)
                     * active * nightMult * fsCalm * boredomBoost
                     + (target.visits === 0 ? 0.12 : 0)
                     + (target.otherScreen ? p.boldness * 0.12 : 0)
                     - _distCost(pet, Math.sqrt(Math.pow(target.gx - perc.petGX, 2)
                                              + Math.pow(target.gy - perc.petGY, 2))) * 0.5,
                exec: function() {
                    _intend(pet, "adventure", pet.exploreDrive, { reason: "exploring" });
                    Memory.remember(pet, "adventure");
                    nav.journeyToGlobal(pet, target.gx, target.gy);
                },
            });
        }
        cands.push({
            name: "wander",
            score: pet.exploreDrive * (0.35 + p.curiosity * 0.3) * active * nightMult * fsCalm
                 + pet.boredom * 0.15,
            exec: function() {
                nav.wanderStart(pet, target ? Math.atan2(target.gy - perc.petGY, target.gx - perc.petGX)
                                            : undefined);
            },
        });
    }

    // --- investigate the user's window ---
    if (perc.win && !perc.fullscreen && pet.alertness > 0.35 && !justWoke) {
        var cls = perc.win.cls;
        var pref = Memory.getWindowPref(pet, cls);
        var novelty = 1 / (1 + Memory.windowFamiliarity(pet, cls) * 0.15);
        var invScore = pet.exploreDrive * (0.4 + p.curiosity * 0.8)
                     * (0.5 + pref * 0.6) * (0.6 + novelty * 0.6)
                     * active * nightMult
                     - _distCost(pet, perc.win.dist);
        if (Memory.recent(pet, "investigated", 180000)) invScore *= 0.3;
        cands.push({
            name: "investigate",
            score: invScore,
            exec: function() {
                _intend(pet, "investigate", pet.exploreDrive, { reason: "curious about " + cls });
                nav.journeyToGlobal(pet, perc.win.gx, Math.min(perc.win.bottom - 10,
                                    perc.screen.y + perc.screen.h - pet.height));
            },
        });
    }

    // --- watch fullscreen content from a polite distance ---
    if (perc.fullscreen && perc.win && p.curiosity > 0.35 && pet.alertness > 0.35) {
        var corner = _quietCornerNear(pet, perc);
        cands.push({
            name: "watch_fullscreen",
            score: pet.exploreDrive * p.curiosity * 0.75 * (0.6 + p.patience * 0.4)
                 - _distCost(pet, Math.sqrt(Math.pow(corner.gx - perc.petGX, 2)
                                          + Math.pow(corner.gy - perc.petGY, 2))),
            exec: function() {
                _intend(pet, "watch_fullscreen", 0.5, { durationMs: 240000, reason: "watching" });
                Memory.remember(pet, "watching_fullscreen");
                nav.journeyToGlobal(pet, corner.gx, corner.gy);
            },
        });
    }

    // --- seek the user ---
    if (pet.socialDrive > 0.3 && !justWoke) {
        if (perc.cursor.active && perc.cursor.dist > 150) {
            cands.push({
                name: "follow_cursor",
                score: pet.socialDrive * (0.5 + p.sociability * 0.9)
                     * moodMult * active * nightMult * fsCalm
                     * (0.4 + p.boldness * 0.7)
                     - _distCost(pet, perc.cursor.dist)
                     + (Memory.wasRecentlyPetted(pet) ? 0.15 : 0),
                exec: function() {
                    _intend(pet, "follow_cursor", pet.socialDrive, { reason: "following the user" });
                    nav.journeyToGlobal(pet, perc.cursor.gx, perc.cursor.gy);
                },
            });
        }
        if (perc.win && perc.win.dist > 200 && !perc.fullscreen) {
            cands.push({
                name: "be_near_user",
                score: pet.socialDrive * (0.45 + p.sociability * 0.8) * moodMult * active * nightMult
                     + (Memory.getWindowPref(pet, perc.win.cls) - 0.5) * 0.3
                     - _distCost(pet, perc.win.dist),
                exec: function() {
                    _intend(pet, "be_near_user", pet.socialDrive, { reason: "wants company" });
                    nav.journeyToGlobal(pet, perc.win.gx, Math.min(perc.win.bottom - 10,
                                        perc.screen.y + perc.screen.h - pet.height));
                },
            });
        }
        var spot = Memory.favoriteSpot(pet);
        if (spot) {
            var dSpot = Math.sqrt(Math.pow(spot.gx - perc.petGX, 2) + Math.pow(spot.gy - perc.petGY, 2));
            if (dSpot > 200) {
                cands.push({
                    name: "revisit_spot",
                    score: (pet.socialDrive * 0.3 + pet.comfortDrive * 0.3 + (1 - pet.mood) * 0.25)
                         * (0.4 + spot.affect) - _distCost(pet, dSpot),
                    exec: function() {
                        _intend(pet, "revisit_spot", 0.4, { reason: "good memories there" });
                        nav.journeyToGlobal(pet, spot.gx, spot.gy);
                    },
                });
            }
        }
    }

    // --- play ---
    if (pet.playDrive > 0.35 && pet.alertness > 0.35 && !justWoke) {
        var soloScore = pet.playDrive * (0.5 + p.playfulness * 0.8)
                      * moodMult * active * fsCalm * nightMult;
        // a refractory keeps play in bursts with real pauses between
        if (Memory.recent(pet, "played_solo", 180000)) soloScore *= 0.3;
        cands.push({
            name: "play_solo",
            score: soloScore,
            exec: function() {
                _intend(pet, "play_solo", pet.playDrive, { durationMs: 40000, reason: "playing" });
                pet.playDrive = Math.max(0, pet.playDrive - 0.08);
                Memory.remember(pet, "played_solo");
                pet.enterState(_pick(pet, _playPool(pet)));
            },
        });
        if (pet.playDrive > 0.6 && pet.alertness > 0.5) {
            cands.push({
                name: "zoomies",
                score: Math.pow(pet.playDrive, 1.5) * (0.4 + p.playfulness * 0.8)
                     * (0.3 + p.energy * 0.7) * moodMult * boredomBoost
                     * (perc.fullscreen ? 0.4 : 1) * (perc.isNight ? 0.4 : 1) - 0.1,
                exec: function() {
                    _intend(pet, "zoomies", 0.9, { durationMs: 20000, reason: "zoomies!" });
                    Memory.remember(pet, "zoomies");
                    nav.randomDir(pet);
                    pet.enterState("zoomies");
                },
            });
        }
    }

    // --- other pets ---
    _socialCandidates(pet, perc, nav, cands, { active: active, nightMult: nightMult, moodMult: moodMult });

    return cands;
}

function _socialCandidates(pet, perc, nav, cands, m) {
    var p = pet.personality;
    for (var i = 0; i < Math.min(3, perc.others.length); i++) {
        var o = perc.others[i];

        // visit a friend, possibly on another monitor
        if (pet.socialDrive > 0.3 && o.dist > 180 && o.sinceInteract > 60000) {
            (function(o) {
                var s = pet.socialDrive * (0.4 + p.sociability * 0.8)
                      * (0.3 + o.affinity * 0.9) * m.moodMult * m.active * m.nightMult
                      + o.familiarity * 0.1
                      - _distCost(pet, o.dist) * 0.8;
                if (!o.sameScreen) s *= 0.5 + p.boldness * 0.6;
                if (o.resting) s *= 0.6;
                cands.push({
                    name: "visit_pet", otherName: o.name,
                    score: s,
                    exec: function() {
                        _intend(pet, "visit_pet", pet.socialDrive,
                                { otherName: o.name, reason: "visiting " + o.name });
                        Memory.remember(pet, "visiting", { withPet: o.name });
                        nav.journeyToGlobal(pet, o.gx + (Math.random() < 0.5 ? -70 : 70), o.gy);
                    },
                });
            })(o);
        }

        // play together (they're close; refractory keeps bouts intermittent)
        if (o.dist < 220 && pet.playDrive > 0.3 && pet.alertness > 0.3 && o.sinceInteract > 20000) {
            (function(o) {
                var oPlayful = o.pet.personality.playfulness;
                var s = pet.playDrive * (0.45 + Math.min(p.playfulness, oPlayful + 0.2) * 0.7)
                      * (0.3 + o.affinity) * m.moodMult * m.active
                      - (o.resting ? 0.3 + p.patience * 0.3 : 0);
                cands.push({
                    name: "play_with", otherName: o.name,
                    score: s,
                    exec: function() {
                        _intend(pet, "play_with", pet.playDrive,
                                { otherName: o.name, durationMs: 45000, reason: "playing with " + o.name });
                        _faceGlobal(pet, o.gx, o.gy);
                        pet.attentionGX = o.gx; pet.attentionGY = o.gy;
                        pet.attentionUntil = Date.now() + 20000;
                        pet.playDrive = Math.max(0, pet.playDrive - 0.08);
                        Social.invitePlay(pet, o.pet);
                        pet.enterState(_pick(pet, _playPool(pet)));
                    },
                });
            })(o);
        }

        // curl up next to a resting friend
        if (o.resting && o.dist < 500 && o.dist > 70 && pet.restDrive > 0.35 && pet.alertness < 0.75) {
            (function(o) {
                cands.push({
                    name: "rest_with", otherName: o.name,
                    score: pet.restDrive * (0.5 + p.sleepiness * 0.5)
                         * (0.35 + o.affinity * 0.8) + o.familiarity * 0.1
                         - _distCost(pet, o.dist),
                    exec: function() {
                        _intend(pet, "rest_with", pet.restDrive,
                                { otherName: o.name, durationMs: 300000, reason: "napping near " + o.name });
                        nav.journeyToGlobal(pet, o.gx + (perc.petGX < o.gx ? -55 : 55), o.gy);
                    },
                });
            })(o);
        }

        // playful pounce: roughhouse with a friend using a real attack anim.
        // Bold, playful pets do it more; pouncing someone asleep is rude, so
        // only the bold and impatient ever risk it.
        if (o.dist < 220 && pet.playDrive > 0.35 && pet.alertness > 0.4
                && o.sinceInteract > 25000 && !Memory.recent(pet, "pounced", 90000)) {
            var pool = _attackPool(pet);
            if (pool.length > 0) {
                (function(o, pool) {
                    var s = pet.playDrive * (0.5 + p.playfulness * 0.65)
                          * (0.3 + o.affinity * 0.85)
                          * (0.55 + p.boldness * 0.5)
                          * m.moodMult * m.active
                          - (o.resting ? 0.35 + (1 - p.boldness) * 0.3 + p.patience * 0.3 : 0);
                    cands.push({
                        name: "pounce", otherName: o.name,
                        score: s,
                        exec: function() {
                            _intend(pet, "pounce", pet.playDrive,
                                    { otherName: o.name, durationMs: 20000, reason: "pouncing " + o.name });
                            _faceGlobal(pet, o.gx, o.gy);
                            pet.attentionGX = o.gx; pet.attentionGY = o.gy;
                            pet.attentionUntil = Date.now() + 15000;
                            Social.pounce(pet, o.pet);
                            pet.enterState(_pick(pet, pool));
                        },
                    });
                })(o, pool);
            }
        }

        // too close for comfort
        if (o.dist < 90 && o.affinity < 0.45 && p.patience < 0.6) {
            (function(o) {
                cands.push({
                    name: "move_away", otherName: o.name,
                    score: (0.45 - o.affinity) * (1 - p.patience) * 1.3,
                    exec: function() {
                        Social.annoy(pet, o.pet);
                        clearIntention(pet);
                        nav.fleeFrom(pet, o.gx, o.gy, 200 + Math.random() * 150);
                    },
                });
            })(o);
        }
    }
}

function _quietCornerNear(pet, perc) {
    // a low corner of the pet's screen, whichever side it's already on
    var m = 90;
    var gx = perc.petGX < perc.screen.x + perc.screen.w / 2
           ? perc.screen.x + m : perc.screen.x + perc.screen.w - m;
    return { gx: gx, gy: perc.screen.y + perc.screen.h - m };
}

function _attendToSomething(pet, perc) {
    var now = Date.now();
    if (perc.cursor.onMyScreen && perc.cursor.dist < 600 && perc.cursor.active) {
        pet.attentionGX = perc.cursor.gx; pet.attentionGY = perc.cursor.gy;
    } else if (perc.nearest && perc.nearest.dist < 700) {
        pet.attentionGX = perc.nearest.gx; pet.attentionGY = perc.nearest.gy;
    } else if (perc.win && perc.win.onMyScreen) {
        pet.attentionGX = perc.win.gx; pet.attentionGY = perc.win.gy;
    } else {
        pet.attentionUntil = 0;
        return;
    }
    pet.attentionUntil = now + 8000 + Math.random() * 8000;
}

function _faceGlobal(pet, gx, gy) {
    var dx = gx - (pet.screenX() + pet.worldX);
    var dy = gy - (pet.screenY() + pet.worldY);
    pet.facingRight = dx >= 0;
    pet.sprite.setDirection(Math.atan2(dy, dx));
}

// ---------------------------------------------------------------------------
// rest ticks: sleep as a sequence of "stay asleep?" decisions
// ---------------------------------------------------------------------------

// Called by the sit timer instead of a hard wake-up. Each tick weighs staying
// asleep against waking; while pressure holds, sleep silently continues (and
// may deepen), which is what consolidates naps into hours-long sleep. Only a
// genuine wake emits "well_rested".
function restTick(pet) {
    var perc = Perception.perceive(pet);
    var p = pet.personality;
    var deep = pet.state_ === "deepsleep";
    var quietHour = 1 - Memory.usualUserActivity(pet, perc.hour);
    var stay = pet.restDrive * 1.1
             + p.sleepiness * 0.45
             - pet.alertness * 0.4
             + (perc.isNight ? 0.35 + p.sleepiness * 0.35 : 0)
             + quietHour * 0.15
             + (deep ? 0.15 : 0)              // deep sleep has inertia
             + (perc.userIdle ? 0.1 : 0);
    if (stay > 0.55 + Math.random() * 0.3) {
        var wantDeep = pet.restDrive > 0.6 || (perc.isNight && p.sleepiness > 0.25);
        pet.continueResting(wantDeep ? "deepsleep" : "sit");
        return;
    }
    Memory.remember(pet, "well_rested");
    clearIntention(pet);
    pet.enterState("wake");
}

// ---------------------------------------------------------------------------
// journey callbacks (called from PetNav)
// ---------------------------------------------------------------------------

// Refresh a journey's target for moving goals. Return false to abandon.
function retarget(pet) {
    var it = pet.intention;
    if (!it) return true;
    // journeys expire with their intention: no chasing the cursor for an hour
    if (Date.now() > it.until) return false;
    switch (it.name) {
    case "follow_cursor": {
        if (!pet.inputTracker.userActive) return false;
        pet.targetGX = pet.inputTracker.cursorX;
        pet.targetGY = pet.inputTracker.cursorY;
        return true;
    }
    case "investigate":
    case "be_near_user": {
        var wp = pet.windowTracker.activeWindowPos;
        if (!wp) return false;
        pet.targetGX = wp.x + wp.w / 2;
        pet.targetGY = Math.min(wp.y + wp.h - 10, pet.screenY() + pet.screenH() - pet.height);
        return true;
    }
    case "watch_fullscreen":
        return pet.windowTracker.isFullscreen;
    case "visit_pet":
    case "rest_with": {
        var other = _findPet(pet, it.otherName);
        if (!other) return false;
        var ogx = other.screenX() + other.worldX;
        var ogy = other.screenY() + other.worldY;
        pet.targetGX = ogx + (pet.targetGX >= ogx ? 60 : -60);
        pet.targetGY = ogy;
        return true;
    }
    }
    return true;
}

function _findPet(pet, name) {
    var all = pet.petManager.pets;
    for (var i = 0; i < all.length; i++)
        if (all[i] !== pet && all[i].petData.name === name) return all[i];
    return null;
}

function onArrived(pet) {
    var it = pet.intention;
    Memory.remember(pet, "arrived", it ? { intent: it.name } : undefined);
    Drives.eventful(pet, 0.2);
    // a completed outing is satisfying: settle for a while instead of
    // immediately chasing the next goal
    pet.calmUntil = Date.now() + 15000 + pet.personality.patience * 45000;
    if (!it) { pet.enterState("idle"); return; }

    switch (it.name) {
    case "adventure":
        pet.exploreDrive = Math.max(0, pet.exploreDrive - 0.3);
        Drives.happier(pet, 0.01);
        Memory.recordPlaceAffect(pet, 0.05);
        clearIntention(pet);
        pet.enterState(_pick(pet, ["lookUp", "pose", "nod"]));
        return;

    case "investigate": {
        pet.exploreDrive = Math.max(0, pet.exploreDrive - 0.25);
        var cls = pet.windowTracker.activeWindowClass;
        Memory.recordWindowPref(pet, cls, 0.02);
        Memory.remember(pet, "investigated", { windowClass: cls });
        _attendWindow(pet);
        clearIntention(pet);
        pet.enterState(_pick(pet, ["lookUp", "nod"]));
        return;
    }

    case "follow_cursor":
        pet.socialDrive = Math.max(0, pet.socialDrive - 0.2);
        Drives.happier(pet, 0.02);
        pet.attentionGX = pet.inputTracker.cursorX;
        pet.attentionGY = pet.inputTracker.cursorY;
        pet.attentionUntil = Date.now() + 15000;
        clearIntention(pet);
        pet.enterState(_pick(pet, ["react", "hop", "nod"]));
        return;

    case "be_near_user":
        pet.socialDrive = Math.max(0, pet.socialDrive - 0.25);
        Drives.happier(pet, 0.02);
        _attendWindow(pet);
        clearIntention(pet);
        pet.enterState(pet.personality.patience > 0.5 ? "sit" : "idle");
        return;

    case "go_home":
    case "go_home_rest":
        pet.comfortDrive *= 0.25;
        Drives.happier(pet, 0.01);
        Memory.remember(pet, "home_again");
        if (it.name === "go_home_rest") { clearIntention(pet); pet.enterState("sit"); return; }
        clearIntention(pet);
        pet.enterState("idle");
        return;

    case "revisit_spot":
        pet.mood = Math.min(1, pet.mood + 0.05);
        pet.socialDrive = Math.max(0, pet.socialDrive - 0.1);
        clearIntention(pet);
        pet.enterState(_pick(pet, ["pose", "nod", "sitDown"]));
        return;

    case "watch_fullscreen":
        _attendWindow(pet);
        pet.enterState("sit");   // intention persists; rest scoring keeps it seated
        return;

    case "visit_pet": {
        var other = _findPet(pet, it.otherName);
        clearIntention(pet);
        if (other) {
            var d = _globalDist(pet, other);
            if (d < 260) {
                pet.attentionGX = other.screenX() + other.worldX;
                pet.attentionGY = other.screenY() + other.worldY;
                pet.attentionUntil = Date.now() + 15000;
                _faceGlobal(pet, pet.attentionGX, pet.attentionGY);
                Social.greet(pet, other);
                pet.enterState(_pick(pet, ["nod", "hop", "react"]));
                return;
            }
        }
        pet.enterState("idle");
        return;
    }

    case "rest_with": {
        var friend = _findPet(pet, it.otherName);
        if (friend && _globalDist(pet, friend) < 200) Social.restBeside(pet, friend);
        clearIntention(pet);
        _intend(pet, "rest", pet.restDrive, { durationMs: 300000, reason: "napping together" });
        pet.enterState("sit");
        return;
    }

    default:
        clearIntention(pet);
        pet.enterState("idle");
    }
}

function onBlocked(pet) {
    Memory.remember(pet, "blocked", pet.intention ? { intent: pet.intention.name } : undefined);
    pet.mood = Math.max(0, pet.mood - 0.02);
    clearIntention(pet);
    pet.enterState("idle");
}

function _globalDist(pet, other) {
    var dx = (other.screenX() + other.worldX) - (pet.screenX() + pet.worldX);
    var dy = (other.screenY() + other.worldY) - (pet.screenY() + pet.worldY);
    return Math.sqrt(dx * dx + dy * dy);
}

function _attendWindow(pet) {
    var wp = pet.windowTracker.activeWindowPos;
    if (!wp) return;
    pet.attentionGX = wp.x + wp.w / 2;
    pet.attentionGY = wp.y + wp.h / 2;
    pet.attentionUntil = Date.now() + 20000;
}

// ---------------------------------------------------------------------------
// events
// ---------------------------------------------------------------------------

function _cooldown(pet, key, ms) {
    if (!pet._eventCooldowns) pet._eventCooldowns = ({});
    var now = Date.now();
    if (now - (pet._eventCooldowns[key] || 0) < ms) return true;
    pet._eventCooldowns[key] = now;
    return false;
}

function onEvent(pet, type, data, nav) {
    var p = pet.personality;
    var resting = pet.state_ === "sit" || pet.state_ === "deepsleep";
    if (pet.state_ === "drag") return;

    switch (type) {
    case "cursor_near": {
        if (_cooldown(pet, "cursor_near", 8000)) return;
        var valence = p.boldness * 0.55 + p.sociability * 0.45 - 0.35 + pet.mood * 0.15;
        if (valence >= 0) {
            pet.mood = Math.min(1, pet.mood + 0.04);
            Memory.recordPlaceAffect(pet, 0.1);
            Memory.remember(pet, "cursor_greet");
            Drives.stimulate(pet, 0.15);
            if (!resting)
                pet.enterState(p.playfulness > 0.6 && pet.mood > 0.6 ? _pick(pet, ["hop", "react"]) : "react");
        } else {
            pet.alertness = Math.min(1, pet.alertness + 0.3);
            pet.mood = Math.max(0, pet.mood - 0.05);
            Memory.recordPlaceAffect(pet, -0.1);
            Memory.remember(pet, "startled");
            if (!resting) {
                if (p.boldness < 0.25 && nav) {
                    clearIntention(pet);
                    nav.fleeFrom(pet, pet.inputTracker.cursorX, pet.inputTracker.cursorY,
                                 180 + Math.random() * 120);
                } else {
                    pet.enterState(_pick(pet, HIDE_STATES));
                }
            } else if (pet.state_ === "sit") {
                pet.enterState("wake");
            }
        }
        break;
    }

    case "petted": {
        // deep sleepers wake up gently rather than springing into a trick
        if (pet.state_ === "deepsleep") {
            Drives.happier(pet, 0.05);
            pet.mood = Math.min(1, pet.mood + 0.1);
            Memory.remember(pet, "petted");
            pet.enterState("wake");
            break;
        }
        pet.socialDrive = Math.max(0, pet.socialDrive - 0.35);
        Drives.happier(pet, 0.15);
        pet.mood = Math.min(1, pet.mood + 0.25);
        pet.playDrive = Math.min(1, pet.playDrive + 0.1);
        Drives.stimulate(pet, 0.2);
        Memory.recordPlaceAffect(pet, 0.5);
        Memory.remember(pet, "petted");
        var cls = pet.windowTracker.activeWindowClass;
        if (cls) Memory.recordWindowPref(pet, cls, 0.1);
        pet.enterState(p.playfulness > 0.5 ? _pick(pet, ["hop", "pose", "nod"]) : _pick(pet, ["nod", "pose"]));
        break;
    }

    case "window_opened": {
        Drives.stimulate(pet, 0.05 + p.curiosity * 0.1);
        Memory.remember(pet, "window_opened", data);
        if (pet.state_ === "idle" && Math.random() < 0.15 + p.curiosity * 0.3)
            pet.enterState("react");
        break;
    }

    case "window_focused":
        Drives.stimulate(pet, p.curiosity * 0.04);
        break;

    case "workspace_changed":
        Drives.stimulate(pet, 0.05 + p.boldness * 0.1);
        Memory.remember(pet, "workspace_changed");
        if (pet.state_ === "idle" && Math.random() < 0.1 + p.curiosity * 0.25)
            pet.enterState("react");
        break;

    case "user_idle": {
        Memory.remember(pet, "user_idle");
        // the user left: lazy pets doze, lively pets treat it as free rein
        var liveliness = p.energy * 0.5 + p.curiosity * 0.3 + p.playfulness * 0.2;
        if (liveliness < 0.45) {
            pet.restDrive = Math.min(1, pet.restDrive + 0.15);
            if (!resting && Math.random() < 0.7) pet.enterState("sit");
        } else {
            pet.exploreDrive = Math.min(1, pet.exploreDrive + 0.1 + p.curiosity * 0.1);
            pet.playDrive = Math.min(1, pet.playDrive + p.playfulness * 0.1);
        }
        break;
    }

    case "user_active": {
        if (_cooldown(pet, "user_active", 60000)) return;
        Drives.stimulate(pet, 0.1 + p.sociability * 0.1);
        Memory.remember(pet, "user_back");
        pet.socialDrive = Math.min(1, pet.socialDrive + p.sociability * 0.15);
        if (pet.state_ === "sit" && Math.random() < 0.3 + p.sociability * 0.4)
            pet.enterState("wake");
        break;
    }

    // --- from other pets ---
    case "pet_greet": {
        var fromG = data.fromPet;
        Memory.adjustRelation(pet, fromG.petData.name, 0.008, 0.06);
        Memory.remember(pet, "greeted_by", { withPet: fromG.petData.name });
        pet.mood = Math.min(1, pet.mood + 0.04);
        pet.socialDrive = Math.max(0, pet.socialDrive - 0.1);
        if (!resting) {
            pet.attentionGX = fromG.screenX() + fromG.worldX;
            pet.attentionGY = fromG.screenY() + fromG.worldY;
            pet.attentionUntil = Date.now() + 12000;
            pet.enterState(_pick(pet, ["nod", "react"]));
        }
        break;
    }

    case "pet_invite": {
        var fromI = data.fromPet;
        var rel = Memory.relationWith(pet, fromI.petData.name, fromI.personality);
        Drives.eventful(pet, 0.3);
        if (rel.affinity > 0.35 && pet.alertness > 0.25 && !resting && pet.playDrive > 0.15) {
            Memory.adjustRelation(pet, fromI.petData.name, 0.008, 0.04);
            Memory.remember(pet, "played_with", { withPet: fromI.petData.name });
            pet.playDrive = Math.max(0, pet.playDrive - 0.05);
            pet.mood = Math.min(1, pet.mood + 0.04);
            _intend(pet, "play_with", 0.7, { otherName: fromI.petData.name, durationMs: 45000 });
            pet.attentionGX = fromI.screenX() + fromI.worldX;
            pet.attentionGY = fromI.screenY() + fromI.worldY;
            pet.attentionUntil = Date.now() + 20000;
            _faceGlobal(pet, pet.attentionGX, pet.attentionGY);
            pet.enterState(_pick(pet, _playPool(pet)));
        } else if (rel.affinity < 0.3 || p.patience < 0.25) {
            Memory.adjustRelation(pet, fromI.petData.name, -0.01, 0.02);
            Memory.remember(pet, "annoyed_by", { withPet: fromI.petData.name });
            pet.mood = Math.max(0, pet.mood - 0.03);
            if (!resting) pet.enterState(_pick(pet, ["cringe", "nod"]));
        }
        break;
    }

    case "pet_cuddle": {
        var fromC = data.fromPet;
        Memory.adjustRelation(pet, fromC.petData.name, 0.015, 0.04);
        pet.mood = Math.min(1, pet.mood + 0.03);
        break;
    }

    case "pet_pounce": {
        var fromB = data.fromPet;
        var relB = Memory.relationWith(pet, fromB.petData.name, fromB.personality);
        Drives.eventful(pet, 0.3);
        pet.attentionGX = fromB.screenX() + fromB.worldX;
        pet.attentionGY = fromB.screenY() + fromB.worldY;
        pet.attentionUntil = Date.now() + 15000;
        // how the pounce lands: playful friends spar back, grumps get cross,
        // and nobody enjoys being jumped in their sleep
        var takesItWell = relB.affinity * 0.5 + p.playfulness * 0.35 + p.patience * 0.25
                        + pet.mood * 0.15 + pet.alertness * 0.1
                        - (pet.state_ === "deepsleep" ? 0.5 : resting ? 0.3 : 0);
        if (takesItWell > 0.6) {
            Social.sparBack(pet, fromB);
            Drives.stimulate(pet, 0.15);
            _faceGlobal(pet, pet.attentionGX, pet.attentionGY);
            pet.enterState(_pick(pet, _attackPool(pet).concat(["hop", "trip", "tumble"])));
        } else if (takesItWell < 0.4) {
            Social.rebuff(pet, fromB);
            if (resting) pet.enterState("wake");
            else if (p.boldness < 0.3 && nav) {
                clearIntention(pet);
                nav.fleeFrom(pet, pet.attentionGX, pet.attentionGY, 150 + Math.random() * 100);
            } else pet.enterState(_pick(pet, ["pain", "cringe", "attack"]));
        } else {
            // tolerated: a flinch, no hard feelings
            Memory.adjustRelation(pet, fromB.petData.name, 0.002, 0.03);
            if (resting) pet.enterState("wake");
            else pet.enterState(_pick(pet, ["react", "trip", "cringe", "tumble", "tumbleBack", "hitGround"]));
        }
        break;
    }

    // answers to our own pounce (no further events; a bout is one exchange)
    case "pet_spar": {
        var fromS = data.fromPet;
        Memory.adjustRelation(pet, fromS.petData.name, 0.01, 0.04);
        Memory.remember(pet, "sparred", { withPet: fromS.petData.name });
        pet.playDrive = Math.max(0, pet.playDrive - 0.05);
        pet.mood = Math.min(1, pet.mood + 0.05);
        Drives.happier(pet, 0.02);
        if (pet.state_ === "idle")
            pet.enterState(_pick(pet, _attackPool(pet).concat(["hop"])));
        break;
    }

    case "pet_rebuff": {
        var fromR = data.fromPet;
        Memory.adjustRelation(pet, fromR.petData.name, -0.008, 0.02);
        Memory.remember(pet, "rebuffed", { withPet: fromR.petData.name });
        pet.mood = Math.max(0, pet.mood - 0.04);
        clearIntention(pet);
        if (pet.state_ === "idle") pet.enterState(_pick(pet, ["cringe", "nod"]));
        break;
    }

    case "pet_annoy": {
        var fromA = data.fromPet;
        Memory.adjustRelation(pet, fromA.petData.name, -0.02, 0.02);
        pet.mood = Math.max(0, pet.mood - 0.04);
        Memory.remember(pet, "annoyed_by", { withPet: fromA.petData.name });
        if (!resting && p.patience < 0.4) pet.enterState(_pick(pet, ["cringe", "pain", "attack"]));
        break;
    }
    }
}

// ---------------------------------------------------------------------------
// idle fidgets (called by Pet.qml's fidget timer; may return null)
// ---------------------------------------------------------------------------

function fidget(pet) {
    var p = pet.personality;
    // patient or drowsy pets mostly just sit there
    if (Math.random() < 0.25 + p.patience * 0.3 + (1 - pet.alertness) * 0.35) return null;
    var pool;
    if (pet.mood < 0.35) pool = ["nod", "cringe", "lookUp"];
    else if (p.sleepiness > 0.6 && pet.restDrive > 0.5) pool = ["deepBreath", "nod", "sitDown", "float"];
    else if (p.playfulness > 0.55 && pet.mood > 0.55) pool = ["hop", "pose", "attack", "charge", "shoot", "rotate", "twirl"];
    else pool = ["nod", "lookUp", "pose", "deepBreath", "float"];
    return _pick(pet, pool);
}

function _playPool(pet) {
    if (pet.mood < 0.35) return ["trip", "nod"];
    return ["attack", "hop", "shoot", "pose", "trip", "charge", "double", "rotate", "twirl", "tumble"];
}

// A startled or exposed pet ducks however its sheet allows: toxapex withdraws
// into its shell, absol sinks into shadow, others cringe.
var HIDE_STATES = ["hide", "sink", "cringe", "trip"];

// Attack-flavored states this pet's sprite can actually show. Sparring is
// only offered when the sheet has real attack animations.
var ATTACK_STATES = ["attack", "shoot", "charge", "double", "leapForth",
                     "strike", "quickStrike", "multiStrike", "spAttack", "swing"];

function _attackPool(pet) {
    var animData = pet.sprite._animData;
    if (!animData) return ATTACK_STATES.slice();
    var out = [];
    for (var i = 0; i < ATTACK_STATES.length; i++) {
        var anim = pet.sprite.actionMap[ATTACK_STATES[i]] || pet.sprite._defaultMap[ATTACK_STATES[i]];
        if (anim && animData[anim]) out.push(ATTACK_STATES[i]);
    }
    return out;
}

// ---------------------------------------------------------------------------
// reflection: slow personality drift from lived experience
// ---------------------------------------------------------------------------

var REFLECT_WINDOW_MS = 30 * 60000;
var TRAIT_BOUND = 0.2;
var TRAIT_DECAY = 0.98;
var TRAIT_PURGE = 0.005;

function reflect(pet) {
    if (!pet.learnedTraits) pet.learnedTraits = ({});
    var cutoff = Date.now() - REFLECT_WINDOW_MS;

    var petted = 0, startled = 0, adventures = 0, rests = 0, plays = 0;
    var social = 0, annoyed = 0;
    for (var i = pet.thoughts.length - 1; i >= 0; i--) {
        var t = pet.thoughts[i];
        if (t.time < cutoff) break;
        if (t.type === "petted") petted++;
        else if (t.type === "startled") startled++;
        else if (t.type === "adventure") adventures++;
        else if (t.type === "resting" || t.type === "well_rested") rests++;
        else if (t.type === "zoomies" || t.type === "played_solo" || t.type === "pounced") plays++;
        else if (t.type === "played_with" || t.type === "greeted" || t.type === "greeted_by"
              || t.type === "rested_with" || t.type === "sparred") social++;
        else if (t.type === "annoyed" || t.type === "annoyed_by" || t.type === "rebuffed") annoyed++;
    }

    function drift(key, delta) {
        var cur = pet.learnedTraits[key] || 0;
        pet.learnedTraits[key] = Math.max(-TRAIT_BOUND, Math.min(TRAIT_BOUND, cur + delta));
    }

    if (petted > 2) { drift("sociability", 0.01); drift("boldness", 0.005); }
    if (petted === 0 && pet.happiness < 0.5) drift("sociability", -0.005);
    if (adventures > 5) { drift("curiosity", 0.01); drift("boldness", 0.005); }
    if (rests > 6) { drift("sleepiness", 0.005); drift("energy", -0.005); }
    if (plays > 4) drift("playfulness", 0.01);
    if (startled > petted + 3) { drift("boldness", -0.01); drift("sociability", -0.005); }
    if (social > 3) { drift("sociability", 0.01); drift("playfulness", 0.005); }
    if (annoyed > social + 2) { drift("sociability", -0.008); drift("patience", -0.005); }

    // rebuild the object so the QML personality binding re-evaluates
    var fresh = {};
    var keys = Object.keys(pet.learnedTraits);
    for (var j = 0; j < keys.length; j++) {
        var v = pet.learnedTraits[keys[j]] * TRAIT_DECAY;
        if (Math.abs(v) >= TRAIT_PURGE) fresh[keys[j]] = v;
    }
    pet.learnedTraits = fresh;

    Memory.remember(pet, "reflected", { petted: petted, adventures: adventures, social: social });
}

// pick a random state, preferring ones the sprite actually has
function _pick(pet, states) {
    var animData = pet.sprite._animData;
    if (animData) {
        var available = [];
        var defaultMap = pet.sprite._defaultMap;
        for (var i = 0; i < states.length; i++) {
            var anim = pet.sprite.actionMap[states[i]] || defaultMap[states[i]] || "Walk";
            if (animData[anim]) available.push(states[i]);
        }
        if (available.length > 0) return available[Math.floor(Math.random() * available.length)];
    }
    return states[Math.floor(Math.random() * states.length)];
}
