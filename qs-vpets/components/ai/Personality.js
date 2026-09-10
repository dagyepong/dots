// Traits are 0-1 and influence drive rates, utility scores, and social compatibility.
//
// A pet's effective personality = preset + seeded per-name jitter + config
// overrides + learned drift (bounded, applied in Pet.qml). The jitter means two
// "curious" pets are still individuals, deterministically, across restarts.

var TRAIT_KEYS = ["energy", "curiosity", "playfulness", "sleepiness",
                  "boldness", "sociability", "patience"];

var PRESETS = {
    "lazy": {
        energy: 0.15, curiosity: 0.2, playfulness: 0.15, sleepiness: 0.9,
        boldness: 0.2, sociability: 0.3, patience: 0.8
    },
    "energetic": {
        energy: 0.95, curiosity: 0.6, playfulness: 0.85, sleepiness: 0.05,
        boldness: 0.8, sociability: 0.7, patience: 0.2
    },
    "curious": {
        energy: 0.5, curiosity: 0.95, playfulness: 0.4, sleepiness: 0.3,
        boldness: 0.6, sociability: 0.5, patience: 0.5
    },
    "chill": {
        energy: 0.3, curiosity: 0.35, playfulness: 0.25, sleepiness: 0.5,
        boldness: 0.4, sociability: 0.4, patience: 0.9
    },
    "brave": {
        energy: 0.7, curiosity: 0.7, playfulness: 0.5, sleepiness: 0.2,
        boldness: 0.95, sociability: 0.5, patience: 0.4
    },
    "shy": {
        energy: 0.3, curiosity: 0.6, playfulness: 0.3, sleepiness: 0.4,
        boldness: 0.1, sociability: 0.2, patience: 0.7
    },
    "playful": {
        energy: 0.7, curiosity: 0.5, playfulness: 0.95, sleepiness: 0.15,
        boldness: 0.6, sociability: 0.8, patience: 0.3
    },
    "grumpy": {
        energy: 0.4, curiosity: 0.2, playfulness: 0.1, sleepiness: 0.6,
        boldness: 0.5, sociability: 0.1, patience: 0.3
    },
};

var JITTER = 0.07;

// Deterministic hash so jitter is stable for a given pet name.
function _hash(str) {
    var h = 2166136261;
    for (var i = 0; i < str.length; i++) {
        h ^= str.charCodeAt(i);
        h = (h * 16777619) >>> 0;
    }
    return h;
}

function _seeded01(seed) {
    // xorshift step, returns [0,1)
    seed ^= seed << 13; seed >>>= 0;
    seed ^= seed >> 17;
    seed ^= seed << 5; seed >>>= 0;
    return { value: (seed >>> 0) / 4294967296, seed: seed };
}

function clamp01(v) { return Math.max(0, Math.min(1, v)); }

// preset: string name or an object of trait values.
// name: pet name, used to seed individual jitter.
// overrides: optional object of absolute trait values from config.
function resolve(preset, name, overrides) {
    var base;
    if (preset && typeof preset === "object") base = preset;
    else base = PRESETS[preset] || PRESETS["curious"];

    var seed = _hash(name || "pet") || 1;
    var p = {};
    for (var i = 0; i < TRAIT_KEYS.length; i++) {
        var k = TRAIT_KEYS[i];
        var r = _seeded01(seed + i * 7919);
        var jitter = (r.value - 0.5) * 2 * JITTER;
        p[k] = clamp01((base[k] !== undefined ? base[k] : 0.5) + jitter);
    }
    if (overrides) {
        for (var j = 0; j < TRAIT_KEYS.length; j++) {
            var ok = TRAIT_KEYS[j];
            if (overrides[ok] !== undefined) p[ok] = clamp01(overrides[ok]);
        }
    }
    return p;
}

// How naturally two personalities get along, -1..1. Playful+playful bond,
// grumpy pets start standoffish, big energy mismatches grate.
function compatibility(a, b) {
    var playMatch = 1 - Math.abs(a.playfulness - b.playfulness);
    var energyMatch = 1 - Math.abs(a.energy - b.energy);
    var warmth = (a.sociability + b.sociability) / 2;
    var c = playMatch * 0.35 + energyMatch * 0.25 + warmth * 0.8 - 0.55;
    return Math.max(-1, Math.min(1, c));
}
