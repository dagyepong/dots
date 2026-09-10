self:
{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (pkgs.stdenv.hostPlatform) system;
  cfg = config.programs.qs-vpets;
  finalPkg = self.packages.${system}.default;
in
{
  options.programs.qs-vpets = with lib; {
    enable = mkEnableOption "qs-vpets desktop virtual pets";

    package = mkOption {
      type = types.package;
      default = finalPkg;
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    systemd.user.services.qs-vpets = {
      Unit = {
        Description = "Desktop virtual pets";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
        ConditionEnvironment = "WAYLAND_DISPLAY";
      };

      Service = {
        ExecStart = "${cfg.package}/bin/qs-vpets";
        Restart = "on-failure";
        RestartSec = 3;
      };

      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
