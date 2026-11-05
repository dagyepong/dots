import Quickshell
import qs.bar
import qs.osd
import qs.launcher
import qs.wallpaper
import qs.ipc
import qs.lock
import qs.sysmon
import qs.widgets
import qs.hello
import qs.settings
import qs.welcome

ShellRoot {
    Bar {}
    Osd {}
    LauncherIpc {}
    WallpaperPicker {}
    ShellIpc {}
    LockScreen {}
    SysPill {}
    Hello {}
    StylePicker {}
    Identify {}
    SettingsWindow {}
    WelcomeWindow {}
    IdleWatcher {}
}
