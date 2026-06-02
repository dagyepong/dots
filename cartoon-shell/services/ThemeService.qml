pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.commons
import qs.services

Singleton {
  id: root

  readonly property string themesDirectory: Quickshell.shellDir + "/assets/themes"
  readonly property string stateFilePath: Directories.shellConfigColoursPath
  readonly property string matugenFilePath: Directories.assetsPath + "/themes/matugen.json"

  property list<string> themeFiles: []
  property bool loading: false
  property alias palette: adapter

  // Theme property - sẽ chứa theme theo format mới
  property var theme: getFallbackTheme()

  readonly property bool isInitialized: true
  property Timer reloadTimer: Timer {
    interval: 200
    repeat: false
    onTriggered: {
      root.refresh();
    }
  }

  signal themeReloaded

  readonly property list<string> validMatugenSchemes: ["scheme-content", "scheme-expressive", "scheme-fidelity", "scheme-fruit-salad", "scheme-monochrome", "scheme-neutral", "scheme-rainbow", "scheme-tonal-spot", "scheme-vibrant"]

  readonly property var matugenMap: ({
      primary: "mPrimary",
      on_primary: "mOnPrimary",
      primary_container: "mPrimaryContainer",
      on_primary_container: "mOnPrimaryContainer",
      secondary: "mSecondary",
      on_secondary: "mOnSecondary",
      tertiary: "mTertiary",
      on_tertiary: "mOnTertiary",
      background: "mBackground",
      on_background: "mOnBackground",
      surface: "mSurface",
      on_surface: "mOnSurface",
      surface_variant: "mSurfaceVariant",
      on_surface_variant: "mOnSurfaceVariant",
      surface_container: "mSurfaceContainer",
      surface_container_low: "mSurfaceContainerLow",
      surface_container_high: "mSurfaceContainerHigh",
      surface_container_highest: "mSurfaceContainerHighest",
      surface_tint: "mSurfaceTint",
      outline: "mOutline",
      shadow: "mShadow",
      error: "mError",
      on_error: "mOnError",
      error_container: "mErrorContainer",
      on_error_container: "mOnErrorContainer"
  })

  // Thêm map cho theme mới sang Material Design 3
  readonly property var themeToMaterialMap: ({
      "primary.background": "mBackground",
      "primary.foreground": "mOnBackground",
      "primary.dim_background": "mSurfaceContainerLow",
      "primary.dim_foreground": "mOnSurfaceVariant",
      "primary.bright_foreground": "mPrimary",
      "button.background": "mSurfaceVariant",
      "button.text": "mPrimary",
      "button.background_select": "mOutline",
      "button.border": "mOutline",
      "button.border_select": "mOutline",
      "normal.red": "mError",
      "normal.green": "mPrimary",
      "normal.yellow": "mTertiary",
      "normal.cyan": "mTertiary",
      "normal.white": "mOnSurface",
      "bright.red": "mError",
      "bright.green": "mPrimary",
      "bright.yellow": "mTertiary",
      "bright.cyan": "mTertiary",
      "bright.white": "mOnSurface"
  })

  function init() {
    root.loading = true;

    // First find all theme files
    findProcess.running = true;
  }

  // Đổi tên hàm này để tránh trùng
  function loadThemeFile() {
    // Alias cho compatibility
    root.refresh();
  }

  function changeTheme(newTheme) {
    if (newTheme !== Settings.appearance.theme) {
      Settings.appearance.theme = newTheme;
      // If theme is matugen, set dynamic to true
      Settings.appearance.dynamic = (newTheme === "matugen");
    }
    return root.theme;
  }

  function getFallbackTheme() {
    return {
      "type": "dark",
      "primary": {
        "background": "#13140d",
        "foreground": "#e5e3d6",
        "dim_background": "#101410",
        "dim_foreground": "#b1cead",
        "bright_foreground": "#92d792"
      },
      "button": {
        "background": "#41493f",
        "text": "#92d792",
        "background_select": "#8a9387",
        "border": "#c0c9bc",
        "border_select": "#c0c9bc"
      },
      "cursor": {
        "cursor": "#cad3f5",
        "text": "#24273a"
      },
      "normal": {
        "black": "#494d64",
        "red": "#ed8796",
        "green": "#a6da95",
        "yellow": "#eed49f",
        "blue": "#8aadf4",
        "magenta": "#f5bde6",
        "cyan": "#8bd5ca",
        "white": "#b8c0e0"
      },
      "bright": {
        "black": "#5b6078",
        "red": "#ed8796",
        "green": "#a6da95",
        "yellow": "#eed49f",
        "blue": "#8aadf4",
        "magenta": "#f5bde6",
        "cyan": "#8bd5ca",
        "white": "#a5adcb"
      }
    };
  }

  function getThemeFromPalette() {
    // Chuyển đổi từ Material Design 3 sang theme format mới
    var currentMode = Settings.appearance.mode || "dark";

    // Nếu đã có theme mới được load, trả về nó
    if (root._currentTheme && root._currentTheme.type) {
      return root._currentTheme;
    }

    // Fallback: tạo theme từ palette
    return {
      "type": currentMode,
      "primary": {
        "background": adapter.mBackground ? adapter.mBackground.toString() : "#13140d",
        "foreground": adapter.mOnBackground ? adapter.mOnBackground.toString() : "#e5e3d6",
        "dim_background": adapter.mSurfaceContainerLow ? adapter.mSurfaceContainerLow.toString() : "#101410",
        "dim_foreground": adapter.mOnSurfaceVariant ? adapter.mOnSurfaceVariant.toString() : "#b1cead",
        "bright_foreground": adapter.mPrimary ? adapter.mPrimary.toString() : "#92d792"
      },
      "button": {
        "background": adapter.mSurfaceVariant ? adapter.mSurfaceVariant.toString() : "#41493f",
        "text": adapter.mPrimary ? adapter.mPrimary.toString() : "#92d792",
        "background_select": adapter.mOutline ? adapter.mOutline.toString() : "#8a9387",
        "border": adapter.mOnSurfaceVariant ? adapter.mOnSurfaceVariant.toString() : "#c0c9bc",
        "border_select": adapter.mOnSurfaceVariant ? adapter.mOnSurfaceVariant.toString() : "#c0c9bc"
      },
      "cursor": {
        "cursor": "#cad3f5",
        "text": "#24273a"
      },
      "normal": {
        "black": "#494d64",
        "red": adapter.mError ? adapter.mError.toString() : "#ed8796",
        "green": adapter.mPrimary ? adapter.mPrimary.toString() : "#a6da95",
        "yellow": adapter.mTertiary ? adapter.mTertiary.toString() : "#eed49f",
        "blue": "#8aadf4",
        "magenta": "#f5bde6",
        "cyan": adapter.mTertiary ? adapter.mTertiary.toString() : "#8bd5ca",
        "white": adapter.mOnSurface ? adapter.mOnSurface.toString() : "#b8c0e0"
      },
      "bright": {
        "black": "#5b6078",
        "red": adapter.mError ? adapter.mError.toString() : "#ed8796",
        "green": adapter.mPrimary ? adapter.mPrimary.toString() : "#a6da95",
        "yellow": adapter.mTertiary ? adapter.mTertiary.toString() : "#eed49f",
        "blue": "#8aadf4",
        "magenta": "#f5bde6",
        "cyan": adapter.mTertiary ? adapter.mTertiary.toString() : "#8bd5ca",
        "white": adapter.mOnSurface ? adapter.mOnSurface.toString() : "#a5adcb"
      }
    };
  }

  function refresh() {
    root.loading = true;

    // Check if theme is matugen or dynamic
    if (Settings.appearance.theme === "matugen" || Settings.appearance.dynamic) {
      generateFromWallpaper(Settings.appearance.mode, Settings.appearance.matugenType);
    } else {
      // Load static theme
      var themeName = Settings.appearance.theme;

      if (themeName && themeName !== "") {
        loadThemeByName(themeName);
      } else {
        // Use fallback theme based on mode
        var fallbackTheme = Settings.appearance.mode === "light" ? (Settings.appearance.light || "gruvbox-light") : (Settings.appearance.dark || "gruvbox-dark");

        Settings.appearance.theme = fallbackTheme;
        loadThemeByName(fallbackTheme);
      }
    }
  }

  function loadThemeByName(name) {
    if (!name || name === "") {
      root.loading = false;
      return;
    }

    // First check if it's a built-in theme file
    var path = "";

    // Check if file exists in themes directory
    for (var i = 0; i < themeFiles.length; i++) {
      var fileName = themeFiles[i].split("/").pop().replace(".json", "");
      if (fileName === name) {
        path = themeFiles[i];
        break;
      }
    }

    if (path) {
      themeReader.path = "";
      themeReader.path = path;
    } else {
      // Try to load matugen.json as fallback
      fallbackThemeReader.path = "";
      fallbackThemeReader.path = matugenFilePath;
    }
  }

  function updateColors(data) {
    if (!data) {
      root.loading = false;
      return;
    }

    // Kiểm tra xem data có phải là theme mới hay Material Design 3
    // Theme mới có cấu trúc: type, primary, button, cursor, normal, bright
    if (data.type && data.primary && data.normal) {
      // Đây là theme mới
      root._currentTheme = data;
      root.theme = data;

      // Ánh xạ theme mới sang Material Design 3
      var materialData = mapThemeToMaterial(data);

      // Cập nhật palette
      let changed = false;
      for (const key in materialData) {
        if (palette.hasOwnProperty(key) && palette[key] !== materialData[key]) {
          palette[key] = materialData[key];
          changed = true;
        }
      }
      if (changed) {
        stateFileView.writeAdapter();
      }
    } else {
      // Đây là Material Design 3 format
      let changed = false;
      for (const key in data) {
        if (palette.hasOwnProperty(key) && palette[key] !== data[key]) {
          palette[key] = data[key];
          changed = true;
        }
      }
      if (changed) {
        stateFileView.writeAdapter();
        // Tạo file matugen.json từ palette hiện tại
        createMatugenJsonFile();
      }

      // Tạo theme mới từ palette
      root._currentTheme = null;
      root.theme = getThemeFromPalette();
    }

    root.loading = false;
    themeReloaded();
  }

  // Hàm ánh xạ theme mới sang Material Design 3
  function mapThemeToMaterial(themeData) {
    var result = {};

    // Ánh xạ các màu từ theme mới sang Material Design 3
    for (var key in themeToMaterialMap) {
      var materialKey = themeToMaterialMap[key];
      var keys = key.split(".");
      var value = themeData;

      // Lấy giá trị theo path
      for (var i = 0; i < keys.length; i++) {
        if (value && typeof value === 'object') {
          value = value[keys[i]];
        } else {
          value = null;
          break;
        }
      }

      if (value && materialKey) {
        result[materialKey] = value;
      }
    }

    // Set mode-based colors
    var mode = themeData.type || "dark";
    if (mode === "light") {
      // Điều chỉnh một số màu cho light mode nếu cần
      if (!result.mBackground && themeData.primary && themeData.primary.background) {
        result.mBackground = themeData.primary.background;
      }
      if (!result.mOnBackground && themeData.primary && themeData.primary.foreground) {
        result.mOnBackground = themeData.primary.foreground;
      }
    }

    return result;
  }

  function generateFromWallpaper(mode, type) {
    if (!ProgramCheckerService.matugenAvailable) {
      root.loading = false;
      // Fall back to static theme
      var fallbackTheme = Settings.appearance.mode === "light" ? (Settings.appearance.light || "gruvbox-light") : (Settings.appearance.dark || "gruvbox-dark");
      loadThemeByName(fallbackTheme);
      return;
    }

    // Get wallpaper from primary screen
    var wallpaper = "";
    for (let i = 0; i < Quickshell.screens.length; i++) {
      if (Quickshell.screens[i].primary) {
        wallpaper = WallpaperService.getWallpaper(Quickshell.screens[i].name);
        break;
      }
    }
    // If no primary, get from first screen
    if (!wallpaper && Quickshell.screens.length > 0) {
      wallpaper = WallpaperService.getWallpaper(Quickshell.screens[0].name);
    }

    if (!wallpaper || wallpaper === "") {
      root.loading = false;
      // Fall back to static theme
      var fallbackTheme = Settings.appearance.mode === "light" ? (Settings.appearance.light || "gruvbox-light") : (Settings.appearance.dark || "gruvbox-dark");
      loadThemeByName(fallbackTheme);
      return;
    }

    const matugenType = validMatugenSchemes.includes(type) ? type : "scheme-tonal-spot";
    const targetMode = mode === "light" ? "light" : "dark";

    generateProcess.command = [
    "matugen",
    "image",
    wallpaper,
    "-j",
    "hex",
    "-m",
    targetMode,
    "--prefer=darkness"
    ];
    generateProcess.running = true;
  }

  function parseMatugen(json) {
    const result = {};
    const colors = json.colors || {};
    const mode = Settings.appearance.mode === "light" ? "light" : "dark";

    for (const key in matugenMap) {
      const colorObj = colors[key];
      if (colorObj && colorObj[mode] && colorObj[mode].color) {
        result[matugenMap[key]] = colorObj[mode].color;
      } else {
        console.warn("Missing color for key:", key);
      }
    }
    return result;
  }

  function getDisplayName(path) {
    if (!path)
    return "";
    return path.split("/").pop().replace(/\.json$/i, "").split("-").map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(" ");
  }

  // Tạo file matugen.json từ palette hiện tại
  function createMatugenJsonFile() {
    const themeData = root.theme;
    const themeJson = JSON.stringify(themeData, null, 2);

    // Create a temporary file and then move it
    var tempFile = "/tmp/matugen_temp_" + Date.now() + ".json";
    var cmd = `echo '${themeJson.replace(/'/g, "'\"'\"'")}' > "${tempFile}" && mv "${tempFile}" "${matugenFilePath}"`;

    try {
      var writeProcess = Qt.createQmlObject(`
        import QtQuick
        import Quickshell.Io
        Process {
        id: writeProcess
        command: ["bash", "-c", "${cmd.replace(/"/g, '\\"')}"]
        onExited: function(exitCode) {
        if (exitCode === 0) {
        console.log("matugen.json created successfully")
      } else {
        console.error("Failed to create matugen.json")
      }
        writeProcess.destroy()
      }
      }
        `, root, "CreateMatugenFileProcess");

      writeProcess.running = true;
    } catch (e) {
      console.error("Error creating matugen.json:", e);
    }
  }

  // Functions cho compatibility với code cũ
  function triggerMatugenOnThemeChange(themeMode) {

    if (Settings.appearance) {
      Settings.appearance.mode = themeMode;
      Settings.appearance.theme = "matugen";
      Settings.appearance.dynamic = true;
    }

    root.refresh();
  }

  function triggerMatugenOnWallpaperChange(currentWallpaper) {

    if (!currentWallpaper || currentWallpaper === "") {
      return;
    }

    if (Settings.appearance.theme === "matugen" || Settings.appearance.dynamic) {
      root.refresh();
    }
  }

  // Simple connection to Settings changes
  Connections {
    target: Settings

    function onReadyChanged() {
      if (Settings.ready) {
        // When settings are ready, refresh theme
        Qt.callLater(function () {
            root.refresh();
        });
      }
    }
  }

  Connections {
    target: Settings.appearance

    function onThemeChanged() {
      Qt.callLater(function () {
          root.refresh();
      });
    }

    function onModeChanged() {
      Qt.callLater(function () {
          root.refresh();
      });
    }

    function onDynamicChanged() {
      Qt.callLater(function () {
          root.refresh();
      });
    }

    function onMatugenTypeChanged() {
      if (Settings.appearance.dynamic || Settings.appearance.theme === "matugen") {
        Qt.callLater(function () {
            root.refresh();
        });
      }
    }
  }

  Connections {
    target: WallpaperService
    function onWallpaperChanged() {
      if (Settings.appearance.dynamic || Settings.appearance.theme === "matugen") {
        Qt.callLater(function () {
            root.refresh();
        });
      }
    }
  }

  Process {
    id: findProcess
    command: ["find", root.themesDirectory, "-name", "*.json", "-type", "f"]
    onExited: exitCode => {
      if (exitCode === 0) {
        themeFiles = stdout.text.trim().split("\n").filter(Boolean);

        // Now refresh theme based on settings
        if (Settings.ready) {
          root.refresh();
        } else {
          // Wait for settings to be ready
          settingsReadyTimer.start();
        }
      } else {
        root.loading = false;
      }
    }
    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }

  Timer {
    id: settingsReadyTimer
    interval: 100
    repeat: true
    onTriggered: {
      if (Settings.ready) {
        root.refresh();
        settingsReadyTimer.stop();
      } else {
        console.log("Still waiting for settings...");
      }
    }
  }

  Process {
    id: generateProcess
    workingDirectory: Quickshell.shellDir
    running: false
    onExited: exitCode => {
      if (exitCode === 0) {
        try {
          var jsonText = stdout.text.trim();
          if (jsonText) {
            var jsonData = JSON.parse(jsonText);
            root.updateColors(root.parseMatugen(jsonData));
          } else {
            console.error("Matugen returned empty output");
            root.loading = false;
          }
        } catch (e) {
          console.error("Matugen Parse Error:", e);
          root.loading = false;
        }
      } else {
        console.error("Matugen Error:", stderr.text);
        root.loading = false;
      }
    }
    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }

  FileView {
    id: themeReader
    onLoaded: {
      try {
        var jsonText = text();
        if (jsonText) {
          root.updateColors(JSON.parse(jsonText));
        } else {
          console.error("Theme file is empty");
          root.loading = false;
        }
      } catch (e) {
        console.error("Theme Load Error:", e);
        root.loading = false;
      }
    }
  }

  FileView {
    id: fallbackThemeReader
    onLoaded: {
      try {
        var jsonText = text();
        if (jsonText) {
          root.updateColors(JSON.parse(jsonText));
        } else {
          console.error("Fallback theme file is empty");
          // Load default fallback theme
          root.updateColors(root.getFallbackTheme());
        }
      } catch (e) {
        console.error("Fallback Theme Load Error:", e);
        // Load default fallback theme
        root.updateColors(root.getFallbackTheme());
      }
    }
  }

  FileView {
    id: stateFileView
    path: root.stateFilePath
    watchChanges: true
    onFileChanged: reload()
    onLoadFailed: error => {
      if (error === FileViewError.FileNotFound)
      writeAdapter();
      else
      console.error("State File Error:", error);
    }

    JsonAdapter {
      id: adapter
      property color mPrimary: "#c4cd7b"
      property color mOnPrimary: "#2e3300"
      property color mPrimaryContainer: "#444b05"
      property color mOnPrimaryContainer: "#e0e994"
      property color mSecondary: "#c7c9a7"
      property color mOnSecondary: "#2f321a"
      property color mTertiary: "#a2d0c1"
      property color mOnTertiary: "#06372d"
      property color mBackground: "#13140d"
      property color mOnBackground: "#e5e3d6"
      property color mSurface: "#13140d"
      property color mOnSurface: "#e5e3d6"
      property color mSurfaceVariant: "#47483b"
      property color mOnSurfaceVariant: "#c8c7b7"
      property color mSurfaceTint: "#c4cd7b"
      property color mOutline: "#929282"
      property color mShadow: "#000000"
      property color mError: "#ffb4ab"
      property color mOnError: "#690005"
      property color mErrorContainer: "#93000a"
      property color mOnErrorContainer: "#ffdad6"
      property color mSurfaceContainer: "#202018"
      property color mSurfaceContainerLow: "#1c1c14"
      property color mSurfaceContainerHigh: "#2a2b22"
      property color mSurfaceContainerHighest: "#35352d"
    }
  }

  // Private property để lưu theme hiện tại
  property var _currentTheme: null

  // Thêm Component.onCompleted để tự động gọi init()
  Component.onCompleted: {
    Qt.callLater(function () {
        init();
    });
  }
}
