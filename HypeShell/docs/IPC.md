# IPC Commands Reference

HypeMaterialShell provides comprehensive IPC (Inter-Process Communication) functionality that allows external control of the shell through command-line commands. All IPC commands follow the format:

```bash
hype ipc call <target> <function> [parameters...]
```

## Target: `audio`

Audio system control and information.

### Functions

**`setvolume <percentage>`**
- Set output volume to specific percentage (0-100)
- Returns: Confirmation message

**`increment <step>`**
- Increase output volume by step amount
- Parameters: `step` - Volume increase amount (default: 5)
- Returns: Confirmation message

**`decrement <step>`**
- Decrease output volume by step amount
- Parameters: `step` - Volume decrease amount (default: 5)
- Returns: Confirmation message

**`mute`**
- Toggle output device mute state
- Returns: Current mute status

**`setmic <percentage>`**
- Set input (microphone) volume to specific percentage (0-100)
- Returns: Confirmation message

**`micmute`**
- Toggle input device mute state
- Returns: Current mic mute status

**`status`**
- Get current audio status for both input and output devices
- Returns: Volume levels and mute states

### Examples
```bash
hype ipc call audio setvolume 50
hype ipc call audio increment 10
hype ipc call audio mute
```

## Target: `brightness`

Display brightness control for internal and external displays.

### Functions

**`set <percentage> [device]`**
- Set brightness to specific percentage (1-100)
- Parameters:
  - `percentage` - Brightness level (1-100)
  - `device` - Optional device name (empty string for default)
- Returns: Confirmation with device info

**`increment <step> [device]`**
- Increase brightness by step amount
- Parameters:
  - `step` - Brightness increase amount
  - `device` - Optional device name (empty string for default)
- Returns: Confirmation with new brightness level

**`decrement <step> [device]`**
- Decrease brightness by step amount
- Parameters:
  - `step` - Brightness decrease amount
  - `device` - Optional device name (empty string for default)
- Returns: Confirmation with new brightness level

**`status`**
- Get current brightness status
- Returns: Current device and brightness level

**`list`**
- List all available brightness devices
- Returns: Device names and classes

### Examples
```bash
hype ipc call brightness set 80
hype ipc call brightness increment 10 ""
hype ipc call brightness decrement 5 "intel_backlight"
```

## Target: `night`

Night mode (gamma/color temperature) control.

### Functions

**`toggle`**
- Toggle night mode on/off
- Returns: Current night mode state

**`enable`**
- Enable night mode
- Returns: Confirmation message

**`disable`**
- Disable night mode
- Returns: Confirmation message

**`status`**
- Get current night mode status
- Returns: Night mode enabled/disabled state

**`temperature [value]`**
- Get or set night mode color temperature
- Parameters:
  - `value` - Optional temperature in Kelvin (2500-6000, steps of 500)
- Returns: Current or newly set temperature

**`automation [mode]`**
- Get or set night mode automation mode
- Parameters:
  - `mode` - Optional automation mode: "manual", "time", or "location"
- Returns: Current or newly set automation mode

**`schedule <start> <end>`**
- Set time-based automation schedule
- Parameters:
  - `start` - Start time in HH:MM format (e.g., "20:00")
  - `end` - End time in HH:MM format (e.g., "06:00")
- Returns: Confirmation of schedule update

**`location <latitude> <longitude>`**
- Set manual coordinates for location-based automation
- Parameters:
  - `latitude` - Latitude coordinate (e.g., 40.7128)
  - `longitude` - Longitude coordinate (e.g., -74.0060)
- Returns: Confirmation of coordinates update

### Examples
```bash
hype ipc call night toggle
hype ipc call night temperature 4000
hype ipc call night automation time
hype ipc call night schedule 20:00 06:00
hype ipc call night location 40.7128 -74.0060
```

## Target: `mpris`

Media player control via MPRIS interface.

### Functions

**`list`**
- List all available media players
- Returns: Player names

**`play`**
- Start playback on active player
- Returns: Nothing

**`pause`**
- Pause playback on active player
- Returns: Nothing

**`playPause`**
- Toggle play/pause state on active player
- Returns: Nothing

**`previous`**
- Skip to previous track
- Returns: Nothing

**`next`**
- Skip to next track
- Returns: Nothing

**`stop`**
- Stop playback on active player
- Returns: Nothing

### Examples
```bash
hype ipc call mpris playPause
hype ipc call mpris next
```

## Target: `lock`

Screen lock control and status.

### Functions

**`lock`**
- Lock the screen immediately
- Returns: Nothing

**`demo`**
- Show lock screen in demo mode (doesn't actually lock)
- Returns: Nothing

**`isLocked`**
- Check if screen is currently locked
- Returns: Boolean lock state

### Examples
```bash
hype ipc call lock lock
hype ipc call lock isLocked
```

## Target: `inhibit`

Idle inhibitor control to prevent automatic sleep/lock.

### Functions

**`toggle`**
- Toggle idle inhibit state
- Returns: Current inhibit state message

**`enable`**
- Enable idle inhibit (prevent sleep/lock)
- Returns: Confirmation message

**`disable`**
- Disable idle inhibit (allow sleep/lock)
- Returns: Confirmation message

### Examples
```bash
hype ipc call inhibit toggle
hype ipc call inhibit enable
```

## Target: `wallpaper`

Wallpaper management and retrieval with support for per-monitor configurations.

### Legacy Functions (Global Wallpaper Mode)

**`get`**
- Get current wallpaper path
- Returns: Full path to current wallpaper file, or error if per-monitor mode is enabled

**`set <path>`**
- Set wallpaper to specified path
- Parameters: `path` - Absolute or relative path to image file
- Returns: Confirmation message or error if per-monitor mode is enabled

**`clear`**
- Clear all wallpapers and disable per-monitor mode
- Returns: Success confirmation

**`next`**
- Cycle to next wallpaper in the same directory
- Returns: Success confirmation or error if per-monitor mode is enabled

**`prev`**
- Cycle to previous wallpaper in the same directory
- Returns: Success confirmation or error if per-monitor mode is enabled

### Per-Monitor Functions

**`getFor <screenName>`**
- Get wallpaper path for specific monitor
- Parameters: `screenName` - Monitor name (e.g., "DP-2", "eDP-1")
- Returns: Full path to wallpaper file for the specified monitor

**`setFor <screenName> <path>`**
- Set wallpaper for specific monitor (automatically enables per-monitor mode)
- Parameters:
  - `screenName` - Monitor name (e.g., "DP-2", "eDP-1")
  - `path` - Absolute or relative path to image file
- Returns: Success confirmation with monitor and path info

**`nextFor <screenName>`**
- Cycle to next wallpaper for specific monitor
- Parameters: `screenName` - Monitor name (e.g., "DP-2", "eDP-1")
- Returns: Success confirmation

**`prevFor <screenName>`**
- Cycle to previous wallpaper for specific monitor
- Parameters: `screenName` - Monitor name (e.g., "DP-2", "eDP-1")
- Returns: Success confirmation

### Examples

**Global wallpaper mode:**
```bash
hype ipc call wallpaper get
hype ipc call wallpaper set /path/to/image.jpg
hype ipc call wallpaper next
hype ipc call wallpaper clear
```

**Per-monitor wallpaper mode:**
```bash
# Set different wallpapers for each monitor
hype ipc call wallpaper setFor DP-2 /path/to/image1.jpg
hype ipc call wallpaper setFor eDP-1 /path/to/image2.jpg

# Get wallpaper for specific monitor
hype ipc call wallpaper getFor DP-2

# Cycle wallpapers for specific monitor
hype ipc call wallpaper nextFor eDP-1
hype ipc call wallpaper prevFor DP-2

# Clear all wallpapers and return to global mode
hype ipc call wallpaper clear
```

**Error handling:**
When per-monitor mode is enabled, legacy functions will return helpful error messages:
```bash
hype ipc call wallpaper get
# Returns: "ERROR: Per-monitor mode enabled. Use getFor(screenName) instead."

hype ipc call wallpaper set /path/to/image.jpg
# Returns: "ERROR: Per-monitor mode enabled. Use setFor(screenName, path) instead."
```

## Target: `profile`

User profile image management.

### Functions

**`getImage`**
- Get current profile image path
- Returns: Full path to profile image or empty string if not set

**`setImage <path>`**
- Set profile image to specified path
- Parameters: `path` - Absolute or relative path to image file
- Returns: Success message with path or error message

**`clearImage`**
- Clear the profile image
- Returns: Success confirmation message

### Examples
```bash
hype ipc call profile getImage
hype ipc call profile setImage /path/to/avatar.png
hype ipc call profile clearImage
```

## Target: `theme`

Theme mode control (light/dark mode switching).

### Functions

**`toggle`**
- Toggle between light and dark themes
- Returns: Current theme mode ("light" or "dark")

**`light`**
- Switch to light theme mode
- Returns: "light"

**`dark`**
- Switch to dark theme mode
- Returns: "dark"

**`getMode`**
- Returns current mode
- Returns: "dark" or "light"

### Examples
```bash
hype ipc call theme toggle
hype ipc call theme dark
```

## Target: `bar`

Top bar visibility control.

### Functions

**`reveal`**
- Show the top bar
- Returns: Success confirmation

**`hide`**
- Hide the top bar
- Returns: Success confirmation

**`toggle`**
- Toggle top bar visibility
- Returns: Success confirmation with current state

**`toggleReveal`**
- Toggle the runtime reveal/tuck state for an autohidden bar
- Returns: Success confirmation with current reveal state

**`status`**
- Get current top bar visibility status
- Returns: "visible" or "hidden"

### Examples
```bash
hype ipc call bar toggle
hype ipc call bar toggleReveal index 0
hype ipc call bar hide
hype ipc call bar status
```

## Target: `systemupdater`

System updater widget control and background update checks.

### Functions

**`toggle`**
- Toggle the system updater popout open/closed

**`open`**
- Open the system updater popout

**`close`**
- Close the system updater popout

**`updatestatus`**
- Trigger a background update check
- Returns: Success confirmation

### Examples
```bash
hype ipc call systemupdater toggle
hype ipc call systemupdater open
hype ipc call systemupdater close
hype ipc call systemupdater updatestatus
```

## Modal Controls

These targets control various modal windows and overlays.

### Target: `spotlight`
Application launcher modal control.

**Functions:**
- `open` - Show the spotlight launcher
- `close` - Hide the spotlight launcher
- `toggle` - Toggle spotlight launcher visibility
- `openQuery <query>` - Show the spotlight launcher with pre-filled search query
  - Parameters: `query` - Search text to pre-fill in the search box
  - Returns: Success confirmation
- `toggleQuery <query>` - Toggle spotlight launcher with pre-filled search query
  - Parameters: `query` - Search text to pre-fill in the search box (only used when opening)
  - Returns: Success confirmation

### Target: `clipboard`
Clipboard history modal control.

**Functions:**
- `open` - Show clipboard history
- `close` - Hide clipboard history
- `toggle` - Toggle clipboard history visibility

### Target: `notifications`
Notification center modal control.

**Functions:**
- `open` - Show notification center
- `close` - Hide notification center
- `toggle` - Toggle notification center visibility

### Target: `settings`
Settings modal control.

**Functions:**
- `open` - Show settings modal
- `close` - Hide settings modal
- `toggle` - Toggle settings modal visibility

### Target: `processlist`
System process list and performance modal control.

**Functions:**
- `open` - Show process list modal
- `close` - Hide process list modal
- `toggle` - Toggle process list modal visibility

### Target: `powermenu`
Power menu modal control for system power actions.

**Functions:**
- `open` - Show power menu modal
- `close` - Hide power menu modal
- `toggle` - Toggle power menu modal visibility

### Target: `control-center`
Control Center popout containing network, bluetooth, audio, power, and other quick settings.

**Functions:**
- `open` - Show the control center
- `close` - Hide the control center
- `toggle` - Toggle control center visibility

**Examples**
```bash
hype ipc call control-center toggle
hype ipc call control-center open
hype ipc call control-center close
```

### Target: `notepad`
Notepad/scratchpad modal control for quick note-taking.

**Functions:**
- `open` - Show notepad modal
- `close` - Hide notepad modal
- `toggle` - Toggle notepad modal visibility
- `expand` - Expand the active notepad width and open it if hidden
- `collapse` - Collapse the active notepad width without changing visibility
- `toggleExpand` - Toggle the active notepad width between collapsed and expanded

### Target: `dash`
Dashboard popup control with tab selection for overview, media, and weather information.

**Functions:**
- `open [tab]` - Show dashboard popup with optional tab selection
  - Parameters: `tab` - Tab to open: "", "overview", "media", or "weather"
  - Returns: Success/failure message
- `close` - Hide dashboard popup
  - Returns: Success/failure message
- `toggle [tab]` - Toggle dashboard popup visibility with optional tab selection
  - Parameters: `tab` - Tab to open when showing: "", "overview", "media", or "weather"
  - Returns: Success/failure message

### Target: `hypedash`
HypeDash wallpaper browser control.

**Functions:**
- `wallpaper` - Toggle HypeDash popup on focused screen with wallpaper tab selected
  - Returns: Success/failure message

### Target: `file`
File browser controls for selecting wallpapers and profile images.

**Functions:**
- `browse <type>` - Open file browser for specific file type
  - Parameters: `type` - Either "wallpaper" or "profile"
  - `wallpaper` - Opens wallpaper file browser in Pictures directory
  - `profile` - Opens profile image file browser in Pictures directory
  - Both browsers support common image formats (jpg, jpeg, png, bmp, gif, webp)

### Target: `color-picker`
Color picker modal control.

**Functions:**
- `open` - Show color picker modal
- `openColor <color>` - Show color picker modal with a pre-selected color
  - Parameters: `color` - Color string (e.g. "#ff0000", "#3f51b5")
- `close` - Hide color picker modal
- `closeInstant` - Hide color picker modal without animation
- `toggle` - Toggle color picker modal visibility
- `toggleInstant` - Toggle color picker modal visibility without animation on hide

### Target: `hypr`
Hyprland-specific controls including keybinds cheatsheet and workspace overview (Hyprland only).

**Functions:**
- `openBinds` - Show Hyprland keybinds cheatsheet modal
  - Returns: Success/failure message
  - Note: Returns "HYPR_NOT_AVAILABLE" if not running Hyprland
- `closeBinds` - Hide Hyprland keybinds cheatsheet modal
  - Returns: Success/failure message
  - Note: Returns "HYPR_NOT_AVAILABLE" if not running Hyprland
- `toggleBinds` - Toggle Hyprland keybinds cheatsheet modal visibility
  - Returns: Success/failure message
  - Note: Returns "HYPR_NOT_AVAILABLE" if not running Hyprland
- `openOverview` - Show Hyprland workspace overview
  - Returns: "OVERVIEW_OPEN_SUCCESS" or "HYPR_NOT_AVAILABLE"
  - Displays all workspaces across all monitors with live window previews
  - Allows drag-and-drop window movement between workspaces and monitors
- `closeOverview` - Hide Hyprland workspace overview
  - Returns: "OVERVIEW_CLOSE_SUCCESS" or "HYPR_NOT_AVAILABLE"
- `toggleOverview` - Toggle Hyprland workspace overview visibility
  - Returns: "OVERVIEW_OPEN_SUCCESS", "OVERVIEW_CLOSE_SUCCESS", or "HYPR_NOT_AVAILABLE"

**Keybinds Cheatsheet Description:**
Displays an auto-categorized cheatsheet of all Hyprland keybinds parsed from `~/.config/hypr`. Keybinds are organized into three columns:
- **Window / Monitor** - Window and monitor management keybinds (sorted by dispatcher)
- **Workspace** - Workspace switching and management (sorted by dispatcher)
- **Execute** - Application launchers and commands (sorted by keybind)

**Workspace Overview Description:**
Displays a live overview of all workspaces across all monitors with window previews:
- **Multi-monitor support** - Shows workspaces from all connected monitors with monitor name labels
- **Live window previews** - Real-time screen capture of all windows on each workspace
- **Drag-and-drop** - Move windows between workspaces and monitors by dragging
- **Keyboard navigation** - Use Left/Right arrow keys to switch between workspaces on current monitor
- **Visual indicators** - Active workspace highlighted when it contains windows
- **Click to switch** - Click any workspace to switch to it
- **Click outside or press Escape** - Close the overview

### Modal Examples
```bash
# Open application launcher
hype ipc call spotlight toggle

# Open spotlight with pre-filled search
hype ipc call spotlight openQuery browser
hype ipc call spotlight toggleQuery "!"

# Show clipboard history
hype ipc call clipboard open

# Toggle notification center
hype ipc call notifications toggle

# Show settings
hype ipc call settings open

# Show system monitor
hype ipc call processlist toggle

# Show power menu
hype ipc call powermenu toggle

# Open notepad
hype ipc call notepad toggle

# Open the active notepad expanded
hype ipc call notepad expand

# Collapse the active notepad width
hype ipc call notepad collapse

# Toggle the active notepad width
hype ipc call notepad toggleExpand

# Show dashboard with specific tabs
hype ipc call dash open overview
hype ipc call dash toggle media
hype ipc call dash open weather

# Open wallpaper browser
hype ipc call hypedash wallpaper

# Open file browsers
hype ipc call file browse wallpaper
hype ipc call file browse profile

# Open color picker
hype ipc call color-picker toggle

# Show Hyprland keybinds cheatsheet (Hyprland only)
hype ipc call hypr toggleBinds
hype ipc call hypr openBinds

# Show Hyprland workspace overview (Hyprland only)
hype ipc call hypr toggleOverview
hype ipc call hypr openOverview
hype ipc call hypr closeOverview
```

## Common Usage Patterns

### Keybinding Integration

These IPC commands are designed to be used with window manager keybindings.

**Example niri configuration:**
```kdl
binds {
    Mod+Space { spawn "qs" "-c" "hype" "ipc" "call" "spotlight" "toggle"; }
    Mod+V { spawn "qs" "-c" "hype" "ipc" "call" "clipboard" "toggle"; }
    Mod+P { spawn "qs" "-c" "hype" "ipc" "call" "notepad" "toggle"; }
    Mod+Shift+P { spawn "qs" "-c" "hype" "ipc" "call" "notepad" "expand"; }
    Mod+Ctrl+P { spawn "qs" "-c" "hype" "ipc" "call" "notepad" "toggleExpand"; }
    Mod+X { spawn "qs" "-c" "hype" "ipc" "call" "powermenu" "toggle"; }
    XF86AudioRaiseVolume { spawn "qs" "-c" "hype" "ipc" "call" "audio" "increment" "3"; }
    XF86MonBrightnessUp { spawn "qs" "-c" "hype" "ipc" "call" "brightness" "increment" "5" ""; }
}
```

**Example Hyprland configuration:**
```conf
bind = SUPER, Space, exec, qs -c hype ipc call spotlight toggle
bind = SUPER, V, exec, qs -c hype ipc call clipboard toggle
bind = SUPER, P, exec, qs -c hype ipc call notepad toggle
bind = SUPER SHIFT, P, exec, qs -c hype ipc call notepad expand
bind = SUPER CTRL, P, exec, qs -c hype ipc call notepad toggleExpand
bind = SUPER, X, exec, qs -c hype ipc call powermenu toggle
bind = SUPER, slash, exec, qs -c hype ipc call hypr toggleBinds
bind = SUPER, Tab, exec, qs -c hype ipc call hypr toggleOverview
bind = , XF86AudioRaiseVolume, exec, qs -c hype ipc call audio increment 3
bind = , XF86MonBrightnessUp, exec, qs -c hype ipc call brightness increment 5 ""
```

### Scripting and Automation

IPC commands can be used in scripts for automation:

```bash
#!/bin/bash
# Toggle night mode based on time of day
hour=$(date +%H)
if [ $hour -ge 20 ] || [ $hour -le 6 ]; then
    hype ipc call night enable
else
    hype ipc call night disable
fi
```

### Status Checking

Many commands provide status information useful for scripts:

```bash
# Check if screen is locked before performing action
if hype ipc call lock isLocked | grep -q "false"; then
    # Perform action only if unlocked
    hype ipc call notifications open
fi
```

## Return Values

Most IPC functions return string messages indicating:
- Success confirmation with current values
- Error messages if operation fails
- Status information for query functions
- Empty/void return for simple action functions

Functions that return void (like media controls) execute the action but don't provide feedback. Check the application state through other means if needed.
