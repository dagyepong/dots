# Changelog

## Unreleased
- Phone: the turn between the Quick Panel and Settings / Wallpapers (both ways) is smooth instead of a snap: one 200 ms speed for every turn of the phone (Settings, Wallpapers, Apps), but on a soft curve, with the two screens dissolving over about 70 - 100 ms instead of swapping in 3 frames, and the turn waits for the phone to be redrawn before it moves so a slow first frame does not skip it.
- Phone: the slide between Quick and Apps is the same 200 ms, softer, with a visible cross-fade.
- Phone: SUPER + N while the Settings (or Wallpapers) are up turns the phone into the Quick Panel, whichever way the Settings were opened; it used to cut or close them.
- Apps: the calculator, clipboard, colour, emoji and web cards fade in over the grid (and out again) instead of replacing it in one frame; system-action rows fade and the grid glides to make room; the card is built before the slide starts and stays until the screen has gone.
- Dock: Reveal zone setting (Auto-hide / Smart hide); pinned apps can be switched on or off in Edit Desktop > DOCK > APPS.
- Notifications: clicking runs the app's default action (Discord opens the message); middle click hides, right click removes; Quiet while fullscreen option.
- Apps: two-line names, a letter icon for apps with no icon, the list refreshes when the Apps screen opens.
- Shadows: tiled windows get shadows again with a stronger default; the phone casts a soft, airbrushed shadow (one small picture, no blur); Settings > Quick > Phone shadow switches it off.
- Lockscreen: optional lyrics under the clock (gacha style; Settings > General).

## 1.0.0 - First release
- Themes: new Monochrome theme and a Custom color theme (make your own palette).
- Windows cursor porter: import .cur / .ani packs (animated too); they show up in Settings > Icons & cursor.
- Desktop widgets: Lyrics, Sticky Notes, Custom Image and Color Palette.
- Capsule bar and dock app style.
- Dock tools.
- Handheld EQ.
- The shell tells you when there is an update.
- Wallpaper folder picker.
- The power button menu now sits at the side of the phone.
- Configurable monitor displays via nwg-displays.
- On-screen keyboard.
- UI consistency adjustments.
- Bug fixes.
