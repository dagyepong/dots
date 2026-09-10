# qs-vpets

Desktop virtual pets for Hyprland/Wayland, built with [Quickshell](https://git.outfoxxed.me/outfoxxed/quickshell).

Pixel-art pets that live on your desktop. They walk around your monitors, investigate your windows, nap when you're idle, follow your cursor when they want attention, and develop preferences over time. Each pet has persistent memory and a personality that shapes how it behaves over hours-long sessions.

Uses [PMD Collab](https://sprites.pmdcollab.org/#/) sprite sheets (Pokemon Mystery Dungeon format).

## Features

- **Drive-based AI** with 5 competing needs (rest, explore, social, comfort, play) that create emergent behavior
- **8 personality presets** that meaningfully change how the pet acts (lazy pets nap constantly, curious pets investigate everything)
- **Persistent memory** across restarts: drives, thoughts, visited areas, window preferences, home position
- **Cross-monitor roaming** with proper multi-monitor support (tested with mixed portrait/landscape)
- **Environment awareness**: reacts to window focus, fullscreen apps, workspace changes, user idle, cursor position
- **Window preference learning**: the pet remembers which windows it was petted near and gravitates toward them
- **Fullscreen awareness**: naturally retreats from fullscreen content (games, videos) based on personality
- **Rich thought log**: every event captures position, drive state, window context for future decision-making
- **Sprite fallback chains**: missing animations gracefully fall back, never causes invisible sprites

## Install (Nix)

```nix
# flake.nix inputs
qs-vpets = {
  url = "github:jesperls/qs-vpets";
  inputs.nixpkgs.follows = "nixpkgs";
};

# home-manager module
{ inputs, ... }: {
  imports = [ inputs.qs-vpets.homeManagerModules.default ];
  programs.qs-vpets.enable = true;
}
```

## Development

```bash
nix develop
qs -p .
```

## Configuration

Config auto-creates at `~/.config/qs-vpets/config.json` on first launch. Per-pet state persists separately in `~/.config/qs-vpets/state-<pet-name>.json`.

### Pets

```json
{
  "pets": [
    {
      "name": "Mochi",
      "sprite": "charizard",
      "personality": "energetic",
      "scale": 2,
      "monitor": ""
    }
  ]
}
```

| Field | Description |
|-------|-------------|
| `name` | Unique name, used as key for state persistence |
| `sprite` | Folder name in `assets/sprites/` (must contain `AnimData.xml` + sprite sheets) |
| `personality` | One of: `lazy`, `energetic`, `curious`, `chill`, `brave`, `shy`, `playful`, `grumpy` |
| `scale` | Sprite scale multiplier (default: 2) |
| `monitor` | Monitor name to start on (empty = primary, pet roams freely after spawn) |
| `actions` | Optional action-to-sprite overrides (see below) |

### Personalities

Each personality is a set of 7 traits (0-1) that influence drive rates and decision weights:

| Preset | Character |
|--------|-----------|
| `lazy` | Naps constantly, low energy, very patient |
| `energetic` | Always moving, playful, impatient |
| `curious` | Investigates windows, explores everywhere |
| `chill` | Idles a lot, relaxed, rarely acts on low drives |
| `brave` | Bold explorer, doesn't retreat from fullscreen easily |
| `shy` | Stays near home, retreats quickly, low social need |
| `playful` | Lots of animations, zoomies, bouncy walks |
| `grumpy` | Fidgets a lot, low social/play, sleepy |

### Sprites

Any [PMD Collab](https://sprites.pmdcollab.org/#/) sprite works. Drop the folder into `assets/sprites/`:

```
assets/sprites/<name>/
├── AnimData.xml
├── Walk-Anim.png
├── Sleep-Anim.png
├── Attack-Anim.png
├── Hop-Anim.png
└── ...
```

The pet automatically discovers available animations from `AnimData.xml` and only uses ones that exist. Missing animations fall back through a chain (e.g. `Laying -> Faint -> Sleep -> Walk`).

### Action Overrides

Override which PMD animation plays for each pet state:

```json
{
  "name": "Shadow",
  "sprite": "absol",
  "actions": {
    "zoomies": "Hop",
    "react": "Hurt",
    "attack": "Double"
  }
}
```

Keys are pet states (`idle`, `walk`, `sit`, `deepsleep`, `react`, `hop`, `attack`, `shoot`, `charge`, `strike`, `quickStrike`, `multiStrike`, `spAttack`, `swing`, `leapForth`, `zoomies`, `nod`, `pose`, `lookUp`, `sitDown`, `rotate`, `twirl`, `tumble`, `tumbleBack`, `pain`, `hide`, `sink`, `float`, etc.), values are animation names from `AnimData.xml`. States whose animation a sheet lacks fall back through sensible chains (e.g. `hide` → `Withdraw` → `Sink` → `Cringe` → `Hurt`), and behavior pools only offer states the sprite can actually show, so sparse sheets stay fully functional.

### Behavior

```json
{
  "behavior": {
    "idleTimeout": 300,
    "walkSpeed": 120
  }
}
```

| Field | Default | Description |
|-------|---------|-------------|
| `idleTimeout` | 300 | Seconds of no input before user is considered idle |
| `walkSpeed` | 120 | Base walk speed in pixels/second |

## How It Works

The pet runs a simple loop: **perceive** the environment, **evaluate** which drive is strongest, **decide** what to do about it. Drives build and decay over time based on personality traits and environmental factors. The pet commits to **intentions** (go home, investigate window, follow cursor) that persist across multiple decision cycles.

Everything is emergent from the drive system. There are no scripted sequences. A curious pet investigates windows because its curiosity trait amplifies the explore drive. A shy pet retreats during fullscreen because low boldness amplifies the comfort drive. The pet follows the cursor because social need is high and the cursor represents the user.

Personality isn't static either. Every 30 minutes the pet reflects on recent experiences and drifts its trait modifiers within bounded limits: a pet that gets petted often slowly becomes more sociable, one that keeps exploring becomes bolder, one that's constantly startled becomes shier. Base personality still dominates, but pets diverge over time.

State persists in `~/.config/qs-vpets/state-<name>.json` per pet (separate from config to avoid reload loops). The pet remembers its drives, mood, learned trait drift, position, home, visited areas, window preferences, place-affect memory, and recent thoughts across restarts.
