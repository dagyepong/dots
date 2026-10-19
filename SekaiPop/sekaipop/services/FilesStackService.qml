pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common

// === files stack ===
// What the dock's Files key (Dock.qml, DockFilesCard.qml) needs that is not drawing:
// which folder it starts in, how things are sorted, how a file is described, and the
// few things you can do to a file. It holds no file list and watches nothing: the
// card lists the folder itself (a FolderListModel that only exists while the card is
// open), so with the card closed this singleton costs a few properties.
//
// Settings (Settings -> Desktop -> Files stack):
//   dock.filesMode         "stack" (the key opens the card) | "manager" (the old behaviour:
//                          it runs `dock.filesCommand`)
//   dock.files.folder      where the stack starts: "" (Downloads), a place name (Downloads,
//                          Documents, Pictures, Videos, Music, Desktop, Trash) or a path (~/Projects)
//   dock.files.view        grid | list
//   dock.files.sort        name | date | type
//   dock.files.reverse     flip the order (dates start with the newest)
//   dock.files.hidden      show dotfiles
//   dock.files.foldersFirst  keep folders above the files (off: one list, sorted together)
//   dock.files.modified    only what was modified: any | today | week | month | year
//
// Every path that reaches a process goes in as its own argument (or as $1 / $2 of a
// fixed script), never spliced into a command line, so a name with spaces, quotes or
// a leading dash is just a name.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME") || ""

    // ===== settings =====
    readonly property string mode: SettingsService.get("dock.filesMode")
    readonly property bool stackOn: root.mode !== "manager"
    readonly property string view: SettingsService.get("dock.files.view") === "list" ? "list" : "grid"
    readonly property string sortBy: {
        const s = SettingsService.get("dock.files.sort")
        return s === "date" || s === "type" ? s : "name"
    }
    readonly property bool reverse: SettingsService.flag("dock.files.reverse")
    readonly property bool showHidden: SettingsService.flag("dock.files.hidden")
    readonly property bool foldersFirst: SettingsService.flag("dock.files.foldersFirst")

    // The "modified" filter: everything, or only what changed since then. It applies to
    // folders too (a folder's date is when something was last added to it or removed).
    readonly property var modifiedOptions: [
        { id: "any",   label: "Any time",     icon: "all_inclusive" },
        { id: "today", label: "Today",        icon: "today" },
        { id: "week",  label: "Past 7 days",  icon: "date_range" },
        { id: "month", label: "Past 30 days", icon: "calendar_month" },
        { id: "year",  label: "Past year",    icon: "event" }
    ]
    readonly property string modified: {
        const m = String(SettingsService.get("dock.files.modified"))
        return root.modifiedOptions.some(o => o.id === m) ? m : "any"
    }

    function modifiedLabel(id) {
        const o = root.modifiedOptions.find(x => x.id === id)
        return o ? o.label : ""
    }

    // The oldest modification time (ms) that still passes the filter; 0 for "any".
    // `tick` only exists so a binding can ask again (midnight passes while a card is kept).
    function cutoffFor(id, tick) {
        const now = new Date()
        const day = 86400000
        if (id === "today")
            return new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime()
        if (id === "week")
            return now.getTime() - 7 * day
        if (id === "month")
            return now.getTime() - 30 * day
        if (id === "year")
            return now.getTime() - 365 * day
        return 0
    }

    // ===== where things are =====
    // ~/.config/user-dirs.dirs, read once (no watcher). Without it the English names are used.
    property var userDirs: ({})

    readonly property var placeNames: ({
        DOWNLOAD: "Downloads", DOCUMENTS: "Documents", PICTURES: "Pictures",
        VIDEOS: "Videos", MUSIC: "Music", DESKTOP: "Desktop", TRASH: "Trash"
    })

    // The row of places along the top of the Files card (DockFilesCard.qml), in this order.
    readonly property var places: [
        { key: "DOWNLOAD",  label: "Downloads", icon: "download" },
        { key: "DOCUMENTS", label: "Documents", icon: "description" },
        { key: "PICTURES",  label: "Pictures",  icon: "image" },
        { key: "VIDEOS",    label: "Videos",    icon: "movie" },
        { key: "MUSIC",     label: "Music",     icon: "music_note" },
        { key: "TRASH",     label: "Trash",     icon: "delete" }
    ]

    // ===== the trash =====
    // The freedesktop trash of the home partition: files/ holds what was deleted, info/
    // holds one .trashinfo per item (where it came from, when it was deleted).
    readonly property string dataHome: Quickshell.env("XDG_DATA_HOME") || (root.home + "/.local/share")
    readonly property string trashDir: root.dataHome + "/Trash"
    readonly property string trashPath: root.trashDir + "/files"

    function inTrash(path) {
        const p = String(path)
        return p === root.trashPath || p.startsWith(root.trashPath + "/")
    }

    // Is this one of the trash's own items (not something inside a trashed folder)?
    function isTrashItem(path) {
        const p = String(path)
        return p.startsWith(root.trashPath + "/") && p.indexOf("/", root.trashPath.length + 1) < 0
    }

    // Which place of the row a path is in (the deepest one), or "".
    function placeKeyOf(path) {
        const p = String(path)
        let best = ""
        let bestLen = 0
        for (const pl of root.places) {
            const base = root.placePath(pl.key)
            if ((p === base || p.startsWith(base + "/")) && base.length > bestLen) {
                best = pl.key
                bestLen = base.length
            }
        }
        return best
    }

    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (root.home + "/.config")

    FileView {
        path: root.configHome + "/user-dirs.dirs"
        printErrors: false      // no such file is normal on a minimal system
        onLoaded: {
            const out = {}
            for (const line of text().split("\n")) {
                const m = line.match(/^XDG_([A-Z]+)_DIR="?([^"]*)"?\s*$/)
                if (m)
                    out[m[1]] = m[2].replace(/^\$HOME/, root.home)
            }
            root.userDirs = out
        }
    }

    function placePath(key) {
        const k = String(key).toUpperCase()
        if (k === "TRASH")
            return root.trashPath
        const p = root.userDirs[k]
        if (p && p.startsWith("/"))
            return p
        return root.home + "/" + (root.placeNames[k] ?? "Downloads")
    }

    // What the setting means as an absolute path.
    function resolve(setting) {
        let s = String(setting ?? "").trim()
        if (s === "")
            return root.placePath("DOWNLOAD")
        for (const k of Object.keys(root.placeNames)) {
            if (s.toLowerCase() === root.placeNames[k].toLowerCase())
                return root.placePath(k)
        }
        if (s === "~")
            s = root.home
        else if (s.startsWith("~/"))
            s = root.home + s.substring(1)
        else if (s.startsWith("$HOME/"))
            s = root.home + s.substring(5)
        else if (!s.startsWith("/"))
            s = root.home + "/" + s
        s = s.replace(/\/{2,}/g, "/")
        return s.length > 1 ? s.replace(/\/+$/, "") : s
    }

    readonly property string configuredRoot: root.resolve(SettingsService.get("dock.files.folder"))

    // The right-click menu of the Files key picks a place for the next opening only
    // (the card takes it when it opens).
    property string override: ""

    function takeOverride() {
        const o = root.override
        root.override = ""
        return o
    }

    function titleFor(path) {
        if (path === "/")
            return "/"
        if (path === root.home)
            return "Home"
        if (path === root.trashPath)
            return "Trash"
        const parts = String(path).split("/").filter(p => p !== "")
        return parts.length > 0 ? parts[parts.length - 1] : "/"
    }

    // ===== describing a file =====
    readonly property var imageSuffixes: ["png", "jpg", "jpeg", "webp", "bmp", "gif", "svg"]
    // A picture bigger than this shows its type icon, not a thumbnail (decoding it
    // just to draw 48 px is not worth the memory).
    readonly property real thumbMaxBytes: 24 * 1024 * 1024

    // suffix -> [what it is, icon name in the icon theme]
    readonly property var kinds: {
        const k = {}
        const add = (list, label, icon) => list.forEach(s => k[s] = [label, icon])
        add(["png", "jpg", "jpeg", "webp", "bmp", "gif", "tif", "tiff", "avif", "heic", "ico", "raw"], "Image", "image-x-generic")
        add(["svg"], "Vector image", "image-svg+xml")
        add(["mp4", "mkv", "webm", "mov", "avi", "m4v", "flv", "wmv", "mpg", "mpeg", "3gp", "ogv"], "Video", "video-x-generic")
        add(["mp3", "flac", "ogg", "opus", "wav", "m4a", "aac"], "Audio", "audio-x-generic")
        add(["pdf"], "PDF", "application-pdf")
        add(["zip", "tar", "gz", "xz", "bz2", "zst", "7z", "rar", "tgz"], "Archive", "package-x-generic")
        add(["iso", "img"], "Disk image", "application-x-cd-image")
        add(["txt", "log"], "Text", "text-x-generic")
        add(["md", "markdown", "rst"], "Markdown", "text-x-markdown")
        add(["doc", "docx", "odt", "rtf"], "Document", "x-office-document")
        add(["xls", "xlsx", "ods", "csv", "tsv"], "Spreadsheet", "x-office-spreadsheet")
        add(["ppt", "pptx", "odp"], "Presentation", "x-office-presentation")
        add(["sh", "bash", "zsh", "fish"], "Shell script", "text-x-script")
        add(["py", "js", "ts", "qml", "c", "h", "cpp", "hpp", "rs", "go", "java", "lua", "css", "html", "json", "toml", "yaml", "yml", "xml", "ini", "conf"], "Code", "text-x-generic")
        add(["deb", "rpm", "appimage", "flatpakref"], "Package", "application-x-executable")
        add(["ttf", "otf", "woff", "woff2"], "Font", "font-x-generic")
        add(["epub", "mobi"], "E-book", "application-epub+zip")
        return k
    }

    // ===== video thumbnails =====
    // A video's picture is one frame, made by ffmpegthumbnailer (or ffmpeg when that is what
    // is installed) into ~/.cache/sekaipop/video-thumbs/<key>.jpg, 256 px wide, once: the key
    // is made from the path, size and date, so a changed file gets a new one. Nothing is made
    // for a video the card is not showing (a job that has not started is dropped when its
    // icon goes away), at most two run at a time, and a file that can't be read keeps its
    // type icon. With neither tool installed nothing is tried again this session. Thumbnails
    // not touched for 60 days are deleted (checked on the first job of a session); deleting
    // the whole folder is always safe.
    readonly property string cacheHome: Quickshell.env("XDG_CACHE_HOME") || (root.home + "/.cache")
    readonly property string thumbDir: root.cacheHome + "/sekaipop/video-thumbs"

    property bool videoThumbsOk: true
    // key -> true once its jpg exists / once it can't be made (replaced as a whole, so bindings see it)
    property var videoDone: ({})
    property var videoFailed: ({})
    property var thumbQueue: []
    property bool thumbPruned: false
    // What the two workers (jobA, jobB below) are making now, or null.
    property var thumbJobs: [null, null]

    function isVideo(suffix) {
        const k = root.kinds[String(suffix).toLowerCase()]
        return !!k && k[0] === "Video"
    }

    function videoThumbKey(path, bytes, modified) {
        return Qt.md5(String(path) + "|" + Number(bytes) + "|" + Number(modified))
    }

    function videoThumbUrl(key) {
        return root.fileUrl(root.thumbDir + "/" + key + ".jpg")
    }

    function requestVideoThumb(key, path) {
        if (!root.videoThumbsOk || root.videoDone[key] === true || root.videoFailed[key] === true)
            return
        if (root.thumbQueue.some(j => j.key === key) || root.thumbJobs.some(j => j !== null && j.key === key))
            return
        root.thumbQueue = root.thumbQueue.concat([{ key: key, path: path }])
        root.pumpThumbs()
    }

    // The icon went away before its job started.
    function cancelVideoThumb(key) {
        root.thumbQueue = root.thumbQueue.filter(j => j.key !== key)
    }

    function pumpThumbs() {
        const workers = [jobA, jobB]
        for (let i = 0; i < workers.length; i++) {
            if (root.thumbQueue.length === 0 || !root.videoThumbsOk)
                return
            if (root.thumbJobs[i] !== null)
                continue
            const j = root.thumbQueue[0]
            root.thumbQueue = root.thumbQueue.slice(1)
            const jobs = root.thumbJobs.slice()
            jobs[i] = j
            root.thumbJobs = jobs
            const prune = root.thumbPruned ? "0" : "1"
            root.thumbPruned = true
            workers[i].exec(["sh", "-c", root.thumbScript, "sh", j.path, root.thumbDir + "/" + j.key + ".jpg", root.thumbDir, prune])
        }
    }

    function thumbFinished(i, code) {
        const j = root.thumbJobs[i]
        const jobs = root.thumbJobs.slice()
        jobs[i] = null
        root.thumbJobs = jobs
        if (j) {
            const m = {}
            m[j.key] = true
            if (code === 0)
                root.videoDone = Object.assign({}, root.videoDone, m)
            else
                root.videoFailed = Object.assign({}, root.videoFailed, m)
        }
        if (code === 3) {
            // No ffmpegthumbnailer and no ffmpeg.
            root.videoThumbsOk = false
            root.thumbQueue = []
        }
        root.pumpThumbs()
    }

    Process {
        id: jobA
        onExited: code => root.thumbFinished(0, code)
    }

    Process {
        id: jobB
        onExited: code => root.thumbFinished(1, code)
    }

    readonly property string thumbScript: (
            "path=$1\n"
            + "out=$2\n"
            + "dir=$3\n"
            + "prune=$4\n"
            + "mkdir -p -- \"$dir\" || exit 1\n"
            + "[ \"$prune\" = 1 ] && find \"$dir\" -type f -mtime +60 -delete 2>/dev/null\n"
            + "[ -s \"$out\" ] && exit 0\n"
            + "[ -r \"$path\" ] || exit 1\n"
            + "T=\"\"\n"
            + "command -v timeout >/dev/null 2>&1 && T=\"timeout 20\"\n"
            + "tmp=\"$out.tmp.jpg\"\n"
            + "if command -v ffmpegthumbnailer >/dev/null 2>&1; then\n"
            + "  $T ffmpegthumbnailer -i \"$path\" -o \"$tmp\" -s 256 -q 6 >/dev/null 2>&1\n"
            + "elif command -v ffmpeg >/dev/null 2>&1; then\n"
            + "  $T ffmpeg -nostdin -v error -y -ss 2 -i \"$path\" -frames:v 1 -vf scale=256:-2 \"$tmp\" >/dev/null 2>&1\n"
            + "  [ -s \"$tmp\" ] || $T ffmpeg -nostdin -v error -y -i \"$path\" -frames:v 1 -vf scale=256:-2 \"$tmp\" >/dev/null 2>&1\n"
            + "else\n"
            + "  exit 3\n"
            + "fi\n"
            + "if [ -s \"$tmp\" ]; then\n"
            + "  mv -f -- \"$tmp\" \"$out\"\n"
            + "else\n"
            + "  rm -f -- \"$tmp\"\n"
            + "  exit 1\n"
            + "fi\n"
    )

    // Special folders get their own icon when the theme has one.
    readonly property var folderIcons: ({
        "Downloads": "folder-download", "Documents": "folder-documents", "Pictures": "folder-pictures",
        "Videos": "folder-videos", "Music": "folder-music", "Desktop": "user-desktop"
    })

    function suffixOf(name) {
        const i = String(name).lastIndexOf(".")
        return i > 0 ? String(name).substring(i + 1).toLowerCase() : ""
    }

    function isImage(suffix) {
        return root.imageSuffixes.indexOf(String(suffix).toLowerCase()) >= 0
    }

    function iconNameFor(isDir, suffix, name) {
        if (isDir)
            return root.folderIcons[name] ?? "folder"
        const k = root.kinds[String(suffix).toLowerCase()]
        return k ? k[1] : "text-x-generic"
    }

    function typeLabel(isDir, suffix) {
        if (isDir)
            return "Folder"
        const k = root.kinds[String(suffix).toLowerCase()]
        if (k)
            return k[0]
        return suffix !== "" ? String(suffix).toUpperCase() + " file" : "File"
    }

    function sizeText(bytes) {
        const b = Number(bytes)
        if (!(b >= 0))
            return ""
        if (b < 1000)
            return b + " B"
        const units = ["kB", "MB", "GB", "TB"]
        let v = b / 1000
        let i = 0
        while (v >= 999.5 && i < units.length - 1) {
            v /= 1000
            i++
        }
        return (v >= 100 ? v.toFixed(0) : v.toFixed(1)) + " " + units[i]
    }

    // Today: the time. This year: day and month. Older: with the year.
    function dateText(date) {
        const d = new Date(date)
        if (isNaN(d.getTime()))
            return ""
        const now = new Date()
        if (d.toDateString() === now.toDateString())
            return Qt.formatTime(d, "hh:mm")
        if (d.getFullYear() === now.getFullYear())
            return Qt.formatDate(d, "d MMM")
        return Qt.formatDate(d, "d MMM yyyy")
    }

    // A name for one line: a newline inside it would break the row.
    function oneLine(name) {
        return String(name).replace(/[\r\n\t]+/g, " ")
    }

    // ===== doing things with a path =====
    function fileUrl(path) {
        return IconCursorService.fileUrl(path)
    }

    // The default application (folders: the default file manager).
    function open(path) {
        Quickshell.execDetached(["xdg-open", path])
    }

    function openInManager(dir) {
        Quickshell.execDetached(["xdg-open", dir])
    }

    // The file manager with the item selected (FileManager1 over D-Bus); the folder
    // that holds it, when no file manager answers.
    function reveal(path) {
        const dir = path.substring(0, Math.max(1, path.lastIndexOf("/")))
        Quickshell.execDetached(["sh", "-c",
            "gdbus call --session --dest org.freedesktop.FileManager1 --object-path /org/freedesktop/FileManager1 "
            + "--method org.freedesktop.FileManager1.ShowItems \"[\\\"$1\\\"]\" \"\" >/dev/null 2>&1 || xdg-open \"$2\"",
            "sh", root.fileUrl(path), dir])
    }

    function copyPath(path) {
        Quickshell.execDetached(["wl-copy", "--", path])
    }

    // On the clipboard as a file: paste it in a file manager.
    function copyFile(path) {
        Quickshell.execDetached(["sh", "-c", "printf '%s\\r\\n' \"$1\" | wl-copy --type text/uri-list", "sh", root.fileUrl(path)])
    }

    function addToShelf(path) {
        ShelfService.addFile(path)
    }

    // Empties the trash (gio when there is one, else the two folders' contents).
    function emptyTrash() {
        Quickshell.execDetached(["sh", "-c",
            "gio trash --empty >/dev/null 2>&1 || find \"$1/files\" \"$1/info\" -mindepth 1 -delete >/dev/null 2>&1",
            "sh", root.trashDir])
    }

    // Puts a trashed item back where it was deleted from (its .trashinfo says where). If
    // something is there now, it comes back as "name (restored)". Only for the trash's own
    // items; a relative Path= (a trash on another disk) is left alone.
    function restore(path) {
        Quickshell.execDetached(["bash", "-c",
            "f=$1\n"
            + "n=${f##*/}\n"
            + "t=${f%/files/*}\n"
            + "info=\"$t/info/$n.trashinfo\"\n"
            + "[ -f \"$info\" ] || exit 1\n"
            + "p=$(sed -n 's/^Path=//p' \"$info\" | head -n 1)\n"
            + "p=$(printf '%s' \"$p\" | sed 's/\\\\/\\\\\\\\/g; s/%/\\\\x/g')\n"
            + "p=$(printf '%b' \"$p\")\n"
            + "case $p in /*) ;; *) exit 1;; esac\n"
            + "dir=${p%/*}\n"
            + "[ -n \"$dir\" ] || dir=/\n"
            + "mkdir -p -- \"$dir\" || exit 1\n"
            + "d=$p\n"
            + "i=1\n"
            + "while [ -e \"$d\" ] || [ -L \"$d\" ]; do\n"
            + "  if [ $i -eq 1 ]; then d=\"$p (restored)\"; else d=\"$p (restored $i)\"; fi\n"
            + "  i=$((i+1))\n"
            + "done\n"
            + "mv -- \"$f\" \"$d\" && rm -f -- \"$info\"\n",
            "bash", path])
    }

    // Opens the trash in the file manager (trash:/// when gio knows it).
    function openTrashInManager() {
        Quickshell.execDetached(["sh", "-c",
            "gio open trash:/// >/dev/null 2>&1 || xdg-open \"$1\"", "sh", root.trashPath])
    }

    function useAsStackFolder(path) {
        SettingsService.set("dock.files.folder", path)
    }
}
