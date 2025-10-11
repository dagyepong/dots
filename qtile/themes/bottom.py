import os
import subprocess
from os import path

from libqtile import bar, hook, layout, qtile, widget
from libqtile.config import Click, Drag, Group, Key, Match, Screen, ScratchPad, DropDown
from libqtile.lazy import lazy
from libqtile.utils import guess_terminal
from settings.path import qtile_path
from qtile_extras import widget
from qtile_extras.widget import decorations
from qtile_extras.widget.decorations import RectDecoration
import colors

mod = "mod4"
terminal = "kitty"
mymenu = "rofi -show drun"
browser = "flatpak run com.vivaldi.Vivaldi"
files = "krusader"
discord = "webcord"
todoist = "flatpak run com.todoist.Todoist"
screenie = "flameshot gui"

colors, backgroundColor, foregroundColor, workspaceColor, chordColor = colors.onedark()

keys = [

    Key([mod], "Return", lazy.spawn(terminal), desc="Launch terminal"),
    # Toggle between different layouts as defined below
    Key([mod], "Tab", lazy.next_layout(), desc="Toggle between layouts"),
    Key([mod], "q", lazy.window.kill(), desc="Kill focused window"),
    Key([mod], "f", lazy.window.toggle_fullscreen(), desc="Toggle fullscreen on the focused window"),
    Key([mod], "f", lazy.window.toggle_floating(), desc="Toggle floating on the focused window"),
    Key([mod, "shift"], "r", lazy.reload_config(), desc="Reload the config"),
    Key([mod, "shift"], "x", lazy.shutdown(), desc="Shutdown Qtile"),
    Key([mod], "r", lazy.spawncmd(), desc="Spawn a command using a prompt widget"),
    Key([mod], "d", lazy.spawn(mymenu)),
    Key([mod], "w", lazy.spawn(browser)),
    Key([mod, "shift"], "Return", lazy.spawn(files)),
    Key([mod, "mod1"], "s", lazy.spawn(screenie)),
    Key(["mod1"], "s", lazy.spawn(todoist)),
    Key(["mod1"], "n", lazy.spawn(discord)),


    # Movement Keys
    Key([mod], "h", lazy.layout.left(), desc="Move focus to left"),
    Key([mod], "l", lazy.layout.right(), desc="Move focus to right"),
    Key([mod], "j", lazy.layout.down(), desc="Move focus down"),
    Key([mod], "k", lazy.layout.up(), desc="Move focus up"),
    Key([mod], "space", lazy.layout.next(), desc="Move window focus to other window"),

    Key([mod, "shift"], "h", lazy.layout.shuffle_left(), desc="Move window to the left"),
    Key([mod, "shift"], "l", lazy.layout.shuffle_right(), desc="Move window to the right"),
    Key([mod, "shift"], "j", lazy.layout.shuffle_down(), desc="Move window down"),
    Key([mod, "shift"], "k", lazy.layout.shuffle_up(), desc="Move window up"),

    Key([mod, "control"], "h", lazy.layout.grow_left(), desc="Grow window to the left"),
    Key([mod, "control"], "l", lazy.layout.grow_right(), desc="Grow window to the right"),
    Key([mod, "control"], "j", lazy.layout.grow_down(), desc="Grow window down"),
    Key([mod, "control"], "k", lazy.layout.grow_up(), desc="Grow window up"),
    Key([mod], "n", lazy.layout.normalize(), desc="Reset all window sizes"),

# Switch focus to specific monitor (out of three)
    Key([mod], "i", lazy.to_screen(0)),
    Key([mod], "o", lazy.to_screen(1)),

# Switch focus of monitors
    Key([mod], "period", lazy.next_screen()),
    Key([mod], "comma", lazy.prev_screen()),


]

# Create labels for groups and assign them a default layout.
groups = []

group_names = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "minus", "equal", "F1", "F2", "F3", "F4", "F5"]

#group_labels = ["󰖟", "", "", "", "", "", "", "", "ﭮ", "", "", "﨣", "F1", "F2", "F3", "F4", "F5"]
group_labels = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "17"]

group_layouts = ["monadtall", "monadtall", "monadtall", "monadtall", "monadtall", "monadtall", "monadtall", "monadtall", "monadtall", "monadtall", "monadtall", "monadtall", "monadtall", "monadtall", "monadtall", "monadtall", "monadtall"]

# Add group names, labels, and default layouts to the groups object.
for i in range(len(group_names)):
    groups.append(
        Group(
            name=group_names[i],
            layout=group_layouts[i].lower(),
            label=group_labels[i],
        ))

# Add group specific keybindings
for i in groups:
    keys.extend([
        Key([mod], i.name, lazy.group[i.name].toscreen(), desc="Mod + number to move to that group."),
        Key(["mod1"], "Tab", lazy.screen.next_group(), desc="Move to next group."),
        Key(["mod1", "shift"], "Tab", lazy.screen.prev_group(), desc="Move to previous group."),
        Key([mod, "shift"], i.name, lazy.window.togroup(i.name), desc="Move focused window to new group."),
    ])


# Add key bindings to switch VTs in Wayland.
# We can't check qtile.core.name in default config as it is loaded before qtile is started
# We therefore defer the check until the key binding is run by using .when(func=...)
for vt in range(1, 8):
    keys.append(
        Key(
            ["control", "mod1"],
            f"f{vt}",
            lazy.core.change_vt(vt).when(func=lambda: qtile.core.name == "wayland"),
            desc=f"Switch to VT{vt}",
        )
    )

# Define scratchpads
groups.append(ScratchPad("scratchpad", [
    DropDown("term", "kitty --class=scratch", width=0.8, height=0.8, x=0.1, y=0.1, opacity=1),
    DropDown("term2", "kitty --class=scratch", width=0.8, height=0.8, x=0.1, y=0.1, opacity=1),
    DropDown("ranger", "kitty --class=ranger -e ranger", width=0.8, height=0.8, x=0.1, y=0.1, opacity=0.9),
    DropDown("volume", "kitty --class=volume -e pulsemixer", width=0.8, height=0.8, x=0.1, y=0.1, opacity=0.9),
    DropDown("mus", "kitty --class=mus -e flatpak run io.github.hrkfdn.ncspot", width=0.8, height=0.8, x=0.1, y=0.1, opacity=0.9),
    DropDown("news", "kitty --class=news -e newsboat", width=0.8, height=0.8, x=0.1, y=0.1, opacity=0.9),

]))

# Scratchpad keybindings
keys.extend([
    Key([mod], "n", lazy.group['scratchpad'].dropdown_toggle('term')),
    Key([mod], "c", lazy.group['scratchpad'].dropdown_toggle('ranger')),
    Key([mod], "v", lazy.group['scratchpad'].dropdown_toggle('volume')),
    Key([mod], "m", lazy.group['scratchpad'].dropdown_toggle('mus')),
    Key([mod], "b", lazy.group['scratchpad'].dropdown_toggle('news')),
    Key([mod, "shift"], "n", lazy.group['scratchpad'].dropdown_toggle('term2')),
])

# Define layouts and layout themes
layout_theme = {
        "margin":0,
        "border_width": 8,
        "border_focus": colors[6],
        "border_normal": colors[2]
    }

layouts = [
    layout.MonadTall(**layout_theme),
    layout.MonadWide(**layout_theme),
    layout.MonadThreeCol(**layout_theme),
    layout.MonadWide(**layout_theme),
    layout.Floating(**layout_theme),
    layout.Spiral(**layout_theme),
    layout.RatioTile(**layout_theme),
    layout.Max(**layout_theme)
]


widget_defaults = dict(
    font="JetBrains Mono Bold",
    fontsize=14,
    padding=12,
)

extension_defaults = widget_defaults.copy()

decor = {
    "decorations": [
        RectDecoration(
            radius=12,
            filled=True,
            colour=colors[0],
            line_width=2,
            line_colour=colors[2],
        )
    ],
}

screens = [
    Screen(
        bottom=bar.Bar(
            [
                widget.TextBox(
                    text="",
                    mouse_callbacks={
                        "Button1": lambda: qtile.cmd_spawn("rofi -show drun")
                    },
                    foreground=colors[6],
                    decorations=[
                        RectDecoration(
                            radius=12,
                            filled=True,
                            colour=colors[0],
                            line_width=2,
                            line_colour=colors[6],
                        )
                    ],
                ),
                widget.Spacer(length=8),
                widget.GroupBox(
                    highlight_method="text",
                    urgent_alert_method="text",
                    padding=0,
                    spacing=4,
                    margin_x=12,
                    active=colors[5],
                    inactive=colors[1],
                    this_current_screen_border=colors[4],
                    urgent_text=colors[3],
                    hide_unused = True,
                    **decor,
                ),
                widget.Spacer(length=8),
                widget.Mpris2(
                    name="spotify",
                    objname="org.mpris.MediaPlayer2.spotify",
                    format="{xesam:title}",
                    playing_text=" {track}",
                    paused_text=" {track}",
                    max_chars=32,
                    foreground=colors[1],
                    **decor,
                ),
                widget.Spacer(),
                widget.CheckUpdates(
                    distro="Arch_checkupdates",
                    no_update_string=" 0 Updates",
                    display_format=" {updates} Updates",
                    colour_have_updates=colors[7],
                    colour_no_updates=colors[7],
                    **decor,
                ),
                widget.Spacer(length=8),
                widget.DF(
                    visible_on_warn=False,
                    format=" {uf} {m}",
                    foreground=colors[8],
                    **decor,
                ),
                widget.Spacer(length=8),
                widget.Load(
                    update_interval=15,
                    format=" {load:.2f}",
                    foreground=colors[7],
                    **decor,
                ),
                widget.Spacer(length=8),
                widget.ThermalZone(
                    zone="/sys/class/thermal/thermal_zone2/temp",
                    update_interval=15,
                    format=" {temp}°C",
                    fgcolor_normal=colors[8],
                    fgcolor_high=colors[5],
                    fgcolor_crit=colors[3],
                    **decor,
                ),
                widget.Spacer(length=8),
                widget.Memory(
                    update_interval=15,
                    format=" {NotAvailable:.2f} {mm}",
                    measure_mem="G",
                    foreground=colors[7],
                    **decor,
                ),
                widget.Spacer(length=8),
                widget.Net(
                    update_interval=15,
                    format=" {down:.0f} {down_suffix}",
                    foreground=colors[8],
                    **decor,
                ),
                widget.Spacer(length=8),
                widget.Net(
                    update_interval=15,
                    format=" {up:.0f} {up_suffix}",
                    foreground=colors[7],
                    **decor,
                ),
                widget.Spacer(length=8),
                widget.Volume(
                    unmute_format=" {volume}/100",
                    mute_format=" 0/100",
                    foreground=colors[8],
                    **decor,
                ),
                widget.Spacer(length=8),
                widget.Wttr(
                    format=" %t, %C",
                    foreground=colors[7],
                    **decor,
                ),
                widget.Spacer(length=8),
                widget.Clock(
                    format=" %d-%m-%y, %H:%M",
                    foreground=colors[8],
                    **decor,
                ),
                widget.Spacer(length=8),
                widget.QuickExit(
                    default_text="",
                    countdown_format="{}",
                    foreground=colors[3],
                    decorations=[
                        RectDecoration(
                            radius=12,
                            filled=True,
                            colour=colors[0],
                            line_width=2,
                            line_colour=colors[3],
                        )
                    ],
                ),
            ],
            32,
            background=colors[0],
            border_width=8,
            border_color=colors[0],
        ),
    ),
    Screen(
        bottom=bar.Bar(
            [
                widget.TextBox(
                    text="",
                    mouse_callbacks={
                        "Button1": lambda: qtile.cmd_spawn("rofi -show drun")
                    },
                    foreground=colors[6],
                    decorations=[
                        RectDecoration(
                            radius=12,
                            filled=True,
                            colour=colors[0],
                            line_width=2,
                            line_colour=colors[6],
                        )
                    ],
                ),
                widget.Spacer(length=8),
                widget.GroupBox(
                    highlight_method="text",
                    urgent_alert_method="text",
                    padding=0,
                    spacing=4,
                    margin_x=12,
                    active=colors[5],
                    inactive=colors[1],
                    this_current_screen_border=colors[4],
                    urgent_text=colors[3],
                    hide_unused = True,
                    **decor,
                ),
                widget.Spacer(length=8),
                widget.Mpris2(
                    name="spotify",
                    objname="org.mpris.MediaPlayer2.spotify",
                    format="{xesam:title}",
                    playing_text=" {track}",
                    paused_text=" {track}",
                    max_chars=32,
                    foreground=colors[1],
                    **decor,
                ),
                widget.Spacer(),
                widget.CheckUpdates(
                    distro="Arch_checkupdates",
                    no_update_string=" 0 Updates",
                    display_format=" {updates} Updates",
                    colour_have_updates=colors[7],
                    colour_no_updates=colors[7],
                    **decor,
                ),
                widget.Spacer(length=8),
                widget.DF(
                    visible_on_warn=False,
                    format=" {uf} {m}",
                    foreground=colors[8],
                    **decor,
                ),
                widget.Spacer(length=8),
                widget.Load(
                    update_interval=15,
                    format=" {load:.2f}",
                    foreground=colors[7],
                    **decor,
                ),
                widget.Spacer(length=8),
                widget.ThermalZone(
                    zone="/sys/class/thermal/thermal_zone2/temp",
                    update_interval=15,
                    format=" {temp}°C",
                    fgcolor_normal=colors[8],
                    fgcolor_high=colors[5],
                    fgcolor_crit=colors[3],
                    **decor,
                ),
                widget.Spacer(length=8),
                widget.Memory(
                    update_interval=15,
                    format=" {NotAvailable:.2f} {mm}",
                    measure_mem="G",
                    foreground=colors[7],
                    **decor,
                ),
                widget.Spacer(length=8),
                widget.Net(
                    update_interval=15,
                    format=" {down:.0f} {down_suffix}",
                    foreground=colors[8],
                    **decor,
                ),
                widget.Spacer(length=8),
                widget.Net(
                    update_interval=15,
                    format=" {up:.0f} {up_suffix}",
                    foreground=colors[7],
                    **decor,
                ),
                widget.Spacer(length=8),
                widget.Volume(
                    unmute_format=" {volume}/100",
                    mute_format=" 0/100",
                    foreground=colors[8],
                    **decor,
                ),
                widget.Spacer(length=8),
                widget.Wttr(
                    format=" %t, %C",
                    foreground=colors[7],
                    **decor,
                ),
                widget.Spacer(length=8),
                widget.Clock(
                    format=" %d-%m-%y, %H:%M",
                    foreground=colors[8],
                    **decor,
                ),
                widget.Spacer(length=8),
                widget.QuickExit(
                    default_text="",
                    countdown_format="{}",
                    foreground=colors[3],
                    decorations=[
                        RectDecoration(
                            radius=12,
                            filled=True,
                            colour=colors[0],
                            line_width=2,
                            line_colour=colors[3],
                        )
                    ],
                ),
            ],
            32,
            background=colors[0],
            border_width=8,
            border_color=colors[0],
        ),
    ),
    Screen(
        bottom=bar.Bar(
            [
                widget.TextBox(
                    text="",
                    mouse_callbacks={
                        "Button1": lambda: qtile.cmd_spawn("rofi -show drun")
                    },
                    foreground=colors[6],
                    decorations=[
                        RectDecoration(
                            radius=12,
                            filled=True,
                            colour=colors[0],
                            line_width=2,
                            line_colour=colors[6],
                        )
                    ],
                ),
                widget.Spacer(length=8),
                widget.GroupBox(
                    highlight_method="text",
                    urgent_alert_method="text",
                    padding=0,
                    spacing=4,
                    margin_x=12,
                    active=colors[5],
                    inactive=colors[1],
                    this_current_screen_border=colors[4],
                    urgent_text=colors[3],
                    hide_unused = True,
                    **decor,
                ),
                widget.Spacer(length=8),
                widget.Mpris2(
                    name="spotify",
                    objname="org.mpris.MediaPlayer2.spotify",
                    format="{xesam:title}",
                    playing_text=" {track}",
                    paused_text=" {track}",
                    max_chars=32,
                    foreground=colors[1],
                    **decor,
                ),
                widget.Spacer(),
                widget.CheckUpdates(
                    distro="Arch_checkupdates",
                    no_update_string=" 0 Updates",
                    display_format=" {updates} Updates",
                    colour_have_updates=colors[7],
                    colour_no_updates=colors[7],
                    **decor,
                ),
                widget.Spacer(length=8),
                widget.DF(
                    visible_on_warn=False,
                    format=" {uf} {m}",
                    foreground=colors[8],
                    **decor,
                ),
                widget.Spacer(length=8),
                widget.Load(
                    update_interval=15,
                    format=" {load:.2f}",
                    foreground=colors[7],
                    **decor,
                ),
                widget.Spacer(length=8),
                widget.ThermalZone(
                    zone="/sys/class/thermal/thermal_zone2/temp",
                    update_interval=15,
                    format=" {temp}°C",
                    fgcolor_normal=colors[8],
                    fgcolor_high=colors[5],
                    fgcolor_crit=colors[3],
                    **decor,
                ),
                widget.Spacer(length=8),
                widget.Memory(
                    update_interval=15,
                    format=" {NotAvailable:.2f} {mm}",
                    measure_mem="G",
                    foreground=colors[7],
                    **decor,
                ),
                widget.Spacer(length=8),
                widget.Net(
                    update_interval=15,
                    format=" {down:.0f} {down_suffix}",
                    foreground=colors[8],
                    **decor,
                ),
                widget.Spacer(length=8),
                widget.Net(
                    update_interval=15,
                    format=" {up:.0f} {up_suffix}",
                    foreground=colors[7],
                    **decor,
                ),
                widget.Spacer(length=8),
                widget.Volume(
                    unmute_format=" {volume}/100",
                    mute_format=" 0/100",
                    foreground=colors[8],
                    **decor,
                ),
                widget.Spacer(length=8),
                widget.Wttr(
                    format=" %t, %C",
                    foreground=colors[7],
                    **decor,
                ),
                widget.Spacer(length=8),
                widget.Clock(
                    format=" %d-%m-%y, %H:%M",
                    foreground=colors[8],
                    **decor,
                ),
                widget.Spacer(length=8),
                widget.QuickExit(
                    default_text="",
                    countdown_format="{}",
                    foreground=colors[3],
                    decorations=[
                        RectDecoration(
                            radius=12,
                            filled=True,
                            colour=colors[0],
                            line_width=2,
                            line_colour=colors[3],
                        )
                    ],
                ),
            ],
            32,
            background=colors[0],
            border_width=8,
            border_color=colors[0],
        ),
    ),
    Screen(
        bottom=bar.Bar(
            [
                widget.TextBox(
                    text="",
                    mouse_callbacks={
                        "Button1": lambda: qtile.cmd_spawn("rofi -show drun")
                    },
                    foreground=colors[6],
                    decorations=[
                        RectDecoration(
                            radius=12,
                            filled=True,
                            colour=colors[0],
                            line_width=2,
                            line_colour=colors[6],
                        )
                    ],
                ),
                widget.Spacer(length=8),
                widget.GroupBox(
                    highlight_method="text",
                    urgent_alert_method="text",
                    padding=0,
                    spacing=4,
                    margin_x=12,
                    active=colors[5],
                    inactive=colors[1],
                    this_current_screen_border=colors[4],
                    urgent_text=colors[3],
                    hide_unused = True,
                    **decor,
                ),
                widget.Spacer(length=8),
                widget.Mpris2(
                    name="spotify",
                    objname="org.mpris.MediaPlayer2.spotify",
                    format="{xesam:title}",
                    playing_text=" {track}",
                    paused_text=" {track}",
                    max_chars=32,
                    foreground=colors[1],
                    **decor,
                ),
                widget.Systray(icon_size=24),
                widget.Spacer(),
                widget.CheckUpdates(
                    distro="Arch_checkupdates",
                    no_update_string=" 0 Updates",
                    display_format=" {updates} Updates",
                    colour_have_updates=colors[7],
                    colour_no_updates=colors[7],
                    **decor,
                ),
                widget.Spacer(length=8),
                widget.DF(
                    visible_on_warn=False,
                    format=" {uf} {m}",
                    foreground=colors[8],
                    **decor,
                ),
                widget.Spacer(length=8),
                widget.Load(
                    update_interval=15,
                    format=" {load:.2f}",
                    foreground=colors[7],
                    **decor,
                ),
                widget.Spacer(length=8),
                widget.ThermalZone(
                    zone="/sys/class/thermal/thermal_zone2/temp",
                    update_interval=15,
                    format=" {temp}°C",
                    fgcolor_normal=colors[8],
                    fgcolor_high=colors[5],
                    fgcolor_crit=colors[3],
                    **decor,
                ),
                widget.Spacer(length=8),
                widget.Memory(
                    update_interval=15,
                    format=" {NotAvailable:.2f} {mm}",
                    measure_mem="G",
                    foreground=colors[7],
                    **decor,
                ),
                widget.Spacer(length=8),
                widget.Net(
                    update_interval=15,
                    format=" {down:.0f} {down_suffix}",
                    foreground=colors[8],
                    **decor,
                ),
                widget.Spacer(length=8),
                widget.Net(
                    update_interval=15,
                    format=" {up:.0f} {up_suffix}",
                    foreground=colors[7],
                    **decor,
                ),
                widget.Spacer(length=8),
                widget.Volume(
                    unmute_format=" {volume}/100",
                    mute_format=" 0/100",
                    foreground=colors[8],
                    **decor,
                ),
                widget.Spacer(length=8),
                widget.Wttr(
                    format=" %t, %C",
                    foreground=colors[7],
                    **decor,
                ),
                widget.Spacer(length=8),
                widget.Clock(
                    format=" %d-%m-%y, %H:%M",
                    foreground=colors[8],
                    **decor,
                ),
                widget.Spacer(length=8),
                widget.QuickExit(
                    default_text="",
                    countdown_format="{}",
                    foreground=colors[3],
                    decorations=[
                        RectDecoration(
                            radius=12,
                            filled=True,
                            colour=colors[0],
                            line_width=2,
                            line_colour=colors[3],
                        )
                    ],
                ),
            ],
            32,
            background=colors[0],
            border_width=8,
            border_color=colors[0],
        ),
    ),
]




# Drag floating layouts.
mouse = [
    Drag([mod], "Button1", lazy.window.set_position_floating(), start=lazy.window.get_position()),
    Drag([mod], "Button3", lazy.window.set_size_floating(), start=lazy.window.get_size()),
    Click([mod], "Button2", lazy.window.bring_to_front()),
]

dgroups_key_binder = None
dgroups_app_rules = []  # type: list
#follow_mouse_focus = True
bring_front_click = False
floats_kept_above = True
cursor_warp = True
floating_layout = layout.Floating(
    float_rules=[
        # Run the utility of `xprop` to see the wm class and name of an X client.
        *layout.Floating.default_float_rules,
        Match(wm_class="confirmreset"),  # gitk
        Match(wm_class="makebranch"),  # gitk
        Match(wm_class="maketag"),  # gitk
        Match(wm_class="ssh-askpass"),  # ssh-askpass
        Match(title="branchdialog"),  # gitk
        Match(title="pinentry"),  # GPG key password entry
    ]
)
auto_fullscreen = True
focus_on_window_activation = "smart"
reconfigure_screens = True

@hook.subscribe.startup_once
def autostart():
    home = os.path.expanduser('~/.config/qtile/autostart.sh')
    subprocess.Popen([home])

# If things like steam games want to auto-minimize themselves when losing
# focus, should we respect this or not?
auto_minimize = True

# When using the Wayland backend, this can be used to configure input devices.
wl_input_rules = None

wmname = "qtile"

