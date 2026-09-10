.import "Memory.js" as Memory
.import "Drives.js" as Drives

// Pet-to-pet interactions. An interaction updates this pet's side of the
// relationship immediately and pokes the other pet's brain through its
// socialEvent() hook — the other pet decides on its own how to respond, so
// play bouts, snubs and friendships all emerge from two independent minds.

function greet(pet, other) {
    Memory.adjustRelation(pet, other.petData.name, 0.008, 0.06);
    Memory.remember(pet, "greeted", { withPet: other.petData.name });
    pet.socialDrive = Math.max(0, pet.socialDrive - 0.15);
    pet.mood = Math.min(1, pet.mood + 0.04);
    other.socialEvent("greet", pet);
}

function invitePlay(pet, other) {
    Memory.adjustRelation(pet, other.petData.name, 0.008, 0.05);
    Memory.remember(pet, "played_with", { withPet: other.petData.name });
    pet.socialDrive = Math.max(0, pet.socialDrive - 0.1);
    pet.mood = Math.min(1, pet.mood + 0.04);
    Drives.happier(pet, 0.02);
    other.socialEvent("invite", pet);
}

function restBeside(pet, other) {
    Memory.adjustRelation(pet, other.petData.name, 0.01, 0.04);
    Memory.remember(pet, "rested_with", { withPet: other.petData.name });
    pet.mood = Math.min(1, pet.mood + 0.03);
    other.socialEvent("cuddle", pet);
}

function annoy(pet, other) {
    Memory.adjustRelation(pet, other.petData.name, -0.025, 0.02);
    Memory.remember(pet, "annoyed", { withPet: other.petData.name });
    pet.mood = Math.max(0, pet.mood - 0.03);
    other.socialEvent("annoy", pet);
}

// --- playful sparring ---
// A pounce is an opening move, not a guaranteed hit: the target's brain
// decides whether it lands as play (sparBack) or as a nuisance (rebuff), and
// the answer flows back to the pouncer. Neither response emits further
// events, so a bout is always pounce -> answer, never an infinite exchange.

function pounce(pet, other) {
    Memory.adjustRelation(pet, other.petData.name, 0.004, 0.05);
    Memory.remember(pet, "pounced", { withPet: other.petData.name });
    pet.playDrive = Math.max(0, pet.playDrive - 0.12);
    pet.socialDrive = Math.max(0, pet.socialDrive - 0.08);
    pet.mood = Math.min(1, pet.mood + 0.05);
    Drives.happier(pet, 0.02);
    other.socialEvent("pounce", pet);
}

// the pounce landed as play: target enjoys it and answers in kind
function sparBack(pet, other) {
    Memory.adjustRelation(pet, other.petData.name, 0.012, 0.05);
    Memory.remember(pet, "sparred", { withPet: other.petData.name });
    pet.playDrive = Math.max(0, pet.playDrive - 0.1);
    pet.mood = Math.min(1, pet.mood + 0.06);
    Drives.happier(pet, 0.02);
    other.socialEvent("spar", pet);
}

// the pounce landed as a nuisance: target is cross and the pouncer knows it
function rebuff(pet, other) {
    Memory.adjustRelation(pet, other.petData.name, -0.02, 0.03);
    Memory.remember(pet, "annoyed_by", { withPet: other.petData.name });
    pet.mood = Math.max(0, pet.mood - 0.06);
    other.socialEvent("rebuff", pet);
}
