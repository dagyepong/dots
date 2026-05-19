{
  lib,
  config,
  pkgs,
  hypePkgs,
  ...
}:
let
  inherit (lib) types;
  cfg = config.programs.hype-material-shell.greeter;
  cfgDms = config.programs.hype-material-shell;

  inherit (config.services.greetd.settings.default_session) user;

  compositorPackage =
    let
      configured = lib.attrByPath [ "programs" cfg.compositor.name "package" ] null config;
    in
    if configured != null then configured else builtins.getAttr cfg.compositor.name pkgs;

  cacheDir = "/var/lib/hype-greeter";
  greeterScript = pkgs.writeShellScriptBin "hype-greeter" ''
    export PATH=$PATH:${
      lib.makeBinPath [
        cfg.quickshell.package
        compositorPackage
        pkgs.glib  # provides gdbus, used by the fprintd hardware probe in GreeterContent.qml
      ]
    }
    ${
      lib.escapeShellArgs (
        [
          "sh"
          "${cfg.package}/share/quickshell/hype/Modules/Greetd/assets/hype-greeter"
          "--cache-dir"
          cacheDir
          "--command"
          cfg.compositor.name
          "-p"
          "${cfg.package}/share/quickshell/hype"
        ]
        ++ lib.optionals (cfg.compositor.customConfig != "") [
          "-C"
          "${pkgs.writeText "hypegreeter-compositor-config" cfg.compositor.customConfig}"
        ]
      )
    } ${lib.optionalString cfg.logs.save "> ${cfg.logs.path} 2>&1"}
  '';

  jq = lib.getExe pkgs.jq;
in
{
  imports =
    let
      msg = "The option 'programs.hype-material-shell.greeter.compositor.extraConfig' is deprecated. Please use 'programs.hype-material-shell.greeter.compositor.customConfig' instead.";
    in
    [
      (lib.mkRemovedOptionModule [
        "programs"
        "hype-material-shell"
        "greeter"
        "compositor"
        "extraConfig"
      ] msg)
      ./hype-rename.nix
    ];

  options.programs.hype-material-shell.greeter = {
    enable = lib.mkEnableOption "HypeMaterialShell greeter";
    package = lib.mkOption {
      type = types.package;
      default = if cfgDms.enable or false then cfgDms.package else hypePkgs.hype-shell;
      defaultText = lib.literalExpression ''
        if config.programs.hype-material-shell.enable
        then config.programs.hype-material-shell.package
        else built from source;
      '';
      description = ''
        The HypeMaterialShell package to use for the greeter.

        Defaults to the package from `programs.hype-material-shell` if it is enabled,
        otherwise defaults to building from source.
      '';
    };
    compositor.name = lib.mkOption {
      type = types.enum [
        "niri"
        "hyprland"
        "sway"
        "labwc"
        "mango"
        "scroll"
        "miracle"
      ];
      description = "Compositor to run greeter in";
    };
    compositor.customConfig = lib.mkOption {
      type = types.lines;
      default = "";
      description = "Custom compositor config";
    };
    configFiles = lib.mkOption {
      type = types.listOf types.path;
      default = [ ];
      description = "Config files to copy into data directory";
      example = [
        "/home/user/.config/HypeMaterialShell/settings.json"
      ];
    };
    configHome = lib.mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "/home/user";
      description = ''
        User home directory to copy configurations for greeter
        If HYPE config files are in non-standard locations then use the configFiles option instead
      '';
    };
    quickshell = {
      package = lib.mkPackageOption hypePkgs "quickshell" {
        extraDescription = "The quickshell package to use (defaults to be built from source, in the commit 26531f due to unreleased features used by HYPE).";
      };
    };
    logs.save = lib.mkEnableOption "saving logs from HYPE greeter to file";
    logs.path = lib.mkOption {
      type = types.path;
      default = "/tmp/hype-greeter.log";
      description = ''
        File path to save HYPE greeter logs to
      '';
    };
  };
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = (config.users.users.${user} or { }) != { };
        message = ''
          hypegreeter: user set for greetd default_session ${user} does not exist. Please create it before referencing it.
        '';
      }
    ];
    # HYPE currently relies on /etc/pam.d/login for lock screen password auth on NixOS.
    # Declare security.pam.services.hypeshell only if you want to override that runtime fallback.
    # U2F and fingerprint are handled separately by HYPE — do not add pam_u2f or pam_fprintd here.
    # security.pam.services.hypeshell = {
    #   # Example: add faillock
    #   faillock.enable = true;
    # };
    services.greetd = {
      enable = lib.mkDefault true;
      settings.default_session.command = lib.mkDefault (lib.getExe greeterScript);
    };
    fonts.packages = with pkgs; [
      fira-code
      inter
      material-symbols
    ];
    systemd.tmpfiles.settings."10-hypegreeter" = {
      ${cacheDir}.d = {
        inherit user;
        group =
          if config.users.users.${user}.group != "" then config.users.users.${user}.group else "greeter";
        mode = "0750";
      };
    };
    systemd.services.greetd.preStart = ''
      cd ${cacheDir}
      ${lib.concatStringsSep "\n" (
        lib.map (f: ''
          if [ -f "${f}" ]; then
              cp "${f}" .
          fi
        '') cfg.configFiles
      )}

      if [ -f session.json ]; then
          copy_wallpaper() {
              local path=$(${jq} -r ".$1 // empty" session.json)
              if [ -f "$path" ]; then
                  cp "$path" "$2"
                  ${jq} ".$1 = \"${cacheDir}/$2\"" session.json > session.tmp
                  mv session.tmp session.json
              fi
          }

          copy_monitor_wallpapers() {
              ${jq} -r ".$1 // {} | to_entries[] | .key + \":\" + .value" session.json 2>/dev/null | while IFS=: read monitor path; do
                  local dest="$2-$(echo "$monitor" | tr -c '[:alnum:]' '-')"
                  if [ -f "$path" ]; then
                      cp "$path" "$dest"
                      ${jq} --arg m "$monitor" --arg p "${cacheDir}/$dest" ".$1[\$m] = \$p" session.json > session.tmp
                      mv session.tmp session.json
                  fi
              done
          }

          copy_wallpaper "wallpaperPath" "wallpaper"
          copy_wallpaper "wallpaperPathLight" "wallpaper-light"
          copy_wallpaper "wallpaperPathDark" "wallpaper-dark"
          copy_monitor_wallpapers "monitorWallpapers" "wallpaper-monitor"
          copy_monitor_wallpapers "monitorWallpapersLight" "wallpaper-monitor-light"
          copy_monitor_wallpapers "monitorWallpapersDark" "wallpaper-monitor-dark"
      fi

      if [ -f settings.json ]; then
          theme_file="$(${jq} -r '.customThemeFile // empty' settings.json)"
          if [ -f "$theme_file" ] && [ -r "$theme_file" ]; then
              cp "$theme_file" custom-theme.json
              mv settings.json settings.orig.json
              ${jq} '.customThemeFile = "${cacheDir}/custom-theme.json"' settings.orig.json > settings.json
          fi
      fi

      mv hype-colors.json colors.json || :
      chown ${user}: * || :
    '';
    programs.hype-material-shell.greeter.configFiles = lib.mkIf (cfg.configHome != null) [
      "${cfg.configHome}/.config/HypeMaterialShell/settings.json"
      "${cfg.configHome}/.local/state/HypeMaterialShell/session.json"
      "${cfg.configHome}/.cache/HypeMaterialShell/hype-colors.json"
    ];
  };
}
